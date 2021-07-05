package NEC2::EX;

use strict;
use warnings;

use parent 'NEC2';

sub defaults 
{
	return (I1 => 0, I2 => 1, I3 => 1, F1 => 1, F2 => 0);
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
		type => 'I1',
		ex_tag  => 'I2',
		ex_segment => 'I3',
		v_real => 'F1',
		v_imag => 'F2',
	}->{$key};
}

1;

