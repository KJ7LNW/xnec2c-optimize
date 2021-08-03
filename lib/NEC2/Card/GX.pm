package NEC2::GX;

use strict;
use warnings;

use parent 'NEC2';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

		itsi       =>  'i1',
		planes     =>  'i2',
	}->{$key};
}

1;

