package NEC2::Card::NE;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults
{
	# default rectangular coordinates:
	return (near => 0);
}

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::Card::program_card_param_maps(),
		near => 'i1',

		# rectangular coordinates (near = 0):
		nrx   =>  'i2',
		nry   =>  'i3',
		nrz   =>  'i4',

		xnr   =>  'f1',
		ynr   =>  'f2',
		znr   =>  'f3',

		dxnr  =>  'f4',
		dynr  =>  'f5',
		dznr  =>  'f6',
		
		# spherical coordinates (near = 1):
		n_r         =>  'i2',
		n_phi       =>  'i3',
		n_theta     =>  'i4',

		pos_r       =>  'f1',
		pos_phi     =>  'f2',
		pos_theta   =>  'f3',

		step_r      =>  'f4',
		step_phi    =>  'f5',
		step_theta  =>  'f6',

	}->{$key};
}

1;

package NEC2::Card::NH;

use parent 'NEC2::Card::NE';
1;
