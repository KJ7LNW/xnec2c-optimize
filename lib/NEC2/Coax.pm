#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Library General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# 
#  Copyright (C) 2021- by Eric Wheeler, KJ7LNW.  All rights reserved.
#
#  The official website and doumentation for xnec2c-optimizer is available here:
#    https://www.xnec2c.org/
#
package NEC2::Coax;

use parent 'NEC2::Shape';

use strict;
use warnings;

use NEC2;

use Math::Trig qw/:radial pi rad2deg deg2rad/;

sub defaults
{
	return (
		tag => 1,
		z0 => 50,
		er => 1,  # NEC2 doesn't support non-freespace Er values (but NEC4/5 do?)
		ns => 21, # number of segments across the coax core and shield
		n_circles => 20, # Number of shield circles drawn along coax.
		n_shield => 8,   # Number of wires drawn as the outer coax shield
		r_inner => undef, # radius of inner conductor
		r_outer => undef,  # will be calculated
		shield_scale => 0.1, # scale the shielding wire by 1/10 of r_inner.
		terminate => 0, # apply a terminating resistor?
		excite => 0,    # apply excitation to {tag}?
	);
}


# points => [ [x,y,z], [x,y,z], [x,y,z], ... ]
sub new 
{
	my ($class, %args) = @_;
	my $self = bless(\%args, $class);

	my %defaults = $self->defaults;
	foreach my $k (keys %defaults)
	{
		$self->{$k} //= $defaults{$k};
	}

	$self->gen_cards;

	return $self;
}

sub gen_coax
{
	my ($self, $p1, $p2, $do_excite, $do_terminate) = @_;
	
	my @coax;

	my $vec = [ ($p2->[0] - $p1->[0]), ($p2->[1] - $p1->[1]), ($p2->[2] - $p1->[2]) ];
	my ($rho, $theta, $phi)   = cartesian_to_spherical(@$vec);
	$theta = rad2deg($theta);
	$phi = rad2deg($phi);

	my $nwires = $self->{n_shield};
	my $ncircles = $self->{n_circles};
	my $coax_len = sqrt($vec->[0]**2 + $vec->[1]**2 + $vec->[2]**2);
	my $ns = $self->{ns}; # number of segments

	my $z0 = $self->{z0};
	my $er = $self->{er};

	# Given inner, find outer at $z0:
	my $ri = $self->{r_inner};
	my $ro = $self->{r_outer};
	my ($d, $D);

	if (defined($ri) && !defined($ro))
	{
		$d = $ri*2;
		$D = _coax_solve_outer($d, $z0, $er);
		$self->{r_outer} = $D/2;
	}
	elsif (!defined($ri) && defined($ro))
	{
		$D = $ro*2;
		$d = _coax_solve_inner($D, $z0, $er);
		$self->{r_inner} = $d/2;
	}
	elsif (!defined($ri) && !defined($ro))
	{
		die "You must specify either r_inner or r_outer";
	}
	else
	{
		$d = $ri*2;
		$D = $ro*2;
	}

	print "d=$d D=$D\n";
	my $shield_rad = $d * $self->{shield_scale};

	my $first_tag = $self->{_tag};

	# Excitation?
	if ($do_excite)
	{
		push @coax,
			GW( tag => $self->{_tag}++, ns => 1, wire_rad => $d/2, z2 => $D/2);

		push @{ $self->{_program_cards} },
			EX( ex_tag => $self->{_tag}-1, ex_seg => 1 );
	}

	# Center conductor:
	push @coax, GW( tag => $self->{_tag}++, ns => $ns, wire_rad => $d/2, x2 => $coax_len);

	# Shielding wires:
	push @coax, GW( tag => $self->{_tag}++, ns => $ns, wire_rad => $shield_rad, z1 => -$D/2, z2 => -$D/2, x2 => $coax_len);
	push @coax, GM( tag_start => $self->{_tag}-1, nrpt => $nwires-1, rox => 360/$nwires);

	# Shielding circles:  For the arc, NS is the number of shielding wires so the
	# polygon lines up to the shape created by the wires.
	push @coax, GA( tag => $self->{_tag}++, ns => $nwires, wire_rad => $shield_rad, rada => $D/2);
	push @coax, GM( tag_start => $self->{_tag}-1, roz => 90);
	push @coax, GM( tag_start => $self->{_tag}-1, nrpt => $ncircles, sx => $coax_len/$ncircles);

	#GW(tag => $self->{_tag}++, points => [[0,0,0]=>$p1]);
	#GW(tag => $self->{_tag}++, points => [[0,0,0]=>$p2]);

	# Terminating resistor?
	if ($do_terminate)
	{
		push @coax,
			GW( tag => $self->{_tag}++, ns => 1, wire_rad => $d/2,
				x1 => $coax_len, x2 => $coax_len, z2 => $D/2);

		push @{ $self->{_program_cards} },
			LD( ldtag => $self->{_tag}-1, type => 0, zlr => 50);
	}

	# Rotate into position
	push @coax, GM( tag_start => $first_tag, roy => - (90-$phi), roz => $theta,
		sx => $p1->[0], sy => $p1->[1], sz => $p1->[2]);

	push @{ $self->{_geo_cards}}, @coax;
}

sub gen_cards
{
	my $self = shift;

	my (@geo, @program);
	my $prev;

	die "Must have at least 2 points" if (scalar(@{ $self->{points} }) < 2);

	$self->{_tag} = $self->{tag};

	my $first = 1;
	my @points = @{ $self->{points} };
	while (my $point = shift @points)
	{
		print join(", ", @$point) . "\n";
		if ($prev)
		{
			# All parameters in $self except 'points' and 'tag' are passed to GW:
			
			$self->gen_coax($prev => $point,
				$first && $self->{excite},
				!@points && $self->{terminate});

			$first = 0;
		}
		$prev = $point;

	}
}

# Formulas from: https://www.everythingrf.com/rf-calculators/coaxial-cable-calculator
# Given outer diameter, Z0 and Er, return the inner diameter
sub _coax_solve_inner
{
	my ($D, $z0, $er) = @_;
	return $D / (10**($z0*sqrt($er)/138));
}

# Given inner diameter, Z0 and Er, return the outer diameter
sub _coax_solve_outer
{
	my ($d, $z0, $er) = @_;
	return ($d*10**($z0*sqrt($er)/138));
}

# Given inner and outer diameter, and Er, return the cutoff frequency in MHz.
sub cutoff_mhz
{
	my $self = shift;
	my ($d, $D, $er) = ($self->{r_inner}*2, $self->{r_outer}*2, $self->{er});
	return 1e3 * 11.8/(sqrt($er)*pi*(($D+$d)/2));
}

sub geo_cards
{
	my $self = shift;

	return @{ $self->{_geo_cards} };
}

sub program_cards
{
	my $self = shift;

	return @{ $self->{_program_cards} // [] };
}

1;
