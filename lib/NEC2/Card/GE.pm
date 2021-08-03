package NEC2::Card::GE;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults
{
	# gpflag - Geometry ground plain flag.

	# 0 - no ground plane is present. 
	# 1 - Indicates a ground plane is present. Structure symmetry is modified
	#     as required, and the current expansion is modified so that the currents
	#     an segments touching the ground (x, Y plane) are interpolated to their
	#     images below the ground (charge at base is zero)
	# -1 - indicates a ground is present. Structure symmetry is modified as
	#      required. Current expansion, however, is not modified, Thus, currents
	#      on segments touching the ground will go to zero at the ground.
	return (gpflag => 0);
}

sub param_map
{
	my ($self, $key) = @_;
	return {
		i1 => 0,

		gpflag => 'i1',
		ground => 'i1'
	}->{$key};
}

1;

