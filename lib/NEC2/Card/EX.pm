package NEC2::EX;

use strict;
use warnings;

use parent 'NEC2';

sub defaults 
{
	return (type => 0, ex_tag => 1, ex_segment => 1, v_real => 1, v_imag => 0);
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::program_card_param_maps(),

		type        =>  'I1',
		ex_tag      =>  'I2',
		
		ex_seg      =>  'I3',
		ex_segment  =>  'I3',
		
		v_real      =>  'F1',
		v_imag      =>  'F2',
	}->{$key};
}

1;

