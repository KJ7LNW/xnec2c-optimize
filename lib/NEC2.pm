package NEC2;

use strict;
use warnings;

use Exporter;

use Math::Vector::Real;
use Math::Matrix;

use NEC2::Card::CM;
use NEC2::Card::EN;
use NEC2::Card::EX;
use NEC2::Card::FR;
use NEC2::Card::GA;
use NEC2::Card::GC;
use NEC2::Card::GE;
use NEC2::Card::GH;
use NEC2::Card::GM;
use NEC2::Card::GN;
use NEC2::Card::GR;
use NEC2::Card::GS;
use NEC2::Card::GW;
use NEC2::Card::GX;
use NEC2::Card::NE;
use NEC2::Card::NT;
use NEC2::Card::RP;
use NEC2::Card::SC;
use NEC2::Card::SM;
use NEC2::Card::SP;
use NEC2::Card::TL;
use NEC2::Card::ZO;

require NEC2::Polyline;

BEGIN {
	our @ISA = qw(Exporter);
	our @EXPORT = (

		# Comment cards
		qw/CM CE/,

		# Geo card functions
		qw/GA GE GF GH GM GR GS GW GC GX SP SM/,

		# Program card functions
		qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ/,

		# xnec2c extensions:
		qw/ZO Z0/,

		# Perl NEC2 extensions:
		qw/Polyline/,
	);
}

use overload '""' => \&stringify;

sub new 
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	$self->{comment} //= 'A blank comment';

	return $self;
}

sub add
{
	my ($self, @cards) = @_;

	foreach my $card (@cards)
	{
		push @{ $self->{comment_cards} }, $card->comment_cards();
		push @{ $self->{geo_cards} }, $card->geo_cards();
		push @{ $self->{program_cards} }, $card->program_cards();
	}

	return $self;
}


