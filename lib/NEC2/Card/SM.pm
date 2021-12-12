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
package NEC2::Card::SM;

use strict;
use warnings;

use NEC2::Card::SC;
use parent 'NEC2::Card';


sub param_map
{
	return {

		nx =>  'i1',
		ny =>  'i2',

		x1 =>  'f1',
		y1 =>  'f2',
		z1 =>  'f3',

		x2 =>  'f4',
		y2 =>  'f5',
		z2 =>  'f6',
	};
}

sub get_special
{
	my ($self, $var) = @_;

	if ($var =~ /^[xyz]3$/)
	{
		return $self->{$var}
	}

	return undef;
}

sub set_special
{
	my ($self, $var, $val) = @_;

	if ($var =~ /^[xyz]3$/)
	{
		$self->{$var} = $val;
		return 1;
	}

	return 0;
}

sub geo_cards
{
	my $self = shift;

	return ($self, 
		NEC2::Card::SC->new(
			x3 => $self->{x3}, 
			y3 => $self->{y3}, 
			z3 => $self->{z3}, 
			)
		);
}

1;
