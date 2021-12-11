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
package NEC2::Card::GM;

use strict;
use warnings;

use parent 'NEC2::Card';

sub param_map
{
	return {

		itsi       =>  'i1',
		nrpt       =>  'i2',
		rox        =>  'f1',
		roy        =>  'f2',
		roz        =>  'f3',
		xs         =>  'f4',
		ys         =>  'f5',
		zs         =>  'f6',
		its        =>  'f7',

		tag_inc    =>  'itsi',
		tag_start  =>  'its',
		
		# Number of copies
		new        =>  'nrpt',
		num        =>  'nrpt',
		n          =>  'nrpt',

		# Rotate about x/y/z
		rx         =>  'rox',
		ry         =>  'roy',
		rz         =>  'roz',

		# Translate x/y/z
		sx         =>  'xs',
		sy         =>  'ys',
		sz         =>  'zs',
	};
}

1;

