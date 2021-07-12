#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use NEC2;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;

use Linux::Inotify2;
use Data::Dumper;

my $config = do($ARGV[0]);
#print Dumper $config;
#exit;

my $FR = $config->{FR};
my $goals = $config->{goals};
my $vars = $config->{geometry};

$FR->{freq_step} = ($FR->{freq_max} - $FR->{freq_min}) / ($FR->{n_freq} - 1);

my $vec_initial = build_simplex_vars($config->{geometry});


print "===== Initial Condition ==== \n";

my @yagi = yagi(get_simplex_vars($vars, $vec_initial));
NEC2::save("yagi.nec", @yagi);
print @yagi;

if ( -e "yagi.nec.csv" ) {
	print "\n=== Goal Status ===\n";
	my $csv = load_csv("yagi.nec.csv");
	goal_eval_all($config->{goals}, $vec_initial, $csv);
}

print "\nOpen xnec2c and select File->Optimizer Output. Then you may press enter to begin.\n";
<STDIN>;


print "\n===== Starting Optimization ==== \n";

my ( $vec_optimal, $opt_ssize, $optval ) = simplex($vec_initial, $config->{simplex}{ssize}, $config->{simplex}{tolerance}, $config->{simplex}{max_iter}, \&f, \&log);


print "\n===== Done! ==== \n";

# One more with the optimal value:
f($vec_optimal);

my $x = $vec_optimal->slice('(0)');
print "opt_ssize=$opt_ssize  opt=$x -> minima=$optval\n";

print "\n===== yagi.nec ==== \n";
system("cat yagi.nec");

exit 0;

# functions below here

# Globals for the functions:
my $log_count = 0;

