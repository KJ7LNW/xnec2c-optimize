package NEC2::Card::GA;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002); 
}

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::Card::geo_card_param_maps(),

		itg       =>  'i1',
		tag       =>  'i1',

		ns        =>  'i2',

		rada      =>  'f1',
		arc_rad   =>  'f1',

		ang1      =>  'f2',
		ang2      =>  'f3',

		rad       =>  'f4',
		wire_rad  =>  'f4',
	}->{$key};
}

1;
