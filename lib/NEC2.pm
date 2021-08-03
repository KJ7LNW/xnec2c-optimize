package NEC2;

use strict;
use warnings;

use Exporter;

use Carp;

$SIG{__DIE__} = sub { Carp::confess() };

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
use NEC2::Card::RP;
use NEC2::Card::SC;
use NEC2::Card::SM;
use NEC2::Card::SP;

BEGIN {
	our @ISA = qw(Exporter);
	our @EXPORT = (
		# Geo card functions
		qw/GA GE GF GH GM GR GS GW GC GX SP SM/,

		# Program card functions
		qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ/
	);
}


#####################################################################
# Static Functions

sub save
{
	my ($fn, @structure) = @_;

	open(my $structure, "|column -t > $fn") or die "$!: $fn";

	print $structure @structure;

	close($structure);
}



###########################################################
# Card shortcuts:

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

1;
