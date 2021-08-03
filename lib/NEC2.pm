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


our @_geo_card_names;
our @_program_card_names;

BEGIN {

	@_geo_card_names = (qw/GA GE GF GH GM GR GS GW GC GX SP SM/);
	@_program_card_names = (qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ/);

	our @ISA = qw(Exporter);
	our @EXPORT = (@_geo_card_names, @_program_card_names);
}

use overload '""' => \&stringify;

sub stringify
{
	my ($self) = @_;

	my $card = $self->card_name();
	return "$card " . join("\t", $self->card_vals) . "\n";
}

sub new
{
	my ($class, %args) = @_;

	my %h;

	my $self = bless({}, $class);

	# Default the card to all 0's.	So far as I can tell, program
	# cards have 10 options and  geometry cards have 9 options.
	
	print "self: $self\n";
	if ($self->is_geo_card()) 
	{
		$self->{card} = [ map { 0 } (1..9) ]
	}
	elsif ($self->is_program_card())
	{
		$self->{card} = [ map { 0 } (1..10) ]
	}
	
	# Set class defaults
	$self->set($class->defaults);

	# Set passed values, the user may override card => [ ... ] if they wish:
	$self->set(%args);

	return $self;
}


#####################################################################
# Functions intended for overload by child classes:

# Map friendly names to NEC2 registers like I1, F2, ...  
# Must be overriden by child class.
sub param_map
{
	my ($self, $param) = @_;
	die "param_map: cannot map $param, incomplete class: " . ref($self);
}

sub defaults
{
	return ()
}

# Return all geometry cards in the class. Overload this
# if a child class may require multiple geo cards to
# represent itself, such as GW and GC for tapered wires.
sub geo_cards
{
	my $self = shift;
	return ($self);
}

# Used for antenna models that may return program cards such as EX
# for the excited element to drive the antenna.
sub program_cards
{
	return ();
}

# The child class may override this for creating internal "variables"
# that can be used to configure the class.  See FR's mhz_max feature:
# example: $self->set(tag => 3, f4 => 7, ...)
sub set
{
	my ($self, %vars) = @_;

	foreach my $var (keys(%vars)) 
	{
		my $idx = $self->_get_var_idx($var);

		$self->{card}->[$idx] = $vars{$var};
	}

	# return object for easy chaining
	return $self;
}

# Override this if the card name doesn't take the format of
# NEC2::(CARDNAME) from the class
sub card_name
{
	my ($self) = @_;

	my $class = ref $self || $self;

	if ($class =~ /NEC2::([A-Z]{2})(:|$)/)
	{
		return $1;
	}
	else
	{
		die "Cannot figure out card name for class: $class";
	}
}


#####################################################################
# Core functions
# get card (or class) value:
sub get
{
	my ($self, $var) = @_;

	my $idx = $self->_get_var_idx($var);

	if (!defined $idx && !defined($self->{$var}))
	{
		# fail if undefined:
		die "Unknown var for class " . ref($self) . ": $var" if !defined($idx);
	}
	elsif (!defined $idx && defined($self->{$var}))
	{
		# return the class var if defined:
		return $self->{$var};
	}
	else
	{
		return $self->{card}->[$idx];
	}
}



sub save
{
	my ($fn, @structure) = @_;

	open(my $structure, "|column -t > $fn") or die "$!: $fn";

	print $structure @structure;

	close($structure);
}


#####################################################################
# Classful helper functions, not intended for overloading.

sub card_vals
{
	my $self = shift;
	return @{ $self->{card} || [] };
}


# Return nonzero if this is a tagged geometry.
sub tagged
{
	my $self = shift;
	return $self->is_geo_card;
}

sub is_geo_card
{
	my $self = shift;
	my $card_name = $self->card_name;
	return scalar(grep { $_ eq $card_name } geo_card_names());
}

sub is_program_card
{
	my $self = shift;
	my $card_name = $self->card_name;
	return scalar(grep { $_ eq $card_name } geo_card_names());
}


#####################################################################
# Classful internal functions, not intended for user use.


# Given a variable, return the index into the card array by 
# looking up the location in its param_map.
sub _get_var_idx
{
	my ($self, $var) = @_;

	# always lowercase
	$var = lc($var);

	# use the class names if they exist:
	my $idx = $self->param_map($var);

	# If the param_map returns a non-integer then remap it
	my $depth = 0; 
	while (defined($idx) && $idx !~ /^[0-9]+$/)
	{
		$idx = $self->param_map($idx);
		#print "$var: $idx\n";
		die "Variable cycle detected for class " . ref($self) . ": $var" if $depth++ > 10;
	}


	return $idx;
}

#####################################################################
# Static Functions


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


sub program_card_param_maps
{

	# nec card names, can be overridden in the child class:
	return (
		# integer register values for card:
		i1 => 0,
		i2 => 1,
		i3 => 2,
		i4 => 3,
		
		# floating-point register values for card:
		f1 => 4,
		f2 => 5,
		f3 => 6,
		f4 => 7,
		f5 => 8,
		f6 => 9);

}

sub geo_card_param_maps
{

	# nec card names, can be overridden in the child class:
	return (
		# integer register values for card:
		i1 => 0,
		i2 => 1,

		# floating-point register values for card:
		f1 => 2,
		f2 => 3,
		f3 => 4,
		f4 => 5,
		f5 => 6,
		f6 => 7,
		f7 => 8);

}

sub geo_card_names     { return @_geo_card_names }
sub program_card_names { return @_program_card_names }


1;
