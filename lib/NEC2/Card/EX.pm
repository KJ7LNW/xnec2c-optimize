package NEC2::Card::EX;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	return (type => 0, ex_tag => 1, ex_segment => 1, v_real => 1, v_imag => 0);
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {

		type        =>  'i1',
		ex_tag      =>  'i2',
		
		ex_seg      =>  'i3',
		ex_segment  =>  'i3',
		
		v_real      =>  'f1',
		v_imag      =>  'f2',
	};
}

1;

