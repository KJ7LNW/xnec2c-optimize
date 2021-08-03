package NEC2::Card::GR;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::Card::geo_card_param_maps(),

		itsi       =>  'i1',
		nrpt       =>  'i2',
		n          =>  'i2',
		num        =>  'i2',
	}->{$key};
}

1;

