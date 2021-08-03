package NEC2::SM;

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

	

	return ($self, 
		NEC2::SC->new(
			x3 => $self->{x3}, 
			y3 => $self->{y3}, 
			z3 => $self->{z3}, 
			)
		);
}


1;