sub goal_eval
{
	my ($vec, $csv, $goal) = @_;

	my $weight = $goal->{weight} || 1;
	my $type = $goal->{type} // 'sum';

	# If no field is defined, just call the goal
	# function on the variables and pass the $csv.
	if (!defined($goal->{field}))
	{
		my $v = $goal->{result}->($vec, $csv); 
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

	$ret *= $weight;

	my $name = $goal->{name} // '';
	print "Goal $name ($goal->{field}) is $ret [$min,$max]. Values $goal->{mhz_min} to $goal->{mhz_max} MHz:\n\t$p\n";
	return $ret;
}

sub goal_eval_all
{
	my ($goals, $vec, $csv) = @_;

	my $ret = 0;
	foreach my $g (@$goals) {
		# Default to enabled if undefined.
		$g->{enabled} //= 1;
		next if (!$g->{enabled});
		$ret += goal_eval($vec, $csv, $g);
	}

	return $ret;
}

sub yagi
{
	my (%vars) = @_;

	my $lengths = $vars{lengths};
	my $spaces = $vars{spaces};

	print "yagi: lengths=[" . join(', ', @$lengths) . "]\n";
	print "yagi: spaces=[" . join(', ', @$spaces) . "]\n";

	my $n_segments = 11; # must be odd!
	my $ex_seg = int($n_segments / 2) + 1;

	#print "lengths: $lengths\n";
	#print "spaces: $spaces\n";
	my @ret = (
		NEC2::CM->new(comment => 'A yagi antenna'),
		NEC2::CE->new() 
		);


	my $zoff = 0;
	for (my $i = 0 ; $i < nelem($lengths) ; $i++) {
		my $l = $lengths->[$i];
		my $s = $spaces->[$i];
		
		# spaces are distances between so accumulate the Z offset
		$zoff += $s;
		
		# left and right of zero
		$l /= 2; 
		push(
			@ret,
			NEC2::GW->new(
				tag => $i+1,
				ns  => $n_segments,
				x   => $l, x2  => -$l,
				z   => $zoff, z2  => $zoff, 
				rad => 0.002

			)
		);

	}

	# End of geometry and program parameters:
	push @ret, 
		# Free Space:
		NEC2::GE->new(ground => 0),
		NEC2::RP360->new(),

		# With ground:
		#NEC2::GE->new(ground => 1),
		#NEC2::RP180->new(),
		#NEC2::GN->new(type => 1),

		NEC2::EX->new(ex_tag => 2, ex_segment => $ex_seg),

		NEC2::NH->new(),
		NEC2::NE->new(),
		NEC2::FR->new(mhz => $FR->{freq_min}, mhz_inc => $FR->{freq_step}, n_freq => $FR->{n_freq}),
		NEC2::EN->new()
		;

	return @ret;
}


sub f
{
	my ($vec) = @_;

	my $inotify = Linux::Inotify2->new;
	$inotify->watch("yagi.nec.csv", IN_CLOSE_WRITE)
		or die "inotify: $!: yagi.nec.csv";

	# save and wait for the CSV to be written:
	

	NEC2::save("yagi.nec", yagi(get_simplex_vars($vars, $vec)));
	$inotify->read;

	my $csv = load_csv("yagi.nec.csv");

	# Whatever vector format $vec->slice("(0)") is, $ret must be also.
	# So slice it, multiply times zero, and then add whatever you need:
	my $ret = $vec->slice("(0)");
	$ret *= 0;
	$ret += goal_eval_all($config->{goals}, $vec, $csv);

	return $ret;
}

sub log
{
	my ($vec, $vals, $ssize) = @_;
	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $minima = $vec->slice("(0)", 0);
	
	my $lengths = get_simplex_var($vars, $vec, 'lengths');
	my $spaces = get_simplex_var($vars, $vec, 'spaces');

	#print "f: vec=$vec\n";
	print "f: lengths=[" . join(', ', @$lengths) . "]\n";
	print "f: spaces=[" . join(', ', @$spaces) . "]\n";

	# each vector element passed to log() has a min and max value.
	# ie: x=[6 0] -> vals=[76 4]
	# so, from above: f(6) == 76 and f(0) == 4


	$log_count++;
	print "\n\nLOG $log_count: $ssize > $config->{simplex}{tolerance}, minima = $minima.\n";
}

sub load_csv
{
	my $fn = shift;
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

	return \%h;
}

sub build_simplex_vars 
{
	my ($vars) = @_;

	# first element is for simplex's return-value use, set it to 0.	
	my @pdl_vars = (0);
	foreach my $var_name (sort keys(%$vars))
	{
		my $var = $vars->{$var_name};

		my $n = scalar(@{ $var->{values} });

		# If enabled is missing or a non-scalar (ie =1 or =0) then form it properly
		# as either all 1's or all 0's:
		if (!defined($var->{enabled}) || (!ref($var->{enabled}) && $var->{enabled}))
		{
			$var->{enabled} = [ map { 1 } @{ $var->{values} } ] 
		}
		elsif (defined($var->{enabled}) && !ref($var->{enabled}) && !$var->{enabled})
		{
			$var->{enabled} = [ map { 0 } @{ $var->{values} } ] 
		}

		if (defined($var->{enabled}) && $n != scalar(@{ $var->{enabled} }))
		{
			die "variable $var must have the same length array for 'values' as for 'enabled'"
		}


		for (my $i = 0; $i < $n; $i++)
		{
			# var is enabled for simplex if enabled[$i] == 1
			if ($var->{enabled}->[$i])
			{
				push(@pdl_vars, $var->{values}->[$i]);
			}
		}
	}

	return pdl \@pdl_vars;
}

sub get_simplex_var
{
	my ($vars, $pdl, $var_name) = @_;

	my @ret;
	
	my $var = $vars->{$var_name};

	my $n = scalar(@{ $var->{values} });
	my $pdl_idx = 1; # skip first element

	# skip ahead to where the pdl_idx that we need is located:
	foreach my $vn (sort keys(%$vars))
	{
		my $var = $vars->{$vn};

		# done if we find it:
		last if $vn eq $var_name;

		$pdl_idx++ foreach (grep { $_ } @{ $var->{enabled} });
	}
	
	for (my $i = 0; $i < $n; $i++)
	{
		# use the pdl index if it is enabled for optimization
		# otherwise use the original index in $var.
		if ($var->{enabled}->[$i])
		{
			push(@ret, unpdl($pdl->slice("($pdl_idx)", 0))->[0]);
			$pdl_idx++;
		}
		else
		{
			push(@ret, $var->{values}->[$i]);
		}
	}

	return \@ret;
}

sub get_simplex_vars
{
	my ($vars, $pdl) = @_;	
	
	my %h;

	foreach my $var (keys %$vars)
	{
		$h{$var} = get_simplex_var($vars, $pdl, $var);
	}

	return %h;
}