sub comment_cards
{
	my $self = shift;
	return @{ $self->{comment_cards} };
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

sub card_filter
{
	my ($self, $card, @cards) = @_;

	if (!@cards)
	{
		die "card_filter($card): No cards were defined for filtering";
	}

	$card = uc($card);

	my @filter;
	if ($card =~ s/^!//) {
		@filter = grep { $_->card_name ne $card } @cards;
	}
	else
	{
		@filter = grep { $_->card_name eq $card } @cards;
	}

	die "filter for $card returned >1 result, but !wantarray" if (@filter > 1 && !wantarray);
	return @filter if (wantarray);
	return $filter[0];
}

sub geo_card_filter
{
	my ($self, $card) = @_;

	return $self->card_filter($card, $self->geo_cards());
}

sub program_card_filter
{
	my ($self, $card) = @_;

	return $self->card_filter($card, $self->program_cards());
}

# Returns shortest line: [ [x1,y1,z1], [x2,y2,z2], distance ].  
# If askew lines cross (or nearly-intersect) then xyz1 and xyz2 are undefined
# and only distance is returned.
#
# Thank you to @Fnord: https://stackoverflow.com/a/18994296/14055985
sub lines_intersect
{
	# Map @_ as vectors:
	my ($a0, $a1, $b0, $b1) = map { V(@{ $_ }) } @_;

	my $A = ($a1-$a0);
	my $B = ($b1-$b0);

	my $magA = abs($A);
	my $magB = abs($B);

	# If length line segment:
	if ($magA == 0 || $magB == 0)
	{
		return V(undef, undef, 0);
	}

	my $_A = $A / $magA;
	my $_B = $B / $magB;

	my $cross = $_A x $_B;
	my $denom = $cross->norm2;

	# If lines are parallel (denom=0) test if lines overlap.
	# If they don't overlap then there is a closest point solution.
	# If they do overlap, there are infinite closest positions, but there is a closest distance
	if ($denom > -1e-6 && $denom < 1e-6) # $denom == 0
	#if ($denom == 0)
	{
		my $d0 = $_A * ($b0-$a0);
		my $d1 = $_A * ($b1-$a0);

		# Is segment B before A?
		if ($d0 <= 1e-6 && -1e-6 >= $d1)
		{
			if (abs($d0) < abs($d1)+1e-6)
			{
				return V($a0, $b0, abs($a0-$b0));
			}
			else
			{
				return V($a0, $b1, abs($a0-$b1));
			}
		}
		# Is segment B after A?
		elsif ($d0+1e-6 >= $magA && $magA <= $d1+1e-6)
		{
			if (abs($d0) < abs($d1))
			{
				return V($a1, $b0, abs($a1-$b0));
			}
			else
			{
				return V($a1, $b1, abs($a1-$b1));
			}
		}
		else
		{
			# Segments overlap, return distance between parallel segments
			return V(V(), V(), abs((($d0*$_A)+$a0)-$b0));
		}

	}
	else
	{
		# Lines criss-cross: Calculate the projected closest points
		my $t = ($b0 - $a0);

		# Math::Matrix won't wirth with Math::Vector::Real
		# even though they are blessed arrays, 
		# so convert them to arrays and back to refs:
		my $detA = Math::Matrix->new([ [ @$t ], [ @$_B ], [ @$cross] ])->det;
		my $detB = Math::Matrix->new([ [ @$t ], [ @$_A ], [ @$cross] ])->det;

		my $t0 = $detA / $denom;
		my $t1 = $detB / $denom;

		my $pA = $a0 + ($_A * $t0); # Projected closest point on segment A
		my $pB = $b0 + ($_B * $t1); # Projected closest point on segment A

		if ($t0 < 0+1e-6)
		{
			$pA = $a0;
		}
		elsif ($t0+1e-6 > $magA)
		{
			$pA = $a1;
		}

		if ($t1 < 0+1e-6)
		{
			$pB = $b0;
		}
		elsif ($t1+1e-6 > $magB)
		{
			$pB = $b1;
		}

		# Clamp projection A
		if ($t0 < 0+1e-6 || $t0+1e-6 > $magA)
		{
			my $dot = $_B * ($pA-$b0);
			if ($dot < 0)
			{
				$dot = 0;
			}
			elsif ($dot > $magB)
			{
				$dot = $magB;
			}

			$pB = $b0 + ($_B * $dot)
		}
		
		# Clamp projection B
		if ($t1 < 0+1e-6 || $t1+1e-6 > $magB)
		{
			my $dot = $_A * ($pB-$a0);
			if ($dot < 0+1e-6)
			{
				$dot = 0;
			}
			elsif ($dot+1e-6 > $magA)
			{
				$dot = $magA;
			}

			$pA = $a0 + ($_A * $dot)
		}

		return V($pA, $pB, abs($pA-$pB));
	}
}

sub test_gw_intersections
{
	my ($self) = @_;

=pod
	print "sample:" . lines_intersect(
		GW(points  =>  [[ 0, 0, 0.955 ],  [ -0.20125, 0, 0.995 ]]),
		GW(points  =>  [[ -0.20125, 0, 0.995 ],  [ -0.27125, 0, 0.995 ]]))  .  "\n"  ;
	#exit;
	# validation:
	print "example: " . lines_intersect(
		GW(points  =>  [[13.43,  21.77,  46.81  ],  [27.83,  31.74,  -26.60  ]]),
		GW(points  =>  [[77.54,  7.53,   6.22   ],  [26.99,  12.39,  11.18   ]]))  .  "\n"  ;

	print "contiguous: " . lines_intersect(
		GW(points  =>  [[0, 0, 0  ],  [ 0, 0, 1  ]]),
		GW(points  =>  [[0, 0, 1  ],  [ 0, 0, 2  ]]),
		)  .  "\n"  ;

	print "contiguous 90: " . lines_intersect(
		GW(points  =>  [[0, 0, 0  ],  [ 0, 0, 1  ]]),
		GW(points  =>  [[0, 0, 1  ],  [ 0, 1, 1  ]]),
		)  .  "\n"  ;

	print "colinear separate: " . lines_intersect(
		GW(points  =>  [[0, 0, 0  ],  [ 0, 0, 1  ]]),
		GW(points  =>  [[0, 0, 2  ],  [ 0, 0, 3  ]]),
		)  .  "\n"  ;

	print "cross: " . lines_intersect(
		GW(points  =>  [[1, 1, 0  ],  [ -1, -1, 0  ]]),
		GW(points  =>  [[-1, 1, 0  ],  [ 1, -1, 0  ]]),
		)  .  "\n"  ;

	print "cross+z: " . lines_intersect(
		GW(points  =>  [[1, 1, 0  ],  [ -1, -1, 0  ]]),
		GW(points  =>  [[-1, 1, 1  ],  [ 1, -1, 1  ]]),
		)  .  "\n"  ;

	print "full overlap1: " . lines_intersect(
		GW(points  =>  [[2, 0, 0  ],  [ 5, 0, 0  ]]),
		GW(points  =>  [[3, 0, 0  ],  [ 4, 0, 0  ]]),
		)  .  "\n"  ;

	print "full overlap2: " . lines_intersect(
		GW(points  =>  [[3, 0, 0  ],  [ 4, 0, 0  ]]),
		GW(points  =>  [[2, 0, 0  ],  [ 5, 0, 0  ]]),
		)  .  "\n"  ;

	print "partial overlap1: " . lines_intersect(
		GW(points  =>  [[2, 0, 0  ],  [ 5, 0, 0  ]]),
		GW(points  =>  [[3, 0, 0  ],  [ 6, 0, 0  ]]),
		)  .  "\n"  ;

	print "partial overlap2: " . lines_intersect(
		GW(points  =>  [[3, 0, 0  ],  [ 6, 0, 0  ]]),
		GW(points  =>  [[2, 0, 0  ],  [ 5, 0, 0  ]]),
		)  .  "\n"  ;

	print "parallel: " . lines_intersect(
		GW(points  =>  [[3, 0, 0  ],  [ 6, 0, 0  ]]),
		GW(points  =>  [[3, 0, 1  ],  [ 6, 0, 1  ]]),
		)  .  "\n"  ;

	# output:
	#example: {{20.29994361624, 26.5264817954106, 11.7875999397098}, {26.99, 12.39, 11.18}, 15.6513944955904}
	#contiguous: {{0, 0, 1}, {0, 0, 1}, 0}
	#contiguous 90: {{0, 0, 1}, {0, 0, 1}, 0}
	#colinear separate{{0, 0, 1}, {0, 0, 2}, 1}
	#cross: {{-2.22044604925031e-16, -2.22044604925031e-16, 0},
	#	{2.22044604925031e-16, -2.22044604925031e-16, 0},
	#	4.44089209850063e-16}
	#cross+z: {{-2.22044604925031e-16, -2.22044604925031e-16, 0},
	#	{2.22044604925031e-16, -2.22044604925031e-16, 1},
	#	1}
	#full overlap1: {{}, {}, 0}
	#full overlap2: {{}, {}, 0}
	#partial overlap1: {{}, {}, 0}
	#partial overlap2: {{}, {}, 0}
	#parallel: {{}, {}, 1}

=cut

#exit;
	my @gw = $self->geo_card_filter('GW');
	my @intersecting_cards;

	foreach my $A (@gw)
	{
		my $tag1 = $A->get('tag');

		foreach my $B (@gw)
		{
			my $tag2 = $B->get('tag');


			# Skip the GW of itself. FIXME: This breaks if the tags are the same!
			next if $tag1 == $tag2;

			my $inter = lines_intersect($A->get_points, $B->get_points);
			#print "inter[$tag1, $tag2]: $inter\n";

			# Skip if they have a nontrivial distance:
			next if $inter->[2] < -1e-6 || $inter->[2] > 1e-6;

			# Skip if they are connected endpoints with a nearly-zero distance:
			next if defined($inter->[0]) && defined($inter->[1]) && 
				abs($inter->[0] - $inter->[1])<1e-6 && # approximately thsame point
				-1e-6 < $inter->[2] && $inter->[2] < 1e-6;

			# Skip if they have a distance:
			next if ($inter->[2] < -1e-6 || 1e-6 < $inter->[2]) ;

			push @intersecting_cards, [$A, $B];
			# Report all others:
			print "inter[$tag1, $tag2]: $inter\n";
			use Data::Dumper;
			print "Overlap tags $tag1 and $tag2: " . Dumper([$A->get_points], [$B->get_points]);
		}
	}

	return @intersecting_cards;
}

sub stringify
{
	my ($self) = @_;

	my $ret = '';

	if (defined($self->{comment}) && ref($self->{comment}) eq 'ARRAY')
	{
		$ret .= CM(comment => $_) foreach (@{ $self->{comment} });
	}
	else {
		$ret .= CM(comment => $self->{comment});
	}

	$ret .= $_ foreach ($self->comment_cards);

	$ret .= CE();
	
	# always put the GE card at the end of the geometry.  Default to freespace GE if
	# none was defined:
	my $GE = $self->geo_card_filter('GE');
	$GE //= GE();

	# exclude GE, it goes above
	my @geo = $self->geo_card_filter('!GE');
	
	# exclude EN cards because they go at the end:
	my @program = $self->program_card_filter('!EN');

	$ret .= join('', @geo);
	$ret .= $GE;

	$ret .= join('', map { "$_" } @program);
	$ret .= EN();

	return $ret;
}

sub save
{
	my ($self, $fn) = @_;

	$fn or die "invalid filename: $fn";

	my @intersecting_cards = $self->test_gw_intersections;
	if (@intersecting_cards)
	{
		print "$self" . "\n";
		use Data::Dumper;
		print "intersecting_cards: " . Dumper(\@intersecting_cards);
		exit;
	}


	open(my $structure, ">", $fn) or die "$!: $fn";

	print $structure $self;
	close($structure);
}


#####################################################################
# Static Functions

###########################################################
# Card shortcuts:

# Comment cards
sub CM { return NEC2::Card::CM->new(@_) }  # Comment
sub CE { return NEC2::Card::CE->new(@_) }  # Comment End

# Geo cards
sub GA { return NEC2::Card::GA->new(@_) }  # Arc
sub GH { return NEC2::Card::GH->new(@_) }  # Helix
sub GW { return NEC2::Card::GW->new(@_) }  # Wire
sub GC { return NEC2::Card::GC->new(@_) }  # Tapered wire
sub SP { return NEC2::Card::SP->new(@_) }  # Surface Patch
sub SM { return NEC2::Card::SM->new(@_) }  # Multiple Surface Patch
sub SC { return NEC2::Card::SC->new(@_) }  # Additional SC card for SP and SM (internal)

# Transform cards
sub GM { return NEC2::Card::GM->new(@_) }  # Move
sub GR { return NEC2::Card::GR->new(@_) }  # Rotate
sub GS { return NEC2::Card::GS->new(@_) }  # Scale
sub GX { return NEC2::Card::GX->new(@_) }  # Reflection

# Special cards
sub GF { return NEC2::Card::GF->new(@_) }  # Read NGF File
sub GE { return NEC2::Card::GE->new(@_) }  # Geo End

# Program card shortcuts:
sub CP { return NEC2::Card::CP->new(@_) }  # Maximum coupling Calculation
sub EK { return NEC2::Card::EK->new(@_) }  # Extended Thin-Wire Kernel
sub EN { return NEC2::Card::EN->new(@_) }  # End of Run
sub EX { return NEC2::Card::EX->new(@_) }  # Excitation
sub FR { return NEC2::Card::FR->new(@_) }  # Frequency
sub GD { return NEC2::Card::GD->new(@_) }  # Additional Ground Parameters
sub GN { return NEC2::Card::GN->new(@_) }  # Ground Parameters
sub KH { return NEC2::Card::KH->new(@_) }  # Interaction Approximation Range
sub LD { return NEC2::Card::LD->new(@_) }  # Loading
sub NE { return NEC2::Card::NE->new(@_) }  # Near Fields (E: E field)
sub NH { return NEC2::Card::NH->new(@_) }  # Near Fields (H: Mag field)
sub NT { return NEC2::Card::NT->new(@_) }  # Networks
sub NX { return NEC2::Card::NX->new(@_) }  # Next Structure
sub PQ { return NEC2::Card::PQ->new(@_) }  # Print Control for Charge on Wires
sub PT { return NEC2::Card::PT->new(@_) }  # Print Control for Current on Wires
sub RP { return NEC2::Card::RP->new(@_) }  # Radiation Pattern
sub TL { return NEC2::Card::TL->new(@_) }  # Transmission Line 
sub WG { return NEC2::Card::WG->new(@_) }  # Write NGF File
sub XQ { return NEC2::Card::XQ->new(@_) }  # Execute

# xnec2c extensions
sub ZO { return NEC2::Card::ZO->new(@_) }  # Charectaristic Impedance
sub Z0 { return NEC2::Card::ZO->new(@_) }  # Charectaristic Impedance (Z-zero alias)

# Perl NEC2 extensions:
sub Polyline { return NEC2::Polyline->new(@_) }  # GW card generator

1;
