package NEC2::Card::GX;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	return {

		itsi       =>  'i1',
		planes     =>  'i2',
	};
}

1;

