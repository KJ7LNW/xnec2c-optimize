#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use NEC2;
use NEC2::Antenna::Yagi;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;
use PDL::Opt::Simplex::Simple;

use Linux::Inotify2;
use Data::Dumper;

if (!@ARGV)
{
	print "usage: $0 config-file.conf\n";
	exit 1;
}

my $filename_config = $ARGV[0];
my $filename_nec = $ARGV[0];
my $filename_nec_csv = $ARGV[0];

$filename_nec =~ s/\.conf$//;
$filename_nec     .= ".nec";
$filename_nec_csv = "$filename_nec.csv";

my $config = do($filename_config);
die $@ if $@;

my $simpl = PDL::Opt::Simplex::Simple->new(
	vars => $config->{vars},
	f => \&f,
	log => \&log,
	%{ $config->{simplex} });


print "===== Initial Condition ==== \n";

print Dumper($simpl->get_vars_initial) . "\n";


print "===== Writing NEC2 output to $filename_nec =====\n\n";

my $ncpus = `grep -c processor /proc/cpuinfo`; chomp $ncpus;
print "Open \`xnec2c -j $ncpus $filename_nec\` and select File->Optimizer Output. Then you may press enter to begin.\n";
<STDIN>;

unlink($filename_nec_csv);
f($simpl->get_vars_initial);

print $config->{nec2}->($simpl->get_vars_initial);


print "\n===== Starting Optimization ==== \n";

my $result = $simpl->optimize();

print "\n===== Done! ==== \n";

print "Result: " . Dumper($result);

f($result);

print "\n===== $filename_nec ==== \n";
system("cat $filename_nec");

exit 0;

#####################################################################
#                                                           Functions

# Globals for the functions:
my $log_count = 0;

sub goal_eval
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

sub goal_eval_all
{
	my ($goals, $vars, $csv) = @_;

	my $ret = 0;
	foreach my $g (@$goals) {
		# Default to enabled if undefined.
		$g->{enabled} //= 1;
		next if (!$g->{enabled});
		$ret += goal_eval($vars, $csv, $g);
	}

	return $ret;
}

sub f
{
	my $vars = shift;

	my $inotify = Linux::Inotify2->new;
	if (! -e "$filename_nec_csv" )
	{
		open(my $csv, ">", "$filename_nec_csv");
		close($csv);
	}
	$inotify->watch("$filename_nec_csv", IN_CLOSE_WRITE)
		or die "inotify: $!: $filename_nec_csv";

	# save and wait for the CSV to be written by xnec2c:
	$config->{nec2}->($vars)->save("$filename_nec");
	$inotify->read;

	my $csv = load_csv("$filename_nec_csv");

	return goal_eval_all($config->{goals}, $vars, $csv);
}

sub log
{
	my ($vars, $status) = @_;

	my $minima = $status->{minima};
	my $ssize = $status->{ssize};

	$log_count++;

	printf "\n\nLOG %d/%d [%.2f s]: %.6f > %g, goal minima = %.6f\n",
		$log_count, $simpl->{max_iter},
		$status->{elapsed},
		$ssize, $simpl->{tolerance},
		$minima;
	print Dumper($vars);
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



