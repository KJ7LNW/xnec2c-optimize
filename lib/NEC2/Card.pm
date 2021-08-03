package NEC2::Card;

use strict;
use warnings;

use overload '""' => \&stringify;

use constant geo_card_names => (qw/GA GE GF GH GM GR GS GW GC GX SP SM/);
use constant program_card_names => (qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ/);

sub stringify
{
	my ($self) = @_;

	my $card = $self->card_name();
	return "$card " . join("\t", $self->card_vals) . "\n";
}

sub new
{
	my ($class, %args) = @_;

	die "NEC2::Card->new called with a ref?" if ref ($class);

	my %h;

	my $self = bless({}, $class);

	# Default the card to all 0's.	So far as I can tell, program
	# cards have 10 options and  geometry cards have 9 options.

	if ($self->is_geo_card()) 
	{
		$self->{card} = [ map { 0 } (1..9) ]
	}
	elsif ($self->is_program_card())
	{
		$self->{card} = [ map { 0 } (1..10) ]
	}
	elsif (ref($self) !~ /NEC2::Card::C[ME]/) # ignore comment cards, not geo nor program.
	{
		die "Unknown card type: $class";
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

	return $self if ($self->is_geo_card());
	return ();

}

# Used for antenna models that may return program cards such as EX
# for the excited element to drive the antenna.
sub program_cards
{
	my $self = shift;

	return $self if ($self->is_program_card());
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

	if ($class =~ /NEC2::Card::([A-Z]{2})(:|$)/)
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
	return scalar(grep { $_ eq $card_name } program_card_names());
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

	die "Card index is undefined for class " . ref($self) . ": $var\n" if (!defined($idx));

	return $idx;
}

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

1;
