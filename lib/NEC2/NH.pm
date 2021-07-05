package NEC2::NH;

use strict;
use warnings;

use parent 'NEC2';

sub params
{
	return (qw/I1 I2 I3 I4 F1 F2 F3 F4 F5 F6/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		near          => 'I1',
	}->{$key};
}

1;
