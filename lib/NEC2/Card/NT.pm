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
package NEC2::Card::NT;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
}


# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {
		tag_p1       =>  'i1',
		seg_p1       =>  'i2',
		tag_p2       =>  'i3',
		seg_p2       =>  'i4',

		y11r         =>  'f1',
		y11i         =>  'f2',

		y12r         =>  'f3',
		y12i         =>  'f4',

		# The admittance matrix is symmetric so it is unnecessary to specify element (2, 1). 
		# so this is an alias:
		y21r         =>  'f3',
		y21i         =>  'f4',

		y22r         =>  'f5',
		y22i         =>  'f6',
	};
}

1;

