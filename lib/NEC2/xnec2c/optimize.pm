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
package NEC2::xnec2c::optimize;

use strict;
use warnings;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;
use PDL::Opt::Simplex::Simple;
use PDL::Opt::ParticleSwarm::Simple;

use Linux::Inotify2;

use Data::Dumper;

sub new
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	if (!defined($self->{filename_nec}))
	{
		die "Output file <filename_nec> must be defined";
	}

	if (!defined($self->{nec2}) || ref($self->{nec2}) ne 'CODE')
	{
		die "NEC2 geometry callback function <nec2> is undefined or invalid";
	}
	
	if (!defined($self->{filename_nec_csv}))
	{
		$self->{filename_nec_csv} = $self->{filename_nec} . ".csv";
	}
	else
	{
		warn "specifying filename_nec_csv is unsupported: xnec2c will always append .csv to the .nec file";

	}

	if (defined($self->{simplex}))
	{
		warn "deprecated: the section 'simplex' has been changed to 'optimizer' and requires a 'class' attribute.  Setting class='PDL::Opt::Simplex::Simple'";
		$self->{optimizer} = delete $self->{simplex};
		$self->{optimizer}{class} = 'PDL::Opt::Simplex::Simple';
	}

	$self->{_opt_class} //= delete $self->{optimizer}{class};

	if (!defined($self->{_opt_class}))
	{
		die "You must define an optimizer class in your config as optimizer=>{class=>'CLASSNAME'}}";
	}

	my $oclass = $self->{_opt_class};


	$self->{opt} = $oclass->new(
		vars => $self->{vars},
		f    =>  sub  {  $self->_xnec2c_optimize_callback(@_)  },
		log  =>  sub  {  $self->_log(@_)                       },
		%{ $self->{optimizer} });
	
	#print Dumper $self;

	# opt, vars, nec2, goals, filename_nec_csv, filename_nec
	return $self;
}

sub optimize
{
	my $self = shift;

	my $result = $self->{opt}->optimize();

	# Call one more time to make sure the best result is rendered by xnec2c
	# in case the optimizer's last iteration was worse than the best.
	$self->_xnec2c_optimize_callback($self->{opt}->get_result_simple());

	return $self->{opt}->get_result_expanded();
}

sub print_vars
{
	my ($self, $vars) = @_;

	print "===== Variables ==== \n";
	print Dumper $vars;
}

sub print_vars_initial
{
	my $self = shift;
	print "===== Initial Condition ==== \n";

	print Dumper($self->{opt}->get_vars_simple) . "\n";
}

sub print_vars_result
{
	my $self = shift;
	print "===== Result ==== \n";

	print "srand: $self->{opt}->{'srand'}\n";

	print Dumper($self->{opt}->get_result_simple) . "\n";
}

sub print_nec2_initial
{
	my $self = shift;
	print $self->{nec2}->($self->{opt}->get_vars_simple);
}

sub print_nec2_result
{
	my $self = shift;
	print $self->{nec2}->($self->{opt}->get_result_simple);
}

sub print_goal_status
{
	my $self = shift;
	print "===== Goal Status ==== \n";
	print Dumper($self->{goal_status});
}

sub save_nec_initial
{
	my $self = shift;

	$self->_xnec2c_optimize_callback($self->{opt}->get_vars_simple);
}

sub save_nec_result
{
	my $self = shift;

	$self->_xnec2c_optimize_callback($self->{opt}->get_result_simple);
}

sub _xnec2c_optimize_callback
{
	my ($self, $vars) = @_;

	my $filename = $self->{filename_nec_csv};

	my $inotify = Linux::Inotify2->new;
	if (! -e "$filename" )
	{
		open(my $csv, ">", "$filename");
		close($csv);
	}
	$inotify->watch("$filename", IN_CLOSE_WRITE)
		or die "inotify: $!: $filename";

	$self->{_last_nec} = $self->{nec2}->($vars);

	# save and wait for the CSV to be written by xnec2c:
	$self->{_last_nec}->save($self->{filename_nec});
	$inotify->read;

	my $csv = _load_csv("$filename");

	return $self->_goal_eval_all($self->{goals}, $vars, $csv);
}

