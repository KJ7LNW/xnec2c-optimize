#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use lib 'lib';

use NEC2;
use Math::Trig;


my $filename = shift || die "usage: $0 filename.nec\n";

$SIG{__DIE__} = sub { print "\nDie: $_[0]" . Dumper _build_stack() ; };


my $nec = NEC2->new(comment => "coax cable");

my $z0 = 50;
my $er = 1;

# Given inner, find outer at $z0:
my $d = 0.005;
my $D = coax_solve_outer($d, $z0, $er);


my $cutoff_mhz = coax_cutoff_mhz($d, $D, $er);
print "d=$d D=$D cutoff=$cutoff_mhz\n";


my $nwires = 8;
my $ncircles = 8;
my $coax_len = 1;
my $ns = 21; # number of segments

$nec->add(
	# excitation
	GW( tag => 1, ns => 1, wire_rad => $d/2, z2 => $D/2),

	# center conductor
	GW( tag => 2, ns => $ns, wire_rad => $d/2, x2 => $coax_len),

	# shielding wires
	GW( tag => 3, ns => $ns, wire_rad => $d/10, z1 => -$D/2, z2 => -$D/2, x2 => $coax_len),
	GM( tag_start => 3, nrpt => $nwires-1, rox => 360/$nwires),

	# shielding circles
	GA( tag => 4, ns => $nwires, wire_rad => $d/10, rada => $D/2),
	GM( tag_start => 4, roz => 90),
	GM( tag_start => 4, nrpt => $ncircles, sx => $coax_len/$ncircles),

	# terminating resistor
	GW( tag => 5, ns => 1, wire_rad => $d/2, x1 => $coax_len, x2 => $coax_len, z2 => $D/2),
	LD( ldtag => 5, type => 0, zlr => 50),

	# control cards
	EX( ex_tag => 1, ex_seg => 1 ),
	RP,
	NH,
	NE,
	FR(mhz_min => 100, mhz_max => 2000, n_freq => 100),
	);


$nec->save($filename);

print $nec;

exit 0;
## functions

# Given outer diameter, Z0 and Er, return the inner diameter
sub coax_solve_inner
{
	my ($D, $z0, $er) = @_;
	return $D / (10**($z0*sqrt($er)/138));
}

# formulas from: https://www.everythingrf.com/rf-calculators/coaxial-cable-calculator
# Given inner diameter, Z0 and Er, return the outer diameter
sub coax_solve_outer
{
	my ($d, $z0, $er) = @_;
	return ($d*10**($z0*sqrt($er)/138));
}

# Given inner and outer diameter, and Er, return the cutoff frequency in MHz.
sub coax_cutoff_mhz
{
	my ($d, $D, $er) = @_;
	return 1e3 * 11.8/(sqrt($er)*pi*(($D+$d)/2));
}

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

