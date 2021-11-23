package NEC2;

use strict;
use warnings;

use Exporter;

use Carp;

#$SIG{__DIE__} = sub { Carp::confess(); print Carp::longmess; };

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

BEGIN {
	our @ISA = qw(Exporter);
	our @EXPORT = (
		# Geo card functions
		qw/GA GE GF GH GM GR GS GW GC GX SP SM/,

		# Program card functions
		qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ ZO Z0/
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
		push @{ $self->{geo_cards} }, $card->geo_cards();
		push @{ $self->{program_cards} }, $card->program_cards();
	}

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

sub stringify
{
	my ($self) = @_;

	my $ret = '';

	$ret .= CM(comment => $self->{comment});
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
	my ($self, $fn, @structure) = @_;

	$fn or die "invalid filename: $fn";

	open(my $structure, "|column -t > $fn") or die "$!: $fn";

	print $structure $self;
	close($structure);
}


#####################################################################
# Static Functions

###########################################################
# Card shortcuts:

# Comment cards
sub CM { return NEC2::Card::CM->new(@_) }  # Arc
sub CE { return NEC2::Card::CE->new(@_) }  # Arc

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

1;
