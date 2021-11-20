package NEC2::xnec2c::optimize;

use strict;
use warnings;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;
use PDL::Opt::Simplex::Simple;

use Linux::Inotify2;

use Data::Dumper;

sub new
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	if (!defined($self->{filename_nec}))
	{
		die "Output file <filename_nec> must be defined";
	}

	if (!defined($self->{nec2}) || ref($self->{nec2}) ne 'CODE')
	{
		die "NEC2 geometry callback function <nec2> is undefined or invalid";
	}
	
	if (!defined($self->{filename_nec_csv}))
	{
		$self->{filename_nec_csv} = $self->{filename_nec} . ".csv";
	}
	else
	{
		warn "specifying filename_nec_csv is unsupported: xnec2c will always append .csv to the .nec file";

	}

	$self->{simplex} = PDL::Opt::Simplex::Simple->new(
		vars => $self->{vars},
		f    =>  sub  {  print Dumper \@_; $self->_xnec2c_optimize_callback(@_)  },
		log  =>  sub  {  $self->_log(@_)                       },
		%{ $self->{simplex} });
	
	print Dumper $self;

	# simplex, vars, nec2, goals, filename_nec_csv, filename_nec
	return $self;
}

sub optimize
{
	my $self = shift;

	$self->{log_count} = 0;

	$self->{result} = $self->{simplex}->optimize();

}

sub print_vars_initial
{
	my $self = shift;
	print "===== Initial Condition ==== \n";

	print Dumper($self->{simplex}->get_vars_initial) . "\n";
}

sub print_vars_result
{
	my $self = shift;
	print "===== Result ==== \n";

	print Dumper($self->{result}) . "\n";
}

sub print_nec2_initial
{
	my $self = shift;
	print $self->{nec2}->($self->{simplex}->get_vars_initial);
}

sub print_nec2_final
{
	my $self = shift;
	print $self->{nec2}->($self->{simplex}->get_vars_initial);
}

sub save_nec_initial
{
	my $self = shift;

#$self->_xnec2c_optimize_callback($self->{simplex}->get_vars_initial);
#return;

	my $nec2 = $self->{nec2}->($self->{simplex}->get_vars_initial);
	print("saving $self->{filename_nec}: $nec2\n");
	$nec2->save($self->{filename_nec});
}

sub save_nec_final
{
	my $self = shift;

#$self->_xnec2c_optimize_callback($self->{result});
#return;

	my $nec2 = $self->{nec2}->($self->{result});
	$nec2->save($self->{filename_nec});
}

sub _xnec2c_optimize_callback
{
	my ($self, $vars) = @_;

	my $filename = $self->{filename_nec_csv};

print "waiting for $filename\n";
	my $inotify = Linux::Inotify2->new;
	if (! -e "$filename" )
	{
		open(my $csv, ">", "$filename");
		close($csv);
	}
	$inotify->watch("$filename", IN_CLOSE_WRITE)
		or die "inotify: $!: $filename";


	# save and wait for the CSV to be written by xnec2c:
	$self->{nec2}->($vars)->save($self->{filename_nec});
print "saved $self->{filename_nec}\n";
	$inotify->read;

print "done waiting for $filename\n";

	my $csv = _load_csv("$filename");

	return _goal_eval_all($self->{goals}, $vars, $csv);
}

sub _log
{
	my ($self, $vars, $status) = @_;

	my $minima = $status->{minima};
	my $ssize = $status->{ssize};

	$self->{log_count}++;

	printf "\n\nLOG %d/%d [%.2f s]: %.6f > %g, goal minima = %.6f\n",
		$self->{log_count}, $self->{simplex}->{max_iter},
		$status->{elapsed},
		$ssize, $self->{simplex}->{tolerance},
		$minima;
	print Dumper($vars);
}

