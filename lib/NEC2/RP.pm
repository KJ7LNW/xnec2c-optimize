package NEC2::RP;

use strict;
use warnings;

use parent 'NEC2';

sub defaults
{
	return (I1 => 0, I2 => 19, I3 => 37, I4 => '1000', F1 => 0, F2 => 0, F3 => 10, F4 => 10);
}

sub params
{
	return (qw/I1 I2 I3 I4 F1 F2 F3 F4 F5 F6/);
}

# short-hand terms:
sub param_map
{
	my ($self, $key) = @_;
	return {
		type          => 'I1',
		n_theta       => 'I2',
		n_phi         => 'I3',
		xnda          => 'I4',
		theta_initial => 'F1',
		phi_initial   => 'F2',
		theta_inc     => 'F3',
		phi_inc       => 'F4',
		rfld          => 'F5',
		gnor          => 'F6',
	}->{$key};
}

1;


# No ground, 360-degrees of phi (same as above)
package NEC2::RP360;
use parent 'NEC2::RP';
1;


# With ground, only 180-degrees of phi
package NEC2::RP180;
use parent 'NEC2::RP';

sub defaults
{
	return (I1 => 0, I2 => 19, I3 => 37, I4 => '1000', F1 => 0, F2 => 0, F3 => 5, F4 => 10);
}

1;

