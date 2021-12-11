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
package NEC2::Card::CM;

use strict;
use warnings;

use parent 'NEC2::Card';

use overload '""' => \&stringify;


sub param_map
{
	return { comment => 0 };
}


# this seems cumbersome to override stringify, but CM is neither a geo_card nor a program_card
# so ... this works to split the card into multiple lines. Maybe there should be 
# comment_cards() and is_comment_card() functions.
sub stringify
{
	my $self = shift;

	my @ret;
	if (defined($self->{card}) && defined($self->{card}->[0]) && $self->{card}->[0] =~ /[\r\n]/s)
	{
		foreach my $comment (split /[\r\n]/, $self->{card}->[0])
		{
			push @ret, NEC2::Card::CM->new(comment => $comment);
		}
	}
	else
	{
		return $self->SUPER::stringify();
	}

	return join('', @ret);
}

1;


# Nothing special about CE, so use CM.
package NEC2::Card::CE;
use parent 'NEC2::Card::CM';

1;
