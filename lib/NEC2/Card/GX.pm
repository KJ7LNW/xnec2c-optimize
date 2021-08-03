package NEC2::Card::GX;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::Card::geo_card_param_maps(),

		itsi       =>  'i1',
		planes     =>  'i2',
	}->{$key};
}

1;

