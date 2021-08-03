package NEC2::Card::CM;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	# always return 0, there is only one index:
	return 0;
}

1;


# Nothing special about CE, so use CM.
package NEC2::Card::CE;
use parent 'NEC2::Card::CM';

1;
