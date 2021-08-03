package NEC2::GH;

use strict;
use warnings;

use parent 'NEC2';

sub defaults 
{
	# Defaults to 2mm wire, ~12 AWG
	return (rad => 0.002); 
}

sub param_map
{
	my ($self, $key) = @_;
	return {
		NEC2::geo_card_param_maps(),

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
	}->{$key};
}

sub set
{
	my ($self, $var, $val) = @_;

	# Handle spiral_turns when helix length is zero:
	if ($self->get('length') == 0)
	{
		if ($var eq 'spiral_turns')
		{
			# 'spiral_turns' is internal, so set it in the class
			$self->{spiral_turns} = $val;
		}
		else
		{
			# otherwise set it in the parent
			$self->SUPER::set($var, $val);
		}

		# This will update when ns or spiral_turns is updated:
		if (($var eq 'ns' || $var eq 'spiral_turns') && 
			$self->get('ns') && $self->{spiral_turns})
		{
			# The number of spiral spiral_turns is calculated as spacing=$segments/$spiral_turns.
			# Not sure if this is an xnec2c extension or if other NEC2 interpreters
			# support it:
			$self->SUPER::set('spacing', $self->get('ns')/$self->{spiral_turns});
		}
	}


	

	return $self;
}

1;
