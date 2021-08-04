package NEC2::Card::RP;

use strict;
use warnings;

use parent 'NEC2::Card';

# Note: see below for NEC2::Card::RP::Freespace and NEC2::Card::RP::Ground

sub defaults
{
	return (ground => 0);
}

sub set_special
{
	my ($self, $var, $val) = @_;

	# If ground is nonzero then use the defaults for having a ground.
	# Setting 'ground' will reset all other defaults so set it first
	# before changing other values.
	if ($var eq 'ground')
	{
		if ($val)
		{
			$self->set(NEC2::Card::RP::Ground::defaults());
		}
		else 
		{
			$self->set(NEC2::Card::RP::Freespace::defaults());
		}

		return 1;
	}

	return 0;
}

# short-hand terms:
sub param_map
{
	return {

		type          => 'i1',

		nth           => 'i2',
		n_theta       => 'i2',

		nph           => 'i3',
		n_phi         => 'i3',

		xnda          => 'i4',
		
		thets         => 'f1',
		theta_initial => 'f1',
		
		phis          => 'f2',
		phi_initial   => 'f2',
		
		dth           => 'f3',
		theta_inc     => 'f3',

		dph           => 'f4',
		phi_inc       => 'f4',

		rfld          => 'f5',
		gnor          => 'f6',
	};
}

1;


# No ground, 360-degrees of phi (same as above)
package NEC2::Card::RP::Freespace;
use parent 'NEC2::Card::RP';

sub defaults
{
	return (
		type => 0,
		n_theta => 19,
		n_phi => 37,
		xnda => '1000',
		theta_initial => 0,
		phi_initial => 0,
		theta_inc => 10,
		phi_inc => 10);
}

1;


# With ground, only 180-degrees of theta
package NEC2::Card::RP::Ground;
use parent 'NEC2::Card::RP';

sub defaults
{
	return (
		type => 0,
		n_theta => 19,
		n_phi => 37,
		xnda => '1000',
		theta_initial => 0,
		phi_initial => 0,
		theta_inc => 5,
		phi_inc => 10);
}

1;

