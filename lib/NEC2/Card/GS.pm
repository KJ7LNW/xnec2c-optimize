package NEC2::Card::GS;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	my ($self, $key) = @_;
	return {

		scale        =>  'f1',
	};
}

1;

