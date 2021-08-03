package NEC2::SP;

use strict;
use warnings;

use parent 'NEC2';


sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

		ns =>  'i2',
		shape =>  'i2',

		x1 =>  'f1',
		y1 =>  'f2',
		z1 =>  'f3',

		x2 =>  'f4',
		elevation =>  'f4',

		y2 =>  'f5',
		azimuth =>  'f5',

		z2 =>  'f6',
		area =>  'f6',

	}->{$key};
}

sub geo_cards
{
	my $self = shift;


	# if ns is 1,2,3 then a second SC card exists:
	if ($self->get('ns') =~ /^[12]$/)
	{
		if (
			!$self->{x3} ||
			!$self->{y3} ||
			!$self->{z3})
		{
			die "GW: x3, y3, and z3 must be defined when ns is 2, or 3";
		}
	}

	if ($self->get('ns') == 3)
	{
		if (
			!$self->{x4} ||
			!$self->{y4} ||
			!$self->{z4})
		{
			die "GW: x4, y4, and z4 must be defined when ns is 3";
		}
	}


	my @cards = ($self);

	if ($self->get('ns') =~ /^[123]$/)
	{
		push @cards,
			NEC2::SC->new(
				i2 => $self->get('ns'),
				x3 => $self->{x3}, 
				y3 => $self->{y3}, 
				z3 => $self->{z3}, 

				x4 => $self->{x4}, 
				y4 => $self->{y4}, 
				z4 => $self->{z4}, 
			);
				
	}

	return @cards;
}


1;
