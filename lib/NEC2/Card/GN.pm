package NEC2::Card::GN;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults
{
	# default to free-space
	return (type => -1);
}

sub param_map
{
	return {
		type             =>          'i1',
		n_radials        =>          'i2',
		epse             =>          'f1',
		
		# ohms/meter
		sig              =>          'f2',
		conductivity     =>          'f2',

		# if n_radials > 0
		screen_rad       =>          'f3',
		screen_wire_rad  =>          'f4',

		# not sure about values for nradl=0, someone else please make human-readable values
		# or the user can just use f1-6 as appropriate
	};
}

1;
