#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use NEC2;

use PDL;
use PDL::IO::CSV qw(rcsv1D);
use PDL::Opt::Simplex;

use Linux::Inotify2;
use Data::Dumper;

###################
# For RP tag:
my $freq_min = 134;
my $freq_max = 158;
my $n_freq = 100;
my $freq_step = ($freq_max-$freq_min)/($n_freq-1);

###################
# NEC Geometry 

# yagi dimensions from https://www.qsl.net/dk7zb/PVC-Yagis/5-Ele-2m.htm
my $vars = {
	# Element lengths
	lengths => {
			values  => [ 1.038, 0.955, 0.959, 0.949, 0.935 ],
			enabled => [ 1,     1,     1,     1,     1 ]
		},

	# Spaces between elements:
	spaces => {
			values  => [ 0.000, 0.280, 0.15, 0.520, 0.53 ],
			enabled => [ 1,     1,     1,    1,     1 ]
		}
};

my $vec_initial = build_simplex_vars($vars);

###################
# Simplex Options

# "Step size" but not really, a bigger value makes larger jumps
# but the value doesn't translate to a unit.
# (it actually stands for simplex size, it initializes the size of the simplex tetrahedron)
my $ssize = 0.075;

# Conversion tolerance, exit optmizer when simplex isn't moving much:
my $tolerance = 1e-6;

# Max number of Simplex optimizations:
my $max_iter = 1000;


###################
# Goal Options

# field: the name of the field in the .csv.  
#   Available fields: Freq-MHz, Z-real, Z-imag, Z-magn, Z-phase, VSWR, Gain-max, Gain-viewer, F/B Ratio
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
#         inverted for simplex.  The simplest way to do this is to make it negative:
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
#       sum: add them together
#       avg: add them together and divide by the count
#       min: return the minimum from the set
#       max: return the maximum from the set
#       mag: take the vector magnitude: sum the square of each result and take the sqrt
#
# weight: Multiplicative weight, relative scale of the goal.  
#         This weight is multiplied times the result of the aggregation type
my $goals = [
	{ 
		field => 'Gain-max',
		enabled => 1,
		mhz_min => 144,
		mhz_max => 148,

		weight => 5,
		
		type => 'avg', 

		# Simplex minimizes, so return a negative value and raise it to a power.
		# A higher power makes the max-gain higher
		# A lower power makes a flater curve
		#
		#result => sub { my ($gain,$mhz)=@_; return -$gain**0.5; }
		
		# The (4-(146-$mhz)**2)**2 term attempts to maximize the gain at 146MHz by reducing
		# the multiple as it moves away from center for a narrow-band antenna.
		#result => sub { my ($gain,$mhz)=@_; return -$gain**0.5 * (4-(146-$mhz)**2)**2; }
		
		# This result function exponentiates to the power of the target gain over current gain.
		# It will tend toward a value of 1 as the target is exceeded.
		result => sub { my ($gain,$mhz)=@_; return 2**(12/$gain); }

		#result => sub { my ($gain,$mhz)=@_; return $gain < 1 ? 100 : (12/$gain); }

	},

	{ 
		field => 'VSWR',
		enabled => 1,
		mhz_min => 144,
		mhz_max => 150,

		# Multiplicative weight, relative scale of the goal
		weight => 1,

		type => 'avg', # calculate minima by sum, avg, min, or max

		# The optmizer minimizes results, penalize swr quadratically:
		# A larger power provides a flatter SWR
		# A lower power reduces the strength of the SWR penalty.
		result => sub { my ($swr,$mhz)=@_; return 2**($swr/1.5); }
         
		# The ((146-$mhz)**2)**2 term attempts to maximize the gain at 146MHz by increasing
		# the multiple as it moves away from center for a narrow-band antenna.
		#result => sub { my ($swr,$mhz)=@_; return $swr**2.0 * ((146-$mhz)**2)**2; }
	},

	{ 
		field => 'F/B Ratio',
		enabled => 1,
		mhz_min => 144,
		mhz_max => 148,

		weight => 1,

		type => 'avg', # calculate minima by sum, avg, min, max, or mag

		result => sub { my ($fb,$mhz)=@_; return 2**(20/$fb); }
		#result => sub { my ($fb,$mhz)=@_; return (20/$fb); }
	},
];


print "===== Initial Condition ==== \n";

my @yagi = yagi(get_simplex_vars($vars, $vec_initial));
NEC2::save("yagi.nec", @yagi);
print @yagi;

if ( -e "yagi.nec.csv" ) {
	print "\n=== Goal Status ===\n";
	my $csv = load_csv("yagi.nec.csv");
	foreach my $g (@$goals) {
		# Default to enabled if undefined.
		$g->{enabled} //= 1;
		next if (!$g->{enabled});
		goal_eval($csv, $g);
	}
}

