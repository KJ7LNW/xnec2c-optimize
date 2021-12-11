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
package NEC2::Card::SP;

use strict;
use warnings;

use parent 'NEC2::Card';


sub param_map
{
	return {

		ns =>  'i2',
		shape =>  'i2',

		x1 =>  'f1',
		y1 =>  'f2',
		z1 =>  'f3',

		x2 =>  'f4',
		elevation =>  'f4',

		y2 =>  'f5',
		azimuth =>  'f5',

		z2 =>  'f6',
		area =>  'f6',

	};
}

sub geo_cards
{
	my $self = shift;


	# if ns is 1,2,3 then a second SC card exists:
	if ($self->get('ns') =~ /^[12]$/)
	{
		if (
			!$self->{x3} ||
			!$self->{y3} ||
			!$self->{z3})
		{
			die "GW: x3, y3, and z3 must be defined when ns is 2, or 3";
		}
	}

	if ($self->get('ns') == 3)
	{
		if (
			!$self->{x4} ||
			!$self->{y4} ||
			!$self->{z4})
		{
			die "GW: x4, y4, and z4 must be defined when ns is 3";
		}
	}


	my @cards = ($self);

	if ($self->get('ns') =~ /^[123]$/)
	{
		push @cards,
			NEC2::Card::SC->new(
				i2 => $self->get('ns'),
				x3 => $self->{x3}, 
				y3 => $self->{y3}, 
				z3 => $self->{z3}, 

				x4 => $self->{x4}, 
				y4 => $self->{y4}, 
				z4 => $self->{z4}, 
			);
				
	}

	return @cards;
}


1;
