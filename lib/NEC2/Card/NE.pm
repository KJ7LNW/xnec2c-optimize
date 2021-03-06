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
package NEC2::Card::NE;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults
{
	# default rectangular coordinates:
	return (near => 0);
}

sub param_map
{
	return {
		near => 'i1',

		# rectangular coordinates (near = 0):
		nrx   =>  'i2',
		nry   =>  'i3',
		nrz   =>  'i4',

		xnr   =>  'f1',
		ynr   =>  'f2',
		znr   =>  'f3',

		dxnr  =>  'f4',
		dynr  =>  'f5',
		dznr  =>  'f6',
		
		# spherical coordinates (near = 1):
		n_r         =>  'i2',
		n_phi       =>  'i3',
		n_theta     =>  'i4',

		pos_r       =>  'f1',
		pos_phi     =>  'f2',
		pos_theta   =>  'f3',

		step_r      =>  'f4',
		step_phi    =>  'f5',
		step_theta  =>  'f6',

	};
}

1;

package NEC2::Card::NH;

use parent 'NEC2::Card::NE';
1;