sub _log
{
	my ($self, $vars, $status) = @_;

	my $minima = $status->{minima};
	my $ssize = $status->{ssize};

	$status->{elapsed} //= -1;
	
	if (!$status->{cancel})
	{
		$self->print_vars($vars);
		$self->print_goal_status;

		print "\n\n";
	}

	printf "%s %.2fs pass #%d/%d (best=%d): %d/%d  %.3g > %.3g, minima=%.3g (retries: %d/%d hit/miss: %d/%d)\n",
		$status->{cancel} ? 'CANCEL' : 'LOG',
		$status->{elapsed},
		$status->{optimization_pass}, $status->{num_passes}, $status->{best_pass},
		$status->{log_count}, $self->{opt}->{max_iter},
		$ssize, $self->{opt}->{tolerance} // 0,
		$minima,
		$status->{prev_minima_count}, $self->{opt}->{stagnant_minima_count},
		$status->{cache_hits}//0, $status->{cache_misses}//0, 
		;
}

sub _load_csv
{
	my $fn = shift;

	(-e $fn) or die "CSV file is missing: $fn";

	my @pdls = rcsv1D($fn, { header => 1 });

	# Expected headers as of xnec2c v4.4.11:
	my %headers = map { $_ => 1 } qw/
		mhz zreal zimag zmag zphase vswr s11 s11_real s11_imag s11_ang
		gain_max gain_net gain_max_theta gain_max_phi gain_viewer
		gain_viewer_net fb_ratio/;


	my %h;
	foreach my $p (@pdls)
	{
		my $header = $p->hdr->{col_name};
		if ($header)
		{
			$header =~ s/^\s*|\s*$//g;
			$h{$header} = $p 
		}
	}

	foreach my $key (keys %headers)
	{
		warn "CSV: missing header: $key" if !defined($h{$key});
	}


	return \%h;
}

sub _goal_eval_mhz
{
	my ($self, $mhz_range, $vars, $csv, $goal) = @_;

	my ($mhz_min, $mhz_max) = @$mhz_range;

	my $weight = $goal->{weight} || 1;
	my $type = $goal->{type} // 'sum';

	# Find the index for the given frequency range:
	my $mhz;
	my $idx_min;
	my $idx_max;
	my $i = 0;
	for ($i = 0; $i < nelem($csv->{mhz}); $i++)
	{
		$mhz = $csv->{mhz}->slice("($i)");
		$idx_min = $i if ($mhz >= $mhz_min && !$idx_min);
		$idx_max = $i if ($mhz <= $mhz_max);
	}

	if (!defined($idx_min))
	{
		die "can't find index for frequency in CSV at $mhz_min MHz";
	}

	if (!defined($idx_max))
	{
		die "can't find index for frequency in CSV at $mhz_max MHz";
	}


	# $p contains the goal parameters in the frequency min/max that we are testing:
	my $p = $csv->{$goal->{field}};
	if (!defined($p))
	{
		die "Undefined field in CSV: $goal->{field}\n";
	}

	$p = $p->slice("$idx_min:$idx_max");
	$mhz = $csv->{mhz}->slice("$idx_min:$idx_max");


	# Sum the goal function and return the result:
	my $n = nelem($p);
	my $sum = pdl 0;
	my $mag = pdl 0;
	my $avg = pdl 0;
	my $min;
	my $max;
	for ($i = 0; $i < $n; $i++)
	{
		my $pval = $p->slice("($i)");
		my $mhzval = $mhz->slice("($i)");
		my $v = $goal->{result}->($pval, $mhzval); 

		if ($v == pdl(['inf']) || "$v" eq 'inf')
		{
			#warn "result($goal->{field}) at $mhzval MHz (index $i) is +inf, using 1e6";
			$v = pdl 1e6;
		}
		elsif ($v == pdl(['-inf']) || "$v" eq '-inf')
		{
			#warn "result($goal->{field}) at $mhzval MHz (index $i) is -inf, using -1e6";
			$v = pdl -1e6;
		}
		elsif ($v == pdl(['nan']) || $v == pdl(['-nan']) || "$v" eq 'nan' || "$v" eq '-nan')
		{
			warn "result($goal->{field}) at $mhzval MHz (index $i) is NaN, skipping";
			next;
		}

		$min = $v if (!defined($min) || $v < $min);
		$max = $v if (!defined($max) || $v > $max);
		$sum += $v;

		$mag += $v**2;
	}
	
	# Actual min/max of the parameter:
	my ($value_min, $value_max) = minmax($p);
	$self->{goal_status}->{$goal->{name}}{"$mhz_range->[0]-$mhz_range->[1]_min"} = $value_min;
	$self->{goal_status}->{$goal->{name}}{"$mhz_range->[0]-$mhz_range->[1]_max"} = $value_max;
	
	$avg = $sum / $n;
	$mag = sqrt($mag);

	my $ret = $sum;

	if ($type eq 'sum')    { $ret = $sum; }
	elsif ($type eq 'avg') { $ret = $avg; }
	elsif ($type eq 'min') { $ret = $min; }
	elsif ($type eq 'max') { $ret = $max; }
	elsif ($type eq 'mag') { $ret = $mag; }
	elsif ($type eq 'diff') { $ret = $max - $min; }
	elsif ($type eq '+diff') { $ret = $max - $min; }
	elsif ($type eq '-diff') { $ret = -($max - $min); }

	$ret *= $weight;

	my $name = $goal->{name} // '';

	return $ret;
}

