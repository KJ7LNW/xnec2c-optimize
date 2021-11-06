package NEC2::Card::TL;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	return (z0 => 50);
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {
		tag_p1       =>  'i1',
		seg_p1       =>  'i2',
		tag_p2       =>  'i3',
		seg_p2       =>  'i4',

		z0           =>  'f1',
		length       =>  'f2',
		shunt_re_p1  =>  'f3',
		shunt_im_p1  =>  'f4',
		shunt_re_p2  =>  'f5',
		shunt_im_p2  =>  'f6',
	};
}

1;

