package NEC2::FR;

use strict;
use warnings;

use parent 'NEC2';

sub defaults
{
	return (I1 => 0, I2 => 10, F1 => 144, F2 => 144/9, );
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
		type          => 'I1',
		n_freq        => 'I2',
		mhz           => 'F1',
		mhz_inc       => 'F2',
	}->{$key};
}

1;
