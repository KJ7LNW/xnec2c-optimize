package NEC2::Card::GH;

use strict;
use warnings;

use parent 'NEC2::Card';

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002); 
}

sub param_map
{
	my ($self, $key) = @_;
	return {

		itg       =>  'i1',
		tag       =>  'i1',

		ns        =>  'i2',

		s         =>  'f1',
		spacing   =>  'f1',

		hl        =>  'f2',
		length    =>  'f2',

		a1        =>  'f3',
		rx1       =>  'f3',

		b1        =>  'f4',
		ry1       =>  'f4',

		a2        =>  'f5',
		rx2       =>  'f5',

		b2        =>  'f6',
		ry2       =>  'f6',

		rad       =>  'f7',
		wire_rad  =>  'f7',
	};
}

sub set_special
{
	my ($self, $var, $val) = @_;

	return 0 unless ($var eq 'length' || $var eq 'ns' || $var eq 'spiral_turns');

	if ($var eq 'length' || $var eq 'ns')
	{
		$self->set_card_var($var, $val);
	}
	elsif ($var eq 'spiral_turns')
	{
		# 'spiral_turns' is internal, so set it in the class
		$self->{spiral_turns} = $val;
	}

	# This will update when ns or spiral_turns is updated:
	if ($self->get('length') == 0 &&
		$self->get('ns') > 0 &&
		$self->{spiral_turns} > 0)
	{
		# The number of spiral spiral_turns is calculated
		# as spacing=$segments/$spiral_turns, but only when
		# length==0.  Not sure if this is an xnec2c extension or
		# if other NEC2 interpreters support it, too:
		$self->set_card_var('spacing', $self->get('ns')/$self->{spiral_turns});
	}

	return 1;
}

1;
