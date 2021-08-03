package NEC2::Card::GS;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::Card::geo_card_param_maps(),

		scale        =>  'f1',
	}->{$key};
}

1;

