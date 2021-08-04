package NEC2::Card::GW;

use strict;
use warnings;

use parent 'NEC2::Card';

# this is a multi-card card when rad = 0, see the GC card documented on the GW page.
# GC is added below in the overloaded geo_cards() function.

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002); 
}

sub param_map
{
	my ($self, $key) = @_;
	return {

		# original NEC2 terms:
		itg  =>          'i1',
		ns   =>          'i2',
		xw1  =>          'f1',
		yw1  =>          'f2',
		zw1  =>          'f3',
		xw2  =>          'f4',
		yw2 =>           'f5',
		zw2 =>           'f6',
		rad =>           'f7',

		# shorthand:
		tag  =>          'itg',
		x    =>          'xw1',
		x1   =>          'xw1',

		y    =>          'yw1',
		y1   =>          'yw1',

		z    =>          'zw1',
		z1   =>          'zw1',

		x2   =>          'xw2',
		y2   =>          'yw2',
		z2   =>          'zw2',
	};
}

sub geo_cards
{
	my $self = shift;

	my @cards = ($self);

	# if rad == 0 then there must be a GC card.
	if ($self->get('rad') == 0)
	{
		if (!$self->{rdel} || $self->{rad1} || $self->{rad2})
		{
			die "GW: rdel, rad1, and rad2 must be defined when rad=0";
		}

		push @cards,
			NEC2::Card::GC->new(
				rdel => $self->{rdel}, 
				rad1 => $self->{rad1}, 
				rad2 => $self->{rad2});
				
	}

	return @cards;

}

1;
