package NEC2::GM;

use strict;
use warnings;

use parent 'NEC2';

sub params
{
	return (qw/ITSI NRPT ROX ROY ROZ XS YS ZS ITS/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		tag_inc   => 'ITSI',
		tag_start => 'ITS',
		new       => 'NRPT',
		num       => 'NRPT',
		n         => 'NRPT',
		rx        => 'ROX',
		ry        => 'ROY',
		rz        => 'ROZ',
		sx        => 'XS',
		sy        => 'YS',
		sz        => 'ZS',
	}->{$key};
}

1;

