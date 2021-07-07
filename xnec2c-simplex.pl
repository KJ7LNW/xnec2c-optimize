#!/usr/bin/perl

use lib 'lib';


use NEC2;

use strict;
use warnings;

use Linux::Inotify2;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;

use Data::Dumper;

my $count = 0;

# for RP tag:
my $freq_min = 130;
my $freq_max = 160;
my $n_freq = 100;
my $freq_step = ($freq_max-$freq_min)/($n_freq-1);

# yagi dimensions from https://www.qsl.net/dk7zb/PVC-Yagis/5-Ele-2m.htm
my $vec_initial = pdl 
	(
	# unused value:
	0,

	# element lenghts
	1.038, 0.955, 0.959, 0.949, 0.935,

	# Spaces between elements:
	0.0, 0.280, 0.15, 0.520, 0.53)
;

###################
# Simplex Options

# "Step size" but not really, a bigger value makes larger jumps
# but the value doesn't translate to a unit.
# (it actually stands for simplex size, it initializes the size of the simplex tetrahedron)
my $ssize = 0.1;

# Conversion tolerance, exit optmizer when simplex isn't moving much:
my $tolerance = 1e-6;

# Max number of Simplex optimizations:
my $max_iter = 1000;


# Goals: Freq-MHz, Z-real, Z-imag, Z-magn, Z-phase, VSWR, Gain-max, Gain-viewer
my $goals = [
	{ 
		field => 'Gain-max',
		mhz_min => 144,
		mhz_max => 148,

		# Multiplicative weight, relative scale of the goal
		weight => 10,

		# Simplex minimizes, so return a negative value and raise it to a power.
		# A higher power makes the max-gain higher
		# A lower power makes a flater curve
		result => sub { my $gain = shift; return -$gain**1.5; }

	},

	{ 
		field => 'VSWR',
		mhz_min => 144,
		mhz_max => 148,

		# Multiplicative weight, relative scale of the goal
		weight => 3,

		# The optmizer minimizes results, penalize swr quadratically:
		# A larger power provides a flatter SWR
		# A lower power reduces the strength of the SWR penalty.
		result => sub { my $swr = shift; return $swr**3; }
	},

	{ 
		# F/B Ratio doesn't seem to affect the optimization very much
		# but it is a hint.
		field => 'F/B Ratio',
		mhz_min => 144,
		mhz_max => 148,

		# Multiplicative weight, relative scale of the goal
		weight => 1,

		# Simplex minimizes, so return a negative value and raise it to a power.
		# A higher power makes the max higher
		# A lower power makes the curve flatter.
		result => sub { my $fb = shift; return -$fb**1.0; }
	},
];


print "===== Initial Condition ==== \n";

my @yagi = yagi($vec_initial->slice("1:5"), $vec_initial->slice("6:10"));
NEC2::save("yagi.nec", @yagi);
print @yagi;

print "\n=== Goal Status ===\n";
my $csv = load_csv("yagi.nec.csv");
foreach my $g (@$goals) {
	goal_eval($csv, $g);
}

print "\nTurn on the optimizer and press enter to begin.\n";
<STDIN>;


print "\n===== Starting Optimization ==== \n";

my ( $vec_optimal, $opt_ssize, $optval ) = simplex($vec_initial, $ssize, $tolerance, $max_iter, \&f, \&log);


print "\n===== Done! ==== \n";

# One more with the optimal value:
f($vec_optimal);

my $x = $vec_optimal->slice('(0)');
print "opt_ssize=$opt_ssize  opt=$x -> minima=$optval\n";

print "\n===== yagi.nec ==== \n";
system("cat yagi.nec");

exit 0;

# functions below here

sub goal_eval
{
	my ($csv, $goal) = @_;

	# Find the index for the given frequency range:
	my $idx_min;
	my $idx_max;
	my $i = 0;
	for ($i = 0; $i < nelem($csv->{'Freq-MHz'}); $i++)
	{
		my $mhz = $csv->{'Freq-MHz'}->slice("($i)");
		$idx_min = $i if ($mhz >= $goal->{mhz_min} && !$idx_min);
		$idx_max = $i if ($mhz <= $goal->{mhz_max});
	}

	# $p contains the goal parameters in the frequency min/max that we are testing:
	my $p = $csv->{$goal->{field}};
	$p = $p->slice("$idx_min:$idx_max");


	# Sum the goal function and return the result:
	my $ret = 0;
	my $min;
	my $max;
	for ($i = 0; $i < nelem($p); $i++)
	{
		my $v = $goal->{result}->($p->slice("($i)"));
		$ret += $v;
		$min = $v if (!defined($min) || $v < $min);
		$max = $v if (!defined($max) || $v > $max);
	}

	#print "Calculated goal $goal->{field} is $ret [$min,$max]. Values $goal->{mhz_min} to $goal->{mhz_max} MHz:\n\t$p\n";
	return $ret;
}

sub yagi
{
	my ($lengths, $spaces) = @_;

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

		# convert PDL's to normal floats:
		my $l = $lengths->slice("($i)");
		my $s = $spaces->slice("($i)");
		
		$l = unpdl($l)->[0];
		$s = unpdl($s)->[0];


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
		NEC2::FR->new(mhz => $freq_min, mhz_inc => $freq_step, n_freq => $n_freq),
		NEC2::EN->new()
		;

	return @ret;
}


sub f
{
	my ($vec) = @_;



	my $lengths = $vec->slice("1:5", 0);
	my $spaces = $vec->slice("6:10", 0);
	
	my $inotify = Linux::Inotify2->new;
	$inotify->watch("yagi.nec.csv", IN_CLOSE_WRITE)
		or die "inotify: $!: yagi.nec.csv";

	NEC2::save("yagi.nec", yagi($lengths, $spaces));

	my @e;
	@e = $inotify->read;
	#printf "mask\t%d\n", $_->mask foreach @e;

	my $csv = load_csv("yagi.nec.csv");


	# Whatever vector format $vec->slice("(0)") is, $ret must be also.
	# So slice it, multiply times zero, and then add whatever you need:
	my $ret = $vec->slice("(0)");
	$ret *= 0;

	foreach my $g (@$goals) {
		$g->{weight} || 1;
		$ret += goal_eval($csv, $g) * $g->{weight};
	}

	return $ret;
}

sub log
{
	my ($vec, $vals, $ssize) = @_;
	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $lengths = $vec->slice("1:5", 0);
	my $spaces = $vec->slice("6:10", 0);
	
	#print "f: vec=$vec\n";
	print "f: lengths=$lengths\n";
	print "f: spaces=$spaces\n";

	# each vector element passed to log() has a min and max value.
	# ie: x=[6 0] -> vals=[76 4]
	# so, from above: f(6) == 76 and f(0) == 4

	$count++;
	print "\n\nLOG $count: $ssize > $tolerance, continuing.\n";
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
