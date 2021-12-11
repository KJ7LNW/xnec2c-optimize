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
package NEC2::Polyline;

use parent 'NEC2::Shape';

use strict;
use warnings;

use NEC2;


sub defaults
{
	return ( );
}


# points => [ [x,y,z], [x,y,z], [x,y,z], ... ]
sub new 
{
	my ($class, %args) = @_;
	my $self = bless(\%args, $class);

	my %defaults = $self->defaults;
	foreach my $k (keys %defaults)
	{
		$self->{$k} //= $defaults{$k};
	}

	$self->gen_cards;

	return $self;
}


sub gen_cards
{
	my $self = shift;

	my (@geo, @program);
	my $prev;

	die "Must have at least 2 points" if (scalar(@{ $self->{points} }) < 2);

	$self->{_tag} = $self->{tag};

	foreach my $point (@{ $self->{points} })
	{
		if ($prev)
		{
			# All parameters in $self except 'points' and 'tag' are passed to GW:
			my $gw = GW(points => [ $prev => $point ], 
				tag => $self->{_tag}++,
				map { $_ => $self->{$_} } grep { $_ !~ /(^_|points$|tag$)/ } keys %$self);

			push @geo, $gw;
		}
		$prev = $point;
	}

	$self->{_geo_cards} = \@geo;
}

sub geo_cards
{
	my $self = shift;

	return @{ $self->{_geo_cards} };
}

sub program_cards
{
	my $self = shift;

	return ();
}

1;
