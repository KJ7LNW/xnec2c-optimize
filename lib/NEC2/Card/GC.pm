package NEC2::Card::GC;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	return {
		
		# for tapered GC card
		rdel => 'f1',
		rad1 => 'f2',
		rad2 => 'f3'
	};
}

1;
