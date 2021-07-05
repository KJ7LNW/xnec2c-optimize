package NEC2::GW;

use strict;
use warnings;

use parent 'NEC2';

sub params
{
	return (qw/ITG NS XW1 YW1 ZW1 XW2 YW2 ZW2 RAD RDEL RAD1 RAD2/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
	  	tag => 'ITG',
		x  => 'XW1',
		y  => 'YW1',
		z  => 'ZW1',
		x2 => 'XW2',
		y2 => 'YW2',
		z2 => 'ZW2'
	}->{$key};
}

1;
