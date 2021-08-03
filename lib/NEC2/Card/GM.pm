package NEC2::GM;

use strict;
use warnings;

use parent 'NEC2';

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

		itsi       =>  'i1',
		nrpt       =>  'i2',
		rox        =>  'f1',
		roy        =>  'f2',
		roz        =>  'f3',
		xs         =>  'f4',
		ys         =>  'f5',
		zs         =>  'f6',
		its        =>  'f7',

		tag_inc    =>  'itsi',
		tag_start  =>  'its',
		
		# Number of copies
		new        =>  'nrpt',
		num        =>  'nrpt',
		n          =>  'nrpt',

		# Rotate about x/y/z
		rx         =>  'rox',
		ry         =>  'roy',
		rz         =>  'roz',

		# Translate x/y/z
		sx         =>  'xs',
		sy         =>  'ys',
		sz         =>  'zs',
	}->{$key};
}

1;