print "\nTurn on the optimizer and press enter to begin.\n";
<STDIN>;


print "\n===== Starting Optimization ==== \n";

my ( $vec_optimal, $opt_ssize, $optval ) = simplex($vec_initial, $ssize, $tolerance, $max_iter, \&f, \&log);


print "\n===== Done! ==== \n";

# One more with the optimal value:
f($vec_optimal);

my $x = $vec_optimal->slice('(0)');
print "opt_ssize=$opt_ssize  opt=$x -> minima=$optval\n";

print "\n===== yagi.nec ==== \n";
system("cat yagi.nec");

exit 0;

# functions below here

# Globals for the functions:
my $log_count = 0;

sub goal_eval
{
	my ($csv, $goal) = @_;

	# Find the index for the given frequency range:
	my $mhz;
	my $idx_min;
	my $idx_max;
	my $i = 0;
	for ($i = 0; $i < nelem($csv->{'Freq-MHz'}); $i++)
	{
		$mhz = $csv->{'Freq-MHz'}->slice("($i)");
		$idx_min = $i if ($mhz >= $goal->{mhz_min} && !$idx_min);
		$idx_max = $i if ($mhz <= $goal->{mhz_max});
	}

	# $p contains the goal parameters in the frequency min/max that we are testing:
	my $p = $csv->{$goal->{field}};
	if (!defined($p))
	{
		die "Undefined field in CSV: $goal->{field}\n";
	}

	$p = $p->slice("$idx_min:$idx_max");
	$mhz = $csv->{'Freq-MHz'}->slice("$idx_min:$idx_max");


	# Sum the goal function and return the result:
	my $weight = $goal->{weight} || 1;
	my $type = $goal->{type} // 'sum';
	my $n = nelem($p);
	my $sum = 0;
	my $mag = 0;
	my $avg = 0;
	my $min;
	my $max;
	for ($i = 0; $i < $n; $i++)
	{
		my $v = $goal->{result}->($p->slice("($i)"), $mhz->slice("($i)")); 

		if ($v eq pdl(['inf']))
		{
			warn "result($goal->{field}) at index $i is infinite, using 1e6";
			$v = 1e6;
		}
		if ($v eq pdl(['nan']) || $v eq pdl(['-nan']))
		{
			warn "result($goal->{field}) at index $i is NaN, skipping";
			next;
		}

		$min = $v if (!defined($min) || $v < $min);
		$max = $v if (!defined($max) || $v > $max);
		$sum += $v;

		$mag += $v**2;
	}
	
	$avg = $sum / $n;
	$mag = sqrt($mag);

	my $ret = $sum;

	if ($type eq 'sum')    { $ret = $sum; }
	elsif ($type eq 'avg') { $ret = $avg; }
	elsif ($type eq 'min') { $ret = $min; }
	elsif ($type eq 'max') { $ret = $max; }
	elsif ($type eq 'mag') { $ret = $mag; }

	$ret *= $weight;

	print "Calculated goal $goal->{field} is $ret [$min,$max]. Values $goal->{mhz_min} to $goal->{mhz_max} MHz:\n\t$p\n";
	return $ret;
}

sub yagi
{
	my (%vars) = @_;

	my $lengths = $vars{lengths};
	my $spaces = $vars{spaces};

	print "yagi: lengths=[" . join(', ', @$lengths) . "]\n";
	print "yagi: spaces=[" . join(', ', @$spaces) . "]\n";

	my $n_segments = 11; # must be odd!
	my $ex_seg = int($n_segments / 2) + 1;

	#print "lengths: $lengths\n";
	#print "spaces: $spaces\n";
	my @ret = (
		NEC2::CM->new(comment => 'A yagi antenna'),
		NEC2::CE->new() 
		);


	my $zoff = 0;
	for (my $i = 0 ; $i < nelem($lengths) ; $i++) {

		# convert PDL's to normal floats:
		my $l = $lengths->[$i];
		my $s = $spaces->[$i];
		
		# spaces are distances between so accumulate the Z offset
		$zoff += $s;
		
		# left and right of zero
		$l /= 2; 
		push(
			@ret,
			NEC2::GW->new(
				tag => $i+1,
				ns  => $n_segments,
				x   => $l, x2  => -$l,
				z   => $zoff, z2  => $zoff, 
				rad => 0.002

			)
		);

	}

	# End of geometry and program parameters:
	push @ret, 
		# Free Space:
		NEC2::GE->new(ground => 0),
		NEC2::RP360->new(),

		# With ground:
		#NEC2::GE->new(ground => 1),
		#NEC2::RP180->new(),
		#NEC2::GN->new(type => 1),

		NEC2::EX->new(ex_tag => 2, ex_segment => $ex_seg),

		NEC2::NH->new(),
		NEC2::NE->new(),
		NEC2::FR->new(mhz => $freq_min, mhz_inc => $freq_step, n_freq => $n_freq),
		NEC2::EN->new()
		;

	return @ret;
}


