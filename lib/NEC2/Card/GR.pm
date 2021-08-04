package NEC2::Card::GR;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	return {

		itsi       =>  'i1',
		nrpt       =>  'i2',
		n          =>  'i2',
		num        =>  'i2',
	};
}

1;

