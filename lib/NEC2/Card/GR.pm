package NEC2::GR;

use strict;
use warnings;

use parent 'NEC2';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

		itsi       =>  'i1',
		nrpt       =>  'i2',
		n          =>  'i2',
		num        =>  'i2',
	}->{$key};
}

1;