sub _load_csv
{
	my $fn = shift;

	(-e $fn) or die "CSV file is missing: $fn";

	my @pdls = rcsv1D($fn, { header => 1 });

	my %h;
	foreach my $p (@pdls)
	{
		my $header = $p->hdr->{col_name};
		if ($header)
		{
			$header =~ s/^\s*|\s*$//g;
			$h{$header} = $p 
		}
	}


print Dumper \%h;
	return \%h;
}

sub _goal_eval
{
	my ($vars, $csv, $goal) = @_;

	my $weight = $goal->{weight} || 1;
	my $type = $goal->{type} // 'sum';

	# If no field is defined, just call the goal
	# function on the variables and pass the $csv.
	if (!defined($goal->{field}))
	{
		my $v = $goal->{result}->($vars, $csv); 
		print "Goal $goal->{name} is $v\n";
		return $v * $weight;
	}

	# Find the index for the given frequency range:
	my $mhz;
	my $idx_min;
	my $idx_max;
	my $i = 0;
	for ($i = 0; $i < nelem($csv->{'Freq-MHz'}); $i++)
	{
		$mhz = $csv->{'Freq-MHz'}->slice("($i)");
		$idx_min = $i if ($mhz >= $goal->{mhz_min} && !$idx_min);
		$idx_max = $i if ($mhz <= $goal->{mhz_max});
	}

	if (!defined($idx_min))
	{
		die "can't find index for frequency in CSV at $goal->{mhz_min} MHz";
	}

	if (!defined($idx_max))
	{
		die "can't find index for frequency in CSV at $goal->{mhz_max} MHz";
	}


	# $p contains the goal parameters in the frequency min/max that we are testing:
	my $p = $csv->{$goal->{field}};
	if (!defined($p))
	{
		die "Undefined field in CSV: $goal->{field}\n";
	}

	$p = $p->slice("$idx_min:$idx_max");
	$mhz = $csv->{'Freq-MHz'}->slice("$idx_min:$idx_max");


	# Sum the goal function and return the result:
	my $n = nelem($p);
	my $sum = 0;
	my $mag = 0;
	my $avg = 0;
	my $min;
	my $max;
	for ($i = 0; $i < $n; $i++)
	{
		my $v = $goal->{result}->($p->slice("($i)"), $mhz->slice("($i)")); 

		if ($v eq pdl(['inf']))
		{
			warn "result($goal->{field}) at index $i is infinite, using 1e6";
			$v = 1e6;
		}
		if ($v eq pdl(['nan']) || $v eq pdl(['-nan']))
		{
			warn "result($goal->{field}) at index $i is NaN, skipping";
			next;
		}

		$min = $v if (!defined($min) || $v < $min);
		$max = $v if (!defined($max) || $v > $max);
		$sum += $v;

		$mag += $v**2;
	}
	
	$avg = $sum / $n;
	$mag = sqrt($mag);

	my $ret = $sum;

	if ($type eq 'sum')    { $ret = $sum; }
	elsif ($type eq 'avg') { $ret = $avg; }
	elsif ($type eq 'min') { $ret = $min; }
	elsif ($type eq 'max') { $ret = $max; }
	elsif ($type eq 'mag') { $ret = $mag; }
	elsif ($type eq 'diff') { $ret = $max - $min; }
	elsif ($type eq '+diff') { $ret = $max - $min; }
	elsif ($type eq '-diff') { $ret = -($max - $min); }

	$ret *= $weight;

	my $name = $goal->{name} // '';
	#print "Goal $name ($goal->{field}) is $ret [$min,$max]. Values $goal->{mhz_min} to $goal->{mhz_max} MHz:\n\t$p\n";
	return $ret;
}

sub _goal_eval_all
{
	my ($goals, $vars, $csv) = @_;

	my $ret = 0;
	foreach my $g (@$goals) {
		# Default to enabled if undefined.
		$g->{enabled} //= 1;
		next if (!$g->{enabled});
		$ret += _goal_eval($vars, $csv, $g);
	}

	return $ret;
}

1;
