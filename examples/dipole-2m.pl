#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use lib 'lib';

use NEC2;

$SIG{__DIE__} = sub { print "\nDie: $_[0]" . Dumper _build_stack() ; };

my $nec = NEC2->new(comment => "half-wave 2-meter dipole");

my $ns = 21; # number of segments

$nec->add(
	GW( tag => 1, ns => $ns, z2 => 1),
	EX( ex_tag => 1, ex_seg => int($ns/2) ),
	RP,
	NH,
	NE,
	FR(mhz_min => 140, mhz_max => 148, n_freq => 10),
	);


$nec->save('dipole-2m.nec');

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
