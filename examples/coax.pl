#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use lib 'lib';

use NEC2;

my $filename = shift || die "usage: $0 filename.nec\n";

$SIG{__DIE__} = sub { print "\nDie: $_[0]" . Dumper _build_stack() ; };


my $nec = NEC2->new(comment => "coax cable");

# Coax cable endpoints.  Use multiple points to "bend" the cable:
my $points = [
	[0,0,0],
	[1,1,1],

	# Try additional points.
	# Be careful: sharp corners could short the shield at the inflection
	# point:
	#[2,2,3],
	#[2,2,4]
];

# Coax cables are now implemented by NEC2::Coax. See also lib/NEC2/Coax.pm:
$nec->add(
	Coax(tag => 1,
		points => $points,
		r_inner => 0.001, # inner conductor radius
		z0 => 50,       # outer radius is calculated for 50-ohms
		excite => 1,    # place an excitation on the first end of the coax
		terminate => 1, # place a 50-ohm termination at the last end of the coax

		# You may need to increase these for higher frequencies:
		n_circles => 20,
		n_shield => 8,
		ns => 20,
		),
	RP,
	NH,
	NE,
	FR(mhz_min => 10, mhz_max => 1000, n_freq => 100),
	);

$nec->save($filename);

print $nec;

exit 0;


## functions

sub _build_stack
{
	my $i = 0;
	my @msg;
	while (my @c = caller($i++)) {
		my @c0 = caller($i);
		my $caller = '';
		$caller = " ($c0[3])" if (@c0);
		push @msg, "  $i. $c[1]:$c[2]:$caller while calling $c[3]";
	}

	return \@msg;
}

