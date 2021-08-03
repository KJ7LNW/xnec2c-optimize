package NEC2::GC;

use strict;
use warnings;

use parent 'NEC2';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),
		
		# for tapered GC card
		rdel => 'f1',
		rad1 => 'f2',
		rad2 => 'f3'
	}->{$key};
}

1;
