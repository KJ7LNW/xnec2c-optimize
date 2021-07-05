package NEC2::GN;

use strict;
use warnings;

use parent 'NEC2';

sub defaults
{
	return (I1 => -1, I2 => 0, I3 => 0, I4 => 0, F1 => 0, F2 => 0, F3 => 0, F4 => 0);
}

sub params
{
	return (qw/I1 I2 I3 I4 F1 F2 F3 F4 F5 F6/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		type      => 'I1',
		n_radials => 'I2',
		n_phi     => 'I3',
		xnda      => 'I4',
		epse      => 'F1',
		sig       => 'F2',
	}->{$key};
}

1;
