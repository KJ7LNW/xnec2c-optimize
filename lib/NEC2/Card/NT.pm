package NEC2::Card::NT;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {
		tag_p1       =>  'i1',
		seg_p1       =>  'i2',
		tag_p2       =>  'i3',
		seg_p2       =>  'i4',

		y11r         =>  'f1',
		y11i         =>  'f2',

		y12r         =>  'f3',
		y12i         =>  'f4',

		# The admittance matrix is symmetric so it is unnecessary to specify element (2, 1). 
		# so this is an alias:
		y21r         =>  'f3',
		y21i         =>  'f4',

		y22r         =>  'f5',
		y22i         =>  'f6',
	};
}

1;

