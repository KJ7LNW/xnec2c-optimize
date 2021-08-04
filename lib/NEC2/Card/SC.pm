package NEC2::Card::SC;

use strict;
use warnings;

use parent 'NEC2::Card';


sub param_map
{
	my ($self, $key) = @_;
	return {
		
		ns    => 'i2',
		shape => 'i2',

		x3 =>  'f1',
		y3 =>  'f2',
		z3 =>  'f3',

		x4 =>  'f4',
		y4 =>  'f5',
		z4 =>  'f6',
	};
}

1;
