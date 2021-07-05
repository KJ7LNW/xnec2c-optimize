package NEC2::GE;

use strict;
use warnings;

use parent 'NEC2';

sub params
{
	return (qw/I1/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		ground => 'I1'
	}->{$key};
}

1;

