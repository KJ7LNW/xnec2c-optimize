#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Library General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# 
#  Copyright (C) 2021- by Eric Wheeler, KJ7LNW.  All rights reserved.
#
#  The official website and doumentation for xnec2c-optimizer is available here:
#    https://www.xnec2c.org/
#
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
	return {
		i1 => 0,

		gpflag => 'i1',
		ground => 'i1'
	};
}

1;