sub f
{
	my ($vec) = @_;

	my $inotify = Linux::Inotify2->new;
	$inotify->watch("yagi.nec.csv", IN_CLOSE_WRITE)
		or die "inotify: $!: yagi.nec.csv";

	# save and wait for the CSV to be written:
	

	NEC2::save("yagi.nec", yagi(get_simplex_vars($vars, $vec)));
	$inotify->read;

	my $csv = load_csv("yagi.nec.csv");

	# Whatever vector format $vec->slice("(0)") is, $ret must be also.
	# So slice it, multiply times zero, and then add whatever you need:
	my $ret = $vec->slice("(0)");
	$ret *= 0;


	foreach my $g (@$goals) {
		next if (!$g->{enabled});

		$ret += goal_eval($csv, $g);
	}

	return $ret;
}

sub log
{
	my ($vec, $vals, $ssize) = @_;
	# $vec is the array of values being optimized
	# $vals is f($vec)
	# $ssize is the simplex size, or roughly, how close to being converged.

	my $minima = $vec->slice("(0)", 0);
	
	my $lengths = get_simplex_var($vars, $vec, 'lengths');
	my $spaces = get_simplex_var($vars, $vec, 'spaces');

	#print "f: vec=$vec\n";
	print "f: lengths=[" . join(', ', @$lengths) . "]\n";
	print "f: spaces=[" . join(', ', @$spaces) . "]\n";

	# each vector element passed to log() has a min and max value.
	# ie: x=[6 0] -> vals=[76 4]
	# so, from above: f(6) == 76 and f(0) == 4


	$log_count++;
	print "\n\nLOG $log_count: $ssize > $tolerance, minima = $minima.\n";
}

sub load_csv
{
	my $fn = shift;
	my @pdls = rcsv1D($fn, { header => 1 });

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

	return \%h;
}

sub build_simplex_vars 
{
	my ($vars) = @_;

	# first element is for simplex's return-value use, set it to 0.	
	my @pdl_vars = (0);
	foreach my $var_name (sort keys(%$vars))
	{
		my $var = $vars->{$var_name};

		my $n = scalar(@{ $var->{values} });

		# If enabled is missing or a non-scalar (ie =1 or =0) then form it properly
		# as either all 1's or all 0's:
		if (!defined($var->{enabled}) || (!ref($var->{enabled}) && $var->{enabled}))
		{
			$var->{enabled} = [ map { 1 } @{ $var->{values} } ] 
		}
		elsif (defined($var->{enabled}) && !ref($var->{enabled}) && !$var->{enabled})
		{
			$var->{enabled} = [ map { 0 } @{ $var->{values} } ] 
		}

		if (defined($var->{enabled}) && $n != scalar(@{ $var->{enabled} }))
		{
			die "variable $var must have the same length array for 'values' as for 'enabled'"
		}


		for (my $i = 0; $i < $n; $i++)
		{
			# var is enabled for simplex if enabled[$i] == 1
			if ($var->{enabled}->[$i])
			{
				push(@pdl_vars, $var->{values}->[$i]);
			}
		}
	}

	return pdl \@pdl_vars;
}

sub get_simplex_var
{
	my ($vars, $pdl, $var_name) = @_;

	my @ret;
	
	my $var = $vars->{$var_name};

	my $n = scalar(@{ $var->{values} });
	my $pdl_idx = 1; # skip first element

	# skip ahead to where the pdl_idx that we need is located:
	foreach my $vn (sort keys(%$vars))
	{
		my $var = $vars->{$vn};

		# done if we find it:
		last if $vn eq $var_name;

		$pdl_idx++ foreach (grep { $_ } @{ $var->{enabled} });
	}
	
	for (my $i = 0; $i < $n; $i++)
	{
		# use the pdl index if it is enabled for optimization
		# otherwise use the original index in $var.
		if ($var->{enabled}->[$i])
		{
			push(@ret, unpdl($pdl->slice("($pdl_idx)", 0))->[0]);
			$pdl_idx++;
		}
		else
		{
			push(@ret, $var->{values}->[$i]);
		}
	}

	return \@ret;
}

sub get_simplex_vars
{
	my ($vars, $pdl) = @_;	
	
	my %h;

	foreach my $var (keys %$vars)
	{
		$h{$var} = get_simplex_var($vars, $pdl, $var);
	}

	return %h;
}
