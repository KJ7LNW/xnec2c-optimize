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
package NEC2::Word;

use strict;
use warnings;

use NEC2;

use Font::FreeType;
use Math::Bezier;

sub defaults
{
	return (
		ttf => '/usr/share/fonts/liberation/LiberationSans-Regular.ttf',
		size => 1,
		dpi => 0.001,
		text => 'a',

		# Number of segments for each line
		ns => 1,

		# Number of lines per curve
		ns_curve => 3,

		# Starting tag
		tag => 1,

		# x,y,z starting position
		x => 0,
		y => 0,
		z => 0,


		# Not implemented, but specifies the plane for drawing
		#plane => 'xy',
	);
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
use Data::Dumper;
print Dumper $self;

	$self->gen_cards;

	return $self;
}


sub gen_cards
{
	my $self = shift;

	my (@geo, @program);

	my $face = Font::FreeType->new->face($self->{ttf});

	$face->set_char_size($self->{size}, $self->{size}, $self->{dpi}, $self->{dpi});

	$self->{_geo_cards} = \@geo;
	$self->{_program_cards} = \@program;

	my $z = $self->{z};

	my $n = 0;
	my $letter_offset = 0;

	$self->{_tag} = $self->{tag};

	foreach my $char (split //, $self->{text})
	{
		my $glyph = $face->glyph_from_char($char);
		my $width = $glyph->horizontal_advance;
		my $height = $glyph->vertical_advance;

		my @cur_pos;

		print "=== $char ===\n";

		$glyph->outline_decompose(
		    move_to => sub {
			my ( $x, $y ) = @_;
	

			$x += $letter_offset + $self->{x};
			$y += $self->{y};

			if (@cur_pos)
			{
				return if (sqrt(($cur_pos[0]-$x)**2 + ($cur_pos[1]-$y)**2) < 0.0001);
				print "move: $cur_pos[0],$cur_pos[1] -> $x,$y\n";
				$self->add_wire(x1 => $cur_pos[0], y1 => $cur_pos[1], x2 => $x, y2 => $y, z1 => $z, z2 => $z);
			}
			@cur_pos = ($x, $y);
		    },
		    line_to => sub {
			my ( $x, $y ) = @_;

			return if (sqrt(($cur_pos[0]-$x)**2 +($cur_pos[1]-$y)**2) < 0.0001);

			$x += $letter_offset + $self->{x};
			$y += $self->{y};

			if (@cur_pos)
			{
				print "line: $cur_pos[0],$cur_pos[1] -> $x,$y\n";
				$self->add_wire(x1 => $cur_pos[0], y1 => $cur_pos[1], x2 => $x, y2 => $y, z1 => $z, z2 => $z) if @cur_pos;
			}

			@cur_pos = ($x, $y);
		    },
		    cubic_to => sub {
			my ( $x, $y, $cx1, $cy1, $cx2, $cy2 ) = @_;

			return if (sqrt(($cur_pos[0]-$x)**2 +($cur_pos[1]-$y)**2) < 0.0001);

			$x += $letter_offset + $self->{x};
			$cx1 += $letter_offset + $self->{x};
			$cx2 += $letter_offset + $self->{x};

			$y += $self->{y};
			$cy1 += $self->{y};
			$cy2 += $self->{y};

			if (@cur_pos)
			{
				$self->bezier([ @cur_pos, $cx1, $cy1, $cx2, $cy2, $x, $y ]);
				print "cubc: $cur_pos[0],$cur_pos[1] -> $cx1,$cy1 $cx2,$cy2 $x,$y\n";
			}

			@cur_pos = ($x, $y);
		    },
		);
		
		$n++;

		$letter_offset += $width;
	}
}

sub geo_cards
{
	my $self = shift;

	return @{ $self->{_geo_cards} };
}

sub program_cards
{
	my $self = shift;

	return @{ $self->{_program_cards} };
}

sub bezier
{
	my ($self, $points) = @_;

	my $n = $self->{ns_curve};
	
	my $b = Math::Bezier->new($points);
	my $i;
	my @cur_pos = @$points[0,1];
	my $first = 1;
	for ($i = 1; $i < $n; $i++)
	{
		my $pct = $i * (1/($n-1));
		my ($x, $y) = $b->point($pct);
		my $len = sqrt(($cur_pos[0]-$x)**2 + ($cur_pos[1]-$y)**2);
		print "  bezier[$pct]: $x, $y (len=$len)\n";

		next if ($len < 0.0001);

		$self->add_wire(x1 => $cur_pos[0], y1 => $cur_pos[1], x2 => $x, y2 => $y, z1 => $self->{z}, z2 => $self->{z});

		@cur_pos = ($x, $y);
	}
}

sub add_wire
{
	my ($self, %vars) = @_;

	return if ( $vars{x1} == $vars{x2} && $vars{y1} == $vars{y2} && $vars{z1} == $vars{z2});

	return push @{ $self->{_geo_cards} }, GW(%vars, ns => $self->{ns}, tag => $self->{_tag}++)
}

1;
