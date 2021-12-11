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
package NEC2::Antenna::Yagi;

use NEC2;

use parent 'NEC2::Shape';

use strict;
use warnings;


sub defaults
{
	return (plane => 'xz', 
		wire_segments => 31,
		wire_rad => 0.002,
		tag => 1);
}

sub new 
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	my %defaults = $self->defaults;
	foreach my $k (keys %defaults)
	{
		$self->{$k} //= $defaults{$k};
	}

	#use Data::Dumper;
	#print Dumper $self;
	
	die "plane must be xy, xz, or yz: $self->{plane}" if ($self->{plane} !~ /^xy|xz|yz$/);
	die "wire_segments must be odd: $self->{wire_segments}" if ($self->{wire_segments} % 2 == 0);

	$self->gen_cards;

	return $self;
}

sub gen_cards
{
	my $self = shift;
	my (%vars) = @_;

	my $lengths = $self->{lengths};
	my $spaces = $self->{spaces};

	my $n_segments = $self->{wire_segments} ; # must be odd!

	#print "lengths: $lengths\n";
	#print "spaces: $spaces\n";
	my @geo;
	my @program;

	$self->{geo_cards} = \@geo;
	$self->{program_cards} = \@program;

	
	my ($a, $b) = split //, $self->{plane};

	my $zoff = 0;
	for (my $i = 0 ; $i < @$lengths ; $i++) {
		my $l = $lengths->[$i];
		my $s = $spaces->[$i];
		
		# spaces are distances between so accumulate the Z offset
		$zoff += $s;
		
		# left and right of zero
		$l /= 2; 
		push(@geo,
			GW(
				tag      =>  $self->{tag} + $i,
				ns       =>  $n_segments,
				"${a}1"  =>  $l,                   "${a}2"  =>  -$l,
				"${b}1"  =>  $zoff,                "${b}2"  =>  $zoff,
				rad      =>  $self->{wire_rad}

			)
		);

	}

	# End of geometry and program parameters:
	push @program, 
		EX(
			ex_tag => $self->{tag} + 1, 
			ex_segment => int($n_segments / 2) + 1);


	# Really nothing to return, geo and program cards are stored in the class
	return $self;
}

sub geo_cards
{
	my $self = shift;

	return @{ $self->{geo_cards} };
}

sub program_cards
{
	my $self = shift;

	return @{ $self->{program_cards} };
}

1;