sub _goal_eval_all
{
	my ($self, $goals, $vars, $csv) = @_;

	my $nec2 = $self->{_last_nec};

	my $ret = 0;
	foreach my $g (@$goals) {

		# Default to enabled if undefined.
		$g->{enabled} //= 1;
		next if (!$g->{enabled});


		# If no field is defined, just call the goal
		# function on the variables and pass the $csv.
		if (!defined($g->{field}))
		{
			my $v = $g->{result}->($vars, $csv); 
			$ret += $v * $g->{weight};
			next;
		}

		my @mhz_ranges;

		# Use all ranges from FR cards:
		if (!defined($g->{mhz_ranges}))
		{
			@mhz_ranges = map { [ $_->get('mhz_min') => $_->get('mhz_max') ] }
				$nec2->program_card_filter('FR');
		}

		# Convert to array of arrayrefs:
		elsif (defined($g->{mhz_ranges}) &&
			ref($g->{mhz_ranges}) eq 'ARRAY' &&
			ref($g->{mhz_ranges}->[0]) eq '')
		{
			@mhz_ranges = ($g->{mhz_ranges});
		}

		else {
			@mhz_ranges = @{ $g->{mhz_ranges} };
		}

		foreach my $mhz_range (@mhz_ranges)
		{
			# Shrink the min/max values in case the FR cards are bigger than the range of the g
			# Typically you would increase the FR cards by (for example) 5MHz so you can see more
			# curve but you only want to optimize in the frequency band you care about.
			if (defined($g->{mhz_shrink}) && (
				$mhz_range->[0]+$g->{mhz_shrink} > $mhz_range->[1] || 
				$mhz_range->[0]+$g->{mhz_shrink} < $mhz_range->[0]))
			{
				die "mhz_shrink'ing $mhz_range->[0] to $mhz_range->[1] MHz by $g->{mhz_shrink} MHz is out of range";
			}
			if (defined($g->{mhz_shrink}))
			{
				$mhz_range->[0] += $g->{mhz_shrink};
				$mhz_range->[1] -= $g->{mhz_shrink};
			}

			# Shift the frequency to the left (-) or right (+) in case the curve needs to move.

			if (defined($g->{mhz_shift}) && (
				$mhz_range->[0]+$g->{mhz_shift} > $mhz_range->[1] || 
				$mhz_range->[0]+$g->{mhz_shift} < $mhz_range->[0]))
			{
				die "mhz_shift from $mhz_range->[0] of $g->{mhz_shift} MHz is out of range";
			}

			if (defined($g->{mhz_shift}))
			{
				$mhz_range->[0] += $g->{mhz_shift};
				$mhz_range->[1] += $g->{mhz_shift};
			}

			my $result = $self->_goal_eval_mhz($mhz_range, $vars, $csv, $g);

			# Return a non-pdl scalar value for logging, this is the value used
			# by the optimizer to determine the goal:
			$self->{goal_status}->{$g->{name}}{"$mhz_range->[0]-$mhz_range->[1]_spx"} = $result->sclr;

			# Add the result to the final value:
			$ret += $result;
		}
	}

	return $ret;
}

1;

__END__


############################################################################
# Goal Options

