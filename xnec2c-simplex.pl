#!/usr/bin/perl

use lib 'lib';


use NEC2;
use NEC2::GW;

use strict;
use warnings;

use PDL;
use PDL::Opt::Simplex;

use Text::CSV;
use Data::Dumper;

my $count = 0;

# for EX tag:
my $ex_tag=1;

# for RP tag:
my $freq_min = 100;
my $freq_max = 460;
my $n_freq = 100;
my $freq_step = ($freq_max-$freq_min)/($n_freq-1);




# Constraints: Freq-MHz, Z-real, Z-imag, Z-magn, Z-phase, VSWR, Gain-max, Gain-viewer
my $goals = [
	{ 
		mhz_min => 144,
		mhz_max => 148,
		constraint => [ 'VSWR', '<', 1.5 ]
	},
	{ 
		mhz_min => 144,
		mhz_max => 148,
		constraint => [ 'Gain-viewer,', '>', 8 ]
		#constraint => [ 'Gain-max', '>', 8 ]
	},
];

my $vec_initial = pdl 

	# element lenghts
	( 2.05, 2, 1.8, 1.5, 1.4,

	# element z locations
	0.0, 0.1, 0.3, 0.7, 1.0 )
;

my $max_iter = 10;


my $vec = $vec_initial;
#print $vec->slice("0:4");
#print $vec->slice("5:9");
print "===== test ==== \n";
print yagi($vec->slice("0:4"), $vec->slice("5:9"));
print "\n===== start ==== \n";
#my $s = $simplex_init->slice("(2)");
#print $s;

my ( $vec_optimal, $ssize, $optval ) = simplex($vec_initial, 10, 1e-6, $max_iter, \&f, \&log);

my $x = $vec_optimal->slice('(0)');
print "ssize=$ssize  opt=$x -> minima=$optval\n";


exit 0;

# functions below here


sub yagi {
  my ($lengths, $spaces) = @_;

	print "lengths: $lengths\n";
	print "spaces: $spaces\n";
  my @ret;
  for (my $i = 0; $i < 5; $i++)
  {
	push (@ret, NEC2::GW->new(tag => 1, ns => 11, 
			x  =>  -$lengths->slice("($i)"),  x2  =>  $lengths->slice("($i)"),  
			z  =>  $spaces->slice("($i)"),      z2  =>  $spaces->slice("($i)")
			)
	);
  }

  return @ret;
}

sub f
{
	my ($vec) = @_;

	$count++;

	my $lengths = $vec->slice("0:4", 0);
	my $spaces = $vec->slice("5:9", 0);
	print "f: $vec\n";

	print yagi($lengths, $spaces);

# Use this RP if there is a ground:
# 	RP  0    19    37        1000  0        0     5       10     0       0
# This with no ground:
# 	RP  0  19       37  1000  0          0           10         10   0  0
  print qq{
GE  1  0        0   0     0          0           0          0    0
EX  0  $ex_tag  1   0     1          0           0          0    0  0
RP  0  19       37  1000  0          0           5          10   0  0
NH  0  0        0   0     0          0           0          0    0  0
NE  0  10       1   10    -1.35      0           -1.35      0.3  0  0.3
GN  1  0        0   0     0          0           0          0    0  0
FR  0  $n_freq  0   0     $freq_min  $freq_step  $freq_max  0    0  0
EN  0  0        0   0     0          0           0          0    0  0
};

	my $ret = $vec->slice("(0)");
	$ret *= 0;
	$ret += rand;
	print "f-ret: $ret\n";
	return $ret;
}

sub log
{
	my ($vec, $vals, $ssize) = @_;

	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $x = $vec;

	# each vector element passed to log() has a min and max value. 
	# ie: x=[6 0] -> vals=[76 4]
	# so, from above: f(6) == 76 and f(0) == 4

	print "LOG $count [$ssize]: $x -> $vals\n";
}
