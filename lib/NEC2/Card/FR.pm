#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Library General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# 
#  Copyright (C) 2021- by Eric Wheeler, KJ7LNW.  All rights reserved.
#
#  The official website and doumentation for xnec2c-optimizer is available here:
#    https://www.xnec2c.org/
#
package NEC2::Card::FR;

use strict;
use warnings;

use parent 'NEC2::Card';

# default to 10 steps in the 2m amature radio band:
sub defaults
{
	# note that NEC2 does not define mhz_max, it is calculated in the 
	# overloaded set_special() function below.
	return (type => 0, n_freq => 10);
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

sub get_special
{
	my ($self, $var) = @_;

	if ($var eq 'mhz_max')
	{
		return $self->get('mhz_min') + ($self->get('n_freq')-1)*$self->get('mhz_inc');
	}

	return undef;
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

	if (defined($self->{mhz_max}) && defined($n_freq) && $n_freq > 1)
	{
		die "FR: mhz_min !< mhz_max: $mhz_min !< $mhz_max" if ($mhz_min >= $mhz_max);

		# set mhz_inc accordingly:
		$self->set_card_var('mhz_inc', ($mhz_max - $mhz_min) / ($n_freq-1));
	}

	my $mhz_inc = $self->get('mhz_inc');

	if ($n_freq > 1 && (!defined($mhz_inc) || $mhz_inc <= 0))
	{
		$mhz_inc //= '(undef)';
		die "FR: n_freq > 1, but mhz_inc is invalid: $mhz_inc";
	}
}

1;

