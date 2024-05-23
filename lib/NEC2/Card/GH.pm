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
package NEC2::Card::GH;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002, spiral_turns => 0);
}

sub param_map
{
	return {

		itg       =>  'i1',
		tag       =>  'i1',

		ns        =>  'i2',

		s         =>  'f1',
		spacing   =>  'f1',

		hl        =>  'f2',
		length    =>  'f2',

		a1        =>  'f3',
		rx1       =>  'f3',

		b1        =>  'f4',
		ry1       =>  'f4',

		a2        =>  'f5',
		rx2       =>  'f5',

		b2        =>  'f6',
		ry2       =>  'f6',

		rad       =>  'f7',
		wire_rad  =>  'f7',
	};
}

sub set_special
{
	my ($self, $var, $val) = @_;

	return 0 unless ($var eq 'length' || $var eq 'ns' || $var eq 'spiral_turns');

	if ($var eq 'length' || $var eq 'ns')
	{
		$self->set_card_var($var, $val);
	}
	elsif ($var eq 'spiral_turns')
	{
		# 'spiral_turns' is internal, so set it in the class
		$self->{spiral_turns} = $val;
	}

	# This will update when ns or spiral_turns is updated:
	if ($self->get('length') == 0 &&
		$self->get('ns') > 0 &&
		$self->{spiral_turns} > 0)
	{
		# The number of spiral spiral_turns is calculated
		# as spacing=$segments/$spiral_turns, but only when
		# length==0.  Not sure if this is an xnec2c extension or
		# if other NEC2 interpreters support it, too:
		$self->set_card_var('spacing', $self->get('ns')/$self->{spiral_turns});
	}

	return 1;
}

1;
