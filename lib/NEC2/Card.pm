package NEC2::Card;

use strict;
use warnings;

use overload '""' => \&stringify;

use constant geo_card_names => (qw/GA GE GF GH GM GR GS GW GC GX SP SM/);
use constant program_card_names => (qw/CP EK EN EX FR GD GN KH LD NE NH NT NX PQ PT RP TL WG XQ ZO/);

sub stringify
{
	my ($self) = @_;

	my $card = $self->card_name();
	return "$card " . join("\t", $self->card_vals) . "\n";
}

sub new
{
	my ($class, @args) = @_;

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
	
	# Exclude defaults that are defined in @args so they only get
	# set once.  This is important for things like FR's mhz_min and
	# mhz_max that will break if they are done out of order, especially
	# if the defaults do not maintain a min<max relationship with the
	# ones provided by the user
	my %defaults = $class->defaults;
	for (my $i = 0; $i < @args; $i += 2)
	{
		delete $defaults{$args[$i]};
	}

	# Set passed values.
	# Note that the order is important here, so we pass a list not a hash:
	$self->set(%defaults, @args);

	return $self;
}


#####################################################################
# Functions intended for overload by child classes:

# Map friendly names to NEC2 registers like I1, F2, ...  
# Must be overriden by child class.
sub param_map
{
	my $self = shift;

	die "Incomplete class, param_map must be defined: ".ref($self);

	# Should return { var => 'f1', ... mappings };
}

# Default values for classes to instantiate without arguments
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


# The child class may create internal "special variables" by
# implementing set_special and get_special.  
# get_special must return a defined value if the variable is defined. See FR's mhz_max feature.
sub get_special
{
	return undef;
}

# set_special must return a true value if that variable is supported.
# Note that this true/false return behavior for set is different than
# the defined/undefined return behavior for get.
sub set_special
{
	return 0;
}

#####################################################################
# Core functions
# get card (or class) value:
#
sub get
{
	my ($self, $var) = @_;

	my $val = $self->get_special($var);

	if (!defined $val) 
	{
		my $idx = $self->_get_var_idx($var);
		if (defined($idx))
		{
			$val = $self->{card}->[$idx];
		}
	}

	if (!defined($val))
	{
		die "Unknown var for class " . ref($self) . ": $var";
	}

	return $val;
}

# directly sets a card variable, will not call set_special().
sub set_card_var
{
	my ($self, $var, $val) = @_;

	my $idx = $self->_get_var_idx($var);
	if (!defined $idx) 
	{
		die "Unknown var for class " . ref($self) . ": $var";
	}
	else
	{
		$self->{card}->[$idx] = $val;
	}

	return $self;
}

# Sets a single var, val tuple.
sub set_one
{
	my ($self, $var, $val) = @_;

	our $depth++;
	die "set_one: depth is too deep (maybe set_card_var instead of set?): $var => $val" if ($depth > 10);

	# first try set_special in case the value is overriden:
	if (!$self->set_special($var, $val))
	{
		$self->set_card_var($var, $val);
	}

	$depth--;

	return $self;
}

# Sets a hash of values:
# example: $self->set(tag => 3, f4 => 7, ...)
sub set
{
	my ($self, @var_vals) = @_;

	# maintain the order of the list because some vars
	# like FR's mhz_min and mhz_max are order-dependent.
	while (my ($var, $val) = splice(@var_vals, 0, 2)) 
	{
		#print $self->card_name . ": $var => $val\n";
		$self->set_one($var, $val);
	}

	# return object for easy chaining
	return $self;
}


#####################################################################
# Classful functions, not intended for overloading.

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

	my $idx = $var;
	my $param_map = $self->_get_param_map();

	# If the param_map returns a non-integer then remap it
	my $depth = 0; 
	while (defined($idx) && $idx !~ /^[0-9]+$/)
	{
		$idx = $param_map->{$idx};
		#print "$var: $idx\n";
		die "Variable cycle detected for class " . ref($self) . ": $var" if $depth++ > 10;
	}

	return $idx;
}

# build the paramater map based on the card type.
sub _get_param_map
{
	my ($self) = @_;

	my $map = $self->param_map;

	my %type_map;
	%type_map = _program_card_param_maps() if ($self->is_program_card);
	%type_map = _geo_card_param_maps() if ($self->is_geo_card);

	return { %$map, %type_map };
}

sub _program_card_param_maps
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

sub _geo_card_param_maps
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