# field: the name of the field in the .csv.  
#   Available fields: 
#   	Freq-MHz, Z-real, Z-imag, Z-magn, Z-phase, VSWR, Gain-max, Gain-viewer, F/B Ratio, Direct-tht, Direct-phi
#
#   If field is left undefined, then instead of passing field values to the result function
#   it will pass the current optimized vector and csv so the function can do its
#   own computation.  This could be used to minimize the length of the antenna.
#
# name: an optional field to display the name of the goal
#
# enabled: 1 or 0 to enable/disable.  Not if enable is undefined then it defaults to enabled.
#
# mhz_min: The minimum frequency for which the goal applies
# mhz_max: The maximum frequency for which the goal applies
#
# result: a subroutine (coderef) that is passed a measurement (and frequency) and returns the
#         value that should be minimized.  The result should always return a smaller
#         value when the it is closer to the goal because Simplex works to 
#         find a minima.  The value can be negative.  The frequency being evaluated by the 
#         result function could be used to scale the goal, for example, if the shape of the 
#         goal should vary with frequency.  The name of the variables in the function do not
#         matter, just know that the values being passed are that which is measured from 'field'
#         and the 2nd argument is always the frequency in MHz being evaluated.
#
#         Once all goals are evaulated independantly for each measurement they are summed
#         together.  Thus, it is important the the scale of one goal against another
#         is similar.  If one goal swings the total sum of all goals too much then 
#         the subtle (and possibly important) effects of a different goal will be lost 
#         in the noise of the "louder" goal.  Work could be done here to normalize all
#         goal results against eachother before summing them together.
#
#         For values like VSWR where lower values are better, you can
#         penalize larger values by raising them to a power.  For example:
#            result => sub { my ($swr,$mhz) = @_; return $swr**2; }
#         This forces a flatter SWR curve because higher values are quadratically
#         worse than lower values.
#
#         For values like gain where higher values are better, the value needs to be
#         inverted for the optimizer.  The simplest way to do this is to make it negative:
#            result => sub { my ($gain,$mhz) = @_; return -$gain; }
#
#         However you may also create a bias by raising it to a fractional power:
#            result => sub { my ($gain,$mhz) = @_; return -$gain*0.5; }
#         A higher power makes the max-gain higher because higher gains get a greater
#         negative score, thus being "better" in terms of how Simplex evaluates it.
#         A lower power makes a flater curve for the opposite reason.
#
#         You can also experiment with creating a synthetic goal and exponentiating
#         the goal as a fraction.  For example:
#            result => sub { my ($gain,$mhz) = @_; return 2**(12/$gain); }
#         This creates a "goal" of 12dB gain such that when the exponent reaches 12/12 it
#         will evaluate as "2".  If gain is less than 12dB it will score exponentially
#         worse.  This also has the effect of normalizing the result against the goal
#         which makes the goals more even (you could also adjust the weights).
#
#         For SWR, invert the fraction so that lower is better:
#            result => sub { my ($swr,$mhz)=@_; return 2**($swr/1.5); }
#
#
#
# type: aggregation type, what to do with of the return from result subroutine for each frequency.
#       avg: add them together and divide by the count
#       min: return the minimum from the set
#            Min will return the "best" value across all frequencies, 
#            so the optimizer will not work as hard to push it down.
#       max: return the maximum from the set
#            Max will return the "worst" value across all frequencies, 
#            so the optimizer will work harder to push it down.  Good for VSWR.
#       diff: subtract min from max ($max-$min).
#            This is useful if you want a minimal difference between the two, but the
#            value itself doesn't matter as much.   For example, if you need VSWR to
#            be consistent across the band but the VSWR value doesn't matter because you
#            plan to use an external impedance matching circuit.
#       -diff: sames as diff, but negative.  Useful when you want a large difference 
#            between min and max
#       +diff: alias for 'diff'
#       mag: take the vector magnitude: sum the square of each result and take the sqrt
#       sum: add them together
#            
#       Note that avg/[+-]diff/min/max scale similarly because they represent (approximately) one 
#       single value across all frequencies.  Whereas, "sum" will add all goal results together
#       and increase the result by the number of frequency points.  The "mag" type may work similarly, 
#       but to a lesser degree than sum.  This effect can be adjusted by decreasing the goal weight.
#
# weight: Multiplicative weight, relative scale of the goal.  
#         This weight is multiplied times the result of the aggregation type
