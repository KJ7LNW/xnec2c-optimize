package NEC2::Card::FR;

use strict;
use warnings;

use parent 'NEC2::Card';

# default to 10 steps in the 2m amature radio band:
sub defaults
{
	# note that NEC2 does not define mhz_max, it is calculated in the 
	# overloaded set_special() function below.
	return (type => 0, n_freq => 10, mhz_min => 144, mhz_max => 148);
}

# human-readable terms, some have multiple aliases for the same thing:
sub param_map
{
	return {

		type          => 'i1',
		n_freq        => 'i2',
		mhz           => 'f1',
		mhz_min       => 'f1',

		mhz_inc       => 'f2',
		mhz_step      => 'f2',
		delfrq        => 'f2',
	};
}


sub set_special
{
	my ($self, $var, $val) = @_;

	if ($var eq 'mhz_max')
	{
		$self->{mhz_max} = $val;
	}
	elsif ($var eq 'mhz_inc')
	{
		# If they specify mhz_inc, then mhz_max is (probably) no longer valid
		delete $self->{mhz_max};

		# Still set the card var for mhz_inc:
		$self->set_card_var($var, $val);
	}
	elsif ($var eq 'mhz_min' || $var eq 'n_freq')
	{
		$self->set_card_var($var, $val);
	}
	else
	{
		return 0;
	}

	$self->_FR_update_mhz_min_max();

	return 1;
}

sub _FR_update_mhz_min_max
{
	my $self = shift;

	my $n_freq = $self->get('n_freq');
	my $mhz_min = $self->get('mhz_min');
	my $mhz_max = $self->{mhz_max};

	if ($n_freq <= 1)
	{
		$self->set_card_var('mhz_inc', 0);
	}
	elsif (defined($self->{mhz_max}))
	{
		die "FR: mhz_min !< mhz_max: $mhz_min !< $mhz_max" if ($mhz_min >= $mhz_max);

		# set mhz_inc accordingly:
		$self->set_card_var('mhz_inc', ($mhz_max - $mhz_min) / ($n_freq-1))
	}

	my $mhz_inc = $self->get('mhz_inc');

	if ($n_freq > 1 && (!defined($mhz_inc) || $mhz_inc <= 0))
	{
		$mhz_inc //= '(undef)';
		die "FR: n_freq > 1, but mhz_inc is invalid: $mhz_inc";
	}
}

1;

