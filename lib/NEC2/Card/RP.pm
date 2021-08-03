package NEC2::Card::RP;

use strict;
use warnings;

use parent 'NEC2::Card';

# Note: see below for NEC2::Card::RP::Freespace and NEC2::Card::RP::Ground

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

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		type          => 'I1',

		nth           => 'I2',
		n_theta       => 'I2',

		nph           => 'I3',
		n_phi         => 'I3',

		xnda          => 'I4',
		
		thets         => 'F1',
		theta_initial => 'F1',
		
		phis          => 'F2',
		phi_initial   => 'F2',
		
		dth           => 'F3',
		theta_inc     => 'F3',

		dph           => 'F4',
		phi_inc       => 'F4',

		rfld          => 'F5',
		gnor          => 'F6',
	}->{$key};
}

1;


# No ground, 360-degrees of phi (same as above)
package NEC2::Card::RP::Freespace;
use parent 'NEC2::Card::RP';
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

