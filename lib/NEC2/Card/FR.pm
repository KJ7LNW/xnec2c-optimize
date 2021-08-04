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
		my $n_freq = $self->get('n_freq');
		my $mhz_min = $self->get('mhz_min');
		my $mhz_max = $val;

		die "FR: mhz_min must be defined before mhz_max, tis needed for calculation" if (!defined($mhz_min));

		if ($n_freq <= 1)
		{
			$self->set_card_var('mhz_inc', 0);
		}
		else
		{
			die "FR: mhz_min !< mhz_max: $mhz_min !< $mhz_max" if ($mhz_min >= $mhz_max);

			# save for later if mhz_min if changed
			$self->{mhz_max} = $mhz_max;

			# set mhz_inc accordingly:
			$self->set_card_var('mhz_inc', ($mhz_max - $mhz_min) / ($n_freq-1))
		}
	}
	elsif ($var eq 'mhz_min')
	{
		# First, this _is_ an NEC2 variable so set it:
		$self->set_card_var('mhz_min', $val);

		my $n_freq = $self->get('n_freq');
		if ($n_freq <= 1)
		{
			$self->set_card_var('mhz_inc', 0);
		}
		elsif ($self->{mhz_max})
		{
			my $mhz_min = $val;
			my $mhz_max = $self->{mhz_max};

			die "mhz_min !< mhz_max: $mhz_min !< $mhz_max" if ($mhz_min >= $mhz_max);

			$self->set_card_var('mhz_inc', ($mhz_max - $mhz_min) / ($n_freq-1))
		}
	}
	else
	{
		return 0;
	}

	return 1;
}

1;

