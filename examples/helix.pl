#!/usr/bin/perl
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
#  Copyright (C) 2021- by Eric Wheeler, KJ7LNW and Zeke Wheeler, KJ7NLL.
#  All rights reserved.


# This is an example of how to use the Perl code to create NEC2 geometries.
# This is much simpler than "SY" implementations because the different cards
# have variable name pneumonics that make easier to understand. Additionally,
# math can be performed inline to each argument. While this example is not
# intended for optimization, it could be modified has an optimized example.
#
# To run this example, follow the instructions in the comments below to make
# any changes that you would like, and run the script as: 
#
#   ]$ ./examples/helix.pl helix.nec
#
# You can then open the resulting .NEC file using xnec2c.  Using xnec2c
# optimization feature, you can modify the Perl script, and when you run it,
# xnec2c will automatically update when the output file has changed:
#
#   ]$ xnec2c --optimize -j `nproc` helix.nec 

use strict;
use warnings;
use Data::Dumper;

use lib 'lib';

use NEC2;
use NEC2::Antenna::Yagi;

if (!@ARGV)
{
	print "usage: $0 outputfile.nec\n";
	exit 1;
}

my $filename = shift;

my $nec = NEC2->new(comment => [
		"Dual-band coaxial helical antenna, by KJ7NLL",
		"Watch the presentation: https://youtu.be/vKeOOaMB4ZQ",
		"Excite helix1 or helix2 by setting EX to tag 91 or 92",
	]);

#######################################################################
# Set your excitation frequencies and bandwidth

my $mhz1 = 146;
my $mhz1_bandwidth = 4;

my $mhz2 = 435;
my $mhz2_bandwidth = 30;

#######################################################################
# Choose which helix to excite.  The other helix will be grounded:

my $ex_tag = 91; # Excite helix1
#my $ex_tag = 92; # Excite helix2

#######################################################################
# Adjust the surface size if necessary. It defaults to the wavelength of mhz1
# (divided by 2, because of +/- coordinates in the NEC2 cards below):
my $surface_size_m = (300/$mhz1)/2;

# Distance from helixes to the ground plane in meters:
my $helix_loft = 0.050;

$nec->add(
	#######################################################################
	# Geometry Cards

	# helix1
	GH(tag => 1, ns => 500, s => 0.14, length => 0.14*21,
		rx1 => 300/($mhz1*2*3.14149),
		ry1 => 300/($mhz1*2*3.14149),
		rx2 => 300/($mhz1*2*3.14149),
		ry2 => 300/($mhz1*2*3.14149)),

	# helix2
	GH(tag => 2, ns => 800, s => 0.14, length => 0.14*21,
		rx1 => 300/($mhz2*2*3.14149),
		ry1 => 300/($mhz2*2*3.14149),
		rx2 => 300/($mhz2*2*3.14149),
		ry2 => 300/($mhz2*2*3.14149)),

	GM(tag_start => 1, sz => $helix_loft), # move +z 1cm for both helixes

	# Add a "+" of ground wires at the surface, and a circle around the excitation
	# so it connects well to the surface patch below.
	GW(tag => 4, x1 => -$surface_size_m, x2 => $surface_size_m),
	GW(tag => 4, y1 => -$surface_size_m, y2 => $surface_size_m),

	GA(tag => 5, ns => 100, rada => 300/($mhz1*2*3.14149) ),
	GA(tag => 6, ns => 100, rada => 300/($mhz2*2*3.14149) ),
	GM(tag_start => 5, rox => 90), # rotate the circles to be flat


	SM(nx => 8, ny => 8,
		x1 => -$surface_size_m, y1 => -$surface_size_m, z1 => 0,
		x2 => $surface_size_m, y2 => -$surface_size_m, z2 => 0,
		x3 => $surface_size_m, y3 => $surface_size_m, z3 => 0), 

	# One of these get excited, so change $ex_tag above to excite one or the other.
	# These are always defined for both frequencies so the helix that is not excited
	# will be grounded:
	GW(tag => 91, ns => 10, x1 => 300/($mhz1*2*3.14149), x2 => 300/($mhz1*2*3.14149), z2 => $helix_loft),
	GW(tag => 92, ns => 10, x1 => 300/($mhz2*2*3.14149), x2 => 300/($mhz2*2*3.14149), z2 => $helix_loft),

	#######################################################################
	# Commands Cards
	#
	GE(ground => 0),
	EX(ex_tag => $ex_tag),
	RP(ground => 0),
	NH,
	NE,
	#FR(mhz_min => 50, mhz_max => 54, n_freq => 10),

	# Draw the FR plot depending on the excited frequency.  These
	# lines use Perl's ternary operator to only show the frequency for the excited
	# helix: 
	$ex_tag == 91
		? FR(mhz_min => $mhz1 - $mhz1_bandwidth/2, mhz_max => $mhz1 + $mhz1_bandwidth/2, n_freq => 20)
		: FR(mhz_min => $mhz2 - $mhz2_bandwidth/2, mhz_max => $mhz2 + $mhz2_bandwidth/2, n_freq => 20)

	# Xnec2c supports displaying multiple FR cards, so list them both if you wish by commenting
	# the 3 lines above and enabling these two:
	#FR(mhz_min => $mhz1 - $mhz1_bandwidth/2, mhz_max => $mhz1 + $mhz1_bandwidth/2, n_freq => 20),
	#FR(mhz_min => $mhz2 - $mhz2_bandwidth/2, mhz_max => $mhz2 + $mhz2_bandwidth/2, n_freq => 20),
	);

$nec->save($filename);

print $nec;
