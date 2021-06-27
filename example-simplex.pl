#!/usr/bin/perl

use strict;
use warnings;

use PDL;
use PDL::Opt::Simplex;
use Data::Dumper;

my $count = 0;

# find value of $x that returns a minima.
sub f
{
	my ($vec) = @_;

	$count++;

	my $x = $vec->slice('(0)');

	# The parabola (x+3)^2 - 5 has a minima at x=-3:
	return (($x+3)**2 - 5);
}

sub log
{
	my ($vec, $vals, $ssize) = @_;

	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $x = $vec->slice('(0)');

	# each vector element passed to log() has a min and max value. 
	# ie: x=[6 0] -> vals=[76 4]
	# so, from above: f(6) == 76 and f(0) == 4

	print "$count [$ssize]: $x -> $vals\n";
}

my $vec_initial = pdl [30];
my ( $vec_optimal, $ssize, $optval ) = simplex($vec_initial, 3, 1e-6, 100, \&f, \&log);

my $x = $vec_optimal->slice('(0)');
print "ssize=$ssize  opt=$x -> minima=$optval\n";
