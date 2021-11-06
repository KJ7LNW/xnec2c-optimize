# Charectaristic Impedance: xnec2c extension: https://www.xnec2c.org/#InputFile
package NEC2::Card::ZO;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	return (z0 => 50);
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {
		z0 =>  'i1',
		zo =>  'i1',
	};
}

1;

