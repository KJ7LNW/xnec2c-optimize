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
#print Dumper $config;
#exit;

my $FR = $config->{FR};
my $goals = $config->{goals};

$FR->{freq_step} = ($FR->{freq_max} - $FR->{freq_min}) / ($FR->{n_freq} - 1);



my $simpl = PDL::Opt::Simplex::Simple->new(
	vars => $config->{geometry},
	f => \&f,
	log => sub { print "LOG: ". Dumper( \@_) },
	ssize => $config->{simplex}{ssize}, 
	max_iter => $config->{simplex}{max_iter},
	tolerance => $config->{simplex}{tolerance});



print "===== Initial Condition ==== \n";

# Can this use f()?
# Can goal_eval's  printing be done in log()?

my $yagi = yagi($simpl->get_vars_initial);
$yagi->save("$filename_nec");
print $yagi;

if ( -e "$filename_nec_csv" ) {
	print "\n=== Goal Status ===\n";
	my $csv = load_csv("$filename_nec_csv");
	goal_eval_all($config->{goals}, $simpl->get_vars_initial, $csv);
}

my $ncpus = `grep -c processor /proc/cpuinfo`; chomp $ncpus;

print "\n===== Ready ==== \n";
print "Writing NEC2 output to $filename_nec\n";
print "Open \`xnec2c -j $ncpus $filename_nec\` and select File->Optimizer Output. Then you may press enter to begin.\n";
<STDIN>;


print "\n===== Starting Optimization ==== \n";

my $result = $simpl->optimize();

print "\n===== Done! ==== \n";

print "Result: " . Dumper($result);

# TODO: Print goal and output status (log details):

f($result);

print "\n===== $filename_nec ==== \n";
system("cat $filename_nec");

exit 0;

# functions below here

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
	print "Goal $name ($goal->{field}) is $ret [$min,$max]. Values $goal->{mhz_min} to $goal->{mhz_max} MHz:\n\t$p\n";
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

sub yagi
{
	my ($vars) = @_;

	my $lengths = $vars->{lengths};
	my $spaces = $vars->{spaces};

	print "yagi: lengths=[" . join(', ', @$lengths) . "]\n";
	print "yagi: spaces=[" . join(', ', @$spaces) . "]\n";
	my $n_segments = $vars->{wire_segments} ; # must be odd!
	my $ex_seg = int($n_segments / 2) + 1;

	my $nec = NEC2->new(comment => 'A yagi antenna');

	my $yagi = NEC2::Antenna::Yagi->new(%$vars);

	$nec->add($yagi);
	$nec->add(
		# Free Space:
		GE(ground => 0),
		RP(ground => 0),

		# With ground:
		#GE->new(ground => 1),
		#RP180,
		#GN->new(type => 1),

		NH,
		NE,
		FR(mhz_min => $FR->{freq_min}, mhz_max => $FR->{freq_max}, n_freq => $FR->{n_freq})
	);

	return $nec;
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
	yagi($vars)->save("$filename_nec");
	$inotify->read;

	my $csv = load_csv("$filename_nec_csv");

	return goal_eval_all($config->{goals}, $vars, $csv);
}

sub log
{
	my ($vec, $vals, $ssize) = @_;
	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $minima = $vec->slice("(0)", 0);
	
	my $lengths = get_simplex_var($vec, 'lengths');
	my $spaces = get_simplex_var($vec, 'spaces');

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

