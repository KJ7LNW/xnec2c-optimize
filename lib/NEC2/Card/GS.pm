package NEC2::GS;

use strict;
use warnings;

use parent 'NEC2';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

		scale        =>  'f1',
	}->{$key};
}

1;

