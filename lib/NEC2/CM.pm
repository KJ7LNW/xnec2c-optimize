package NEC2::CM;

use strict;
use warnings;

use parent 'NEC2';

sub params
{
	return (qw/comment/);
}

sub param_map
{
	return undef;
}



1;


# Nothing special about CE, so use CM.
package NEC2::CE;
use parent 'NEC2::CM';
