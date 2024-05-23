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
package NEC2::Card::GA;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002, ang1 => 0, ang2 => 360);
}

sub param_map
{
	return {

		itg       =>  'i1',
		tag       =>  'i1',

		ns        =>  'i2',

		rada      =>  'f1',
		arc_rad   =>  'f1',

		ang1      =>  'f2',
		ang2      =>  'f3',

		rad       =>  'f4',
		wire_rad  =>  'f4',
	};
}

1;
