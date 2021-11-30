			
package PDL::Opt::Simplex::Simple;

use strict;
use warnings;

use Math::Round qw/nearest/;
use Time::HiRes qw/time/;

use PDL;
use PDL::Opt::Simplex;

sub new
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	$self->{tolerance}              //=  1e-6;
	$self->{max_iter}               //=  1000;
	$self->{ssize}                  //=  0.1;
	$self->{stagnant_minima_count}  //=  30;
	
	if ($self->{srand})
	{
		$self->{srand} = srand($self->{srand});
	}
	else 
	{
		$self->{srand} = srand();
	}

	# _ssize is the array for multiple simplex retries.
	if (ref($self->{ssize}) eq 'ARRAY')
	{
		$self->{_ssize} = $self->{ssize};

		$self->{ssize} = $self->{ssize}[0];
	}
	else
	{
		$self->{_ssize} = [ $self->{ssize} ];
	}

	$self->set_vars($self->{vars});

	# vars, ssize, tolerance, max_iter, f, log
	return $self;
}

sub optimize
{
	my $self = shift;

	$self->{optimization_pass} = 1;
	$self->{log_count} = 0;

	delete $self->{best_minima};
	delete $self->{best_vec};

	if (@{ $self->{_ssize} } == 1)
	{
		return $self->_optimize;
	}

	my $result;
	foreach my $ssize (@{ $self->{_ssize} })
	{
		$self->set_ssize($ssize);
		$result = $self->_optimize;
		$self->set_vars($result);
		$self->{optimization_pass}++;
		$self->{log_count} = 0;
	}

	return $result;
}

sub _optimize
{
	my $self = shift;

	my $vec_initial = $self->_build_simplex_vars();

	$self->{cancel} = 0;

	delete $self->{prev_minima};
	delete $self->{prev_minima_count};

	my ( $vec_optimal, $opt_ssize, $optval ) = simplex($vec_initial,
		$self->{ssize},
		$self->{tolerance},
		$self->{max_iter},

		# This is the simplex callback to evaluate the function "f()"
		# based on the content of $self->{vars}:
		sub {
			my ($vec) = @_;
			my $ret = $vec->slice("(0)");

			if ($self->{cancel})
			{
				$ret *= 0;
				$ret += -1e9;
				return $ret;
			}

			# Call the user's function and pass their vars.
			# $f_ret is the resulting weight:
			my $f_ret = $self->{f}->($self->_get_simplex_vars($vec));

			if (!defined($self->{best_minima}) || $f_ret < $self->{best_minima})
			{
				$self->{best_minima} = $f_ret;
				$self->{best_vec} = $vec;
				$self->{best_pass} = $self->{optimization_pass};
			}

			# Whatever vector format $vec->slice("(0)") is, so $ret must be also.
			# So slice it, multiply times zero, and then add the result from f() above. 
			$ret *= 0;
			$ret += $f_ret;


			return $ret;
		},

		# log callback
		sub {
			my ($vec, $vals, $ssize) = @_;
			# $vec is the array of values being optimized
			# $vals is f($vec)
			# $ssize is the simplex size, or roughly, how close to being converged.

			return unless (defined($self->{log}));

			my $elapsed;
			if ($self->{prev_time})
			{
				$elapsed = time() - $self->{prev_time};
			}
			$self->{prev_time} = time();

			$self->{log_count}++;

			my $minima = $vec->slice("(0)", 0)->sclr;

			# Cancel early if stagnated:
			if (defined($self->{prev_minima}) && abs($self->{prev_minima} - $minima) < 1e-6)
			{
				$self->{prev_minima_count}++;
				if ($self->{prev_minima_count} > $self->{stagnant_minima_count})
				{
					$self->{cancel} = 1;
				}
			}
			elsif (!$self->{cancel})
			{
				$self->{prev_minima} = $minima;
				$self->{prev_minima_count} = 0;
			}


			$self->{log}->($self->_get_simplex_vars($vec), {
				ssize => $ssize,
				minima => $minima,
				elapsed => $elapsed,
				srand => $self->{srand},
				optimization_pass => $self->{optimization_pass},

				num_passes => scalar( @{ $self->{_ssize} }),
				best_pass => $self->{best_pass},
				log_count => $self->{log_count},
				cancel => $self->{cancel},
				prev_minima_count => $self->{prev_minima_count}
				});
		}
	);

	$self->{vec_optimal} = $vec_optimal;
	$self->{opt_ssize} = $opt_ssize;
	$self->{minima} = $optval->sclr;

	# Return the result in the original vars format that was
	# passed to new(vars => {...}) so it matches what the user
	# is expecting by converting it from simple to expanded
	# and finally to original:


	# Using {best_vec} might end up using a value from a previous
	# pass, completely disregarding the current pass.  Is this ok?
	my $result = $self->_get_simplex_vars($self->{best_vec});

	#my $result = $self->_get_simplex_vars($vec_optimal);

	$result = _simple_to_expanded($result);

	$result = $self->_expanded_to_original($result);

	# Round final values if any vars have round_result defined:
	_vars_round_result($result);

	# Store the result in the user's format:
	$self->{result} = $result;

	return $result;
}

sub get_vars_expanded
{
	my $self = shift;

	return $self->{vars};
}

sub get_vars_orig
{
	my $self = shift;

	return $self->{_vars_orig};
}


sub get_vars_simple
{
	my $self = shift;

	return _expanded_to_simple($self->{vars});
}

sub get_result_expanded
{
	my $self = shift;

	return $self->{result};
}

sub get_result_simple
{
	my $self = shift;

	return _expanded_to_simple($self->{result});
}

sub set_vars
{
	my ($self, $vars) = @_;

	# _simple_to_expanded will die if invalid:
	$self->{_vars_orig} = $vars;
	$self->{vars} = _simple_to_expanded($vars);
}

sub set_ssize
{
	my ($self, $ssize) = @_;

	$self->{ssize} = $ssize;
}

sub scale_ssize
{
	my ($self, $scale) = @_;

	$self->{ssize} *= $scale;
}



# build a pdl for use by simplex()
sub _build_simplex_vars 
{
	my ($self) = @_;

	my $vars = $self->{vars};

	# first element is for simplex's return-value use, set it to 0.	
	my @pdl_vars = (0);

	foreach my $var_name (sort keys(%$vars))
	{
		my $var = $vars->{$var_name};

		my $n = scalar(@{ $var->{values} });

		for (my $i = 0; $i < $n; $i++)
		{
			# var is enabled for simplex if enabled[$i] == 1
			if ($var->{enabled}->[$i])
			{
				push(@pdl_vars, $var->{values}->[$i] / $var->{perturb_scale}->[$i]);
			}
		}
	}

	return pdl \@pdl_vars;
}

sub _simple_to_expanded
{
	my ($vars) = @_;

	my %valid_opts = map { $_ => 1 } qw/values enabled minmax perturb_scale round_each round_result/;

	my %exp;
	foreach my $var_name (keys(%$vars))
	{
		my $var = $vars->{$var_name};

		# Copy the structure from what was passed into the %exp
		# hash so we can modify it without changing the orignal.
		if (ref($var) eq '')
		{
			$var = $exp{$var_name} = { values => [ $vars->{$var_name} ] }
		}
		elsif (ref($var) eq 'ARRAY')
		{
			$var = $exp{$var_name} = { values => $vars->{$var_name} }
		}
		elsif (ref($var) eq 'HASH')
		{
			my $newvar = $exp{$var_name} = {};

			foreach my $opt (keys %$var)
			{
				die "invalid option for $var_name: $opt" if (!$valid_opts{$opt});
			}

			foreach my $opt (keys %valid_opts)
			{
				$newvar->{$opt} = $var->{$opt} if exists($var->{$opt});
			}

			$var = $newvar;
		}
		else
		{
			die "invalid type for $var_name: " . ref($var);
		}

		# Make sure values is valid:
		if (!defined($var->{values}) ||
			(ref($var->{values}) eq 'ARRAY' && !@{$var->{values}}))
		{
			die "$var_name\-\>{values} must be defined"
		}

		if (ref($var->{values}) eq 'ARRAY')
		{
			# make a copy to release the original reference: 
			$var->{values} = [ @{ $var->{values} } ];
		}
		elsif (ref($var->{values}) eq '')
		{
			$var->{values} = [ $var->{values} ];
		}
		else
		{
			die "invalid type for $var_name\-\>{values}: " . ref($var->{values});
		}

		my $n = scalar(@{ $var->{values} });


		# If enabled is missing or a non-scalar (ie =1 or =0) then form it properly
		# as either all 1's or all 0's:
		if (!defined($var->{enabled}) || (!ref($var->{enabled}) && $var->{enabled}))
		{
			$var->{enabled} = [ map { 1 } (1..$n) ] 
		}
		elsif (defined($var->{enabled}) && !ref($var->{enabled}) && !$var->{enabled})
		{
			$var->{enabled} = [ map { 0 } (1..$n) ] 
		}

		if (ref($var->{minmax}) eq 'ARRAY' && ref($var->{minmax}->[0]) eq '' && @{$var->{minmax}} == 2)
		{
			$var->{minmax} = [ map { $var->{minmax} } (1..$n) ];
		}

		# Default the perturb_scale to 1x
		$var->{perturb_scale} //= [ map { 1 } (1..$n) ];

		# Make it an array the of length $n:
		if (!ref($var->{perturb_scale}))
		{
			$var->{perturb_scale} = [ map { $var->{perturb_scale} } (1..$n) ] 
		}

		if (defined($var->{round_each}) && !ref($var->{round_each}))
		{
			$var->{round_each} = [ map { $var->{round_each} } (1..$n) ] 
		}

		if (defined($var->{round_result}) && !ref($var->{round_result}))
		{
			$var->{round_result} = [ map { $var->{round_result} } (1..$n) ] 
		}

		# Sanity checks
		if (defined($var->{enabled}) && $n != scalar(@{ $var->{enabled} }))
		{
			die "variable $var_name must have the same length array for 'values' as for 'enabled'"
		}

		if (defined($var->{perturb_scale}) && $n != scalar(@{ $var->{perturb_scale} }))
		{
			die "variable $var_name must have the same length array for 'values' as for 'perturb_scale'"
		}

		if (defined($var->{minmax}))
		{
			if ($n != scalar(@{ $var->{minmax} }))
			{
				die "variable $var_name must have the same length array for 'values' as for 'minmax'"
			}

			for (my $i = 0; $i < $n; $i++)
			{
				my $mm = $var->{minmax}->[$i];

				if (ref($mm) ne 'ARRAY' || @$mm != 2)
				{
					die "$var_name\-\>{minmax} is not a 2-dimensional arrayref with [min,max] for each.";
				}

				my ($min, $max) = @$mm;

				if ($var->{values}->[$i] < $min)
				{
					die "initial value for $var_name\[$i] beyond constraint: $var->{values}->[$i] < $min " 
				}

				if ($var->{values}->[$i] > $max)
				{
					die "initial value for $var_name\[$i] beyond constraint: $var->{values}->[$i] > $max " 
				}
			}
		}
	}

	return \%exp;
}

# Return vars as documented below in POD:
sub _expanded_to_simple
{
	my $vars = shift;

	my %h;

	foreach my $var (keys %$vars)
	{
		if (ref($vars->{$var}) eq 'HASH')
		{
			defined($vars->{$var}->{values}) or die "undefined 'values' array for var: $var";
			$h{$var} = $vars->{$var}->{values};
		}
		elsif (ref($vars->{$var}) eq 'ARRAY')
		{
			$h{$var} = $vars->{$var};
		}
		elsif (ref($vars->{$var}) eq '')
		{
			$h{$var} = [ $vars->{$var} ];
		}
		else
		{
			die "unknown ref for var=$var: " . ref($vars->{$var});
		}

		if (ref($h{$var}) eq 'ARRAY' && scalar(@{ $h{$var} } ) == 1)
		{
			$h{$var} = $h{$var}->[0];
		}
	}

	return \%h;
}


# Return the $exp vars in the same original format as defined by $orig.  This is called as follows:
#   $self->_expanded_to_original($self->{vars})
#
sub _expanded_to_original
{
	my ($self, $exp) = @_;

	my $orig = $self->{_vars_orig};

	my %result;
	foreach my $var_name (keys(%$orig))
	{
		if (ref($orig->{$var_name}) eq '')
		{
			$result{$var_name} = $exp->{$var_name}->{values}->[0];
		}
		elsif (ref($orig->{$var_name}) eq 'ARRAY')
		{
			$result{$var_name} = [ @{ $exp->{$var_name}->{values} } ];
		}
		elsif (ref($orig->{$var_name}) eq 'HASH')
		{
			my $origvar = $orig->{$var_name};
			my $newvar = {};

			if (ref($orig->{$var_name}->{values}) eq 'ARRAY')
			{
				$newvar->{values} = [ @{ $exp->{$var_name}->{values} } ];
			}
			else
			{
				$newvar->{values} = $exp->{$var_name}->{values}->[0];
			}

			foreach my $opt (qw/enabled minmax perturb_scale round_each round_result/)
			{
				$newvar->{$opt} = $origvar->{$opt} if exists($origvar->{$opt});
			}

			$result{$var_name} = $newvar;
		}
	}

	return \%result;
}

# Use the round_result attribute of each var (if defined) to round
# the var to its nearest value.  $vars must be in expanded format.
sub _vars_round_result
{
	my ($vars) = @_;

	foreach my $var (values(%$vars))
	{
		my @round_result;

		next if !ref($var); 
		next unless defined $var->{round_result};

		my $n = @{ $var->{values} };

		# use temp var @round_result so we don't mess with the $vars structure.
		if (!ref($var->{round_result}))
		{
			@round_result = map { $var->{round_result} } (1..$n);
		}
		else 
		{
			@round_result = @{ $var->{round_result} };
		}

		# Round to a precision if defined:
		foreach (my $i = 0; $i < $n; $i++)
		{
			$var->{values}->[$i] = nearest($round_result[$i], $var->{values}->[$i]);
		}
	}

}

# get a var by name from $self->{vars} but get the value from the pdl if
# the var is enabled for optimization. Also minmax/perturb_scale as if defined
sub _get_simplex_var
{
	my ($self, $pdl, $var_name) = @_;

	my $vars = $self->{vars};

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

		# Increment pdl_idx for each element of the {enabled} array
		# that is enabled because that is how it is packed into the pdl.
		# The value of $_ in grep{} is either 1 or 0:
		$pdl_idx++ foreach (grep { $_ } @{ $var->{enabled} });
	}
	
	for (my $i = 0; $i < $n; $i++)
	{
		my $val;

		# use the pdl index if it is enabled for optimization
		# otherwise use the original index in $var.
		if ($var->{enabled}->[$i])
		{
			$val = unpdl($pdl->slice("($pdl_idx)", 0))->[0];
			$val *= $var->{perturb_scale}->[$i];
			$pdl_idx++;
		}
		else
		{
			$val = $var->{values}->[$i];
		}

		# Modify the resulting value depending on these rules:
		if (defined($var->{minmax}))
		{
			my ($min, $max) = @{ $var->{minmax}->[$i] };
			$val = $min if ($val < $min);
			$val = $max if ($val > $max);
		}

		# Round to the nearest value on each iteration.
		# It is probably best to round at the end to keep
		# precision during each iteration, but the option
		# is available:
		if (defined($var->{round_each}))
		{
			$val = nearest($var->{round_each}->[$i], $val);
		}

		push @ret, $val; 
	}

	return \@ret;
}

# get all vars replaced with resultant simplex values if enabled=>1 for that var.
sub _get_simplex_vars
{
	my ($self, $pdl) = @_;	
	
	my $vars = $self->{vars};

	my %h;

	foreach my $var (keys %$vars)
	{
		$h{$var} = $self->_get_simplex_var($pdl, $var);

		# collapse single-element arrays as scalars:
		if (ref($h{$var}) eq 'ARRAY' && scalar(@{ $h{$var} }) == 1)
		{
			$h{$var} = $h{$var}->[0]
		}
	}

	return \%h;
}

1;

__END__

=head1 NAME

PDL::Opt::Simplex::Simple - A simplex optimizer for the rest of us
(who may not know PDL).


=head1 SYNOPSIS

	use PDL::Opt::Simplex::Simple;

	# Simple single-variable invocation

	$simpl = PDL::Opt::Simplex::Simple->new(
		vars => {
			# initial guess for x
			x => 1 
		},
		f => sub { 
				# Parabola with minima at x = -3
				return (($_->{x}+3)**2 - 5) 
			}
	);

	$result_vars = $simpl->optimize();

	print "x=" . $result_vars->{x} . "\n";  # x=-3


	# Multi-vector Optimization and other settings:

	$simpl = PDL::Opt::Simplex::Simple->new(
		vars => {
			# initial guess for arbitrarily-named vectors:
			vec1 => { values => [ 1, 2, 3 ], enabled => [1, 1, 0] }
			vec2 => { values => [ 4, 5 ],    enabled => [0, 1] }
		},
		f => sub { 
				my ($vec1, $vec2) = ($_->{vec1}, $_->{vec2});
				
				# do something with $vec1 and $vec2
				# and return() the result to be minimized by simplex.
			},
		log => sub { }, # log callback
		ssize => 0.1,   # initial simplex size, smaller means less perturbation
		max_iter => 100 # max iterations
	);


	$result_vars = $simpl->optimize();

	use Data::Dumper;

	print Dumper($result_vars);


=head1 DESCRIPTION

This class uses L<PDL::Opt::Simplex> to find the values for C<vars>
that cause the C<f> coderef to return the minimum value.  The difference
between L<PDL::Opt::Simplex> and L<PDL::Opt::Simplex::Simple> is that
L<PDL::Opt::Simplex> expects all data to be in PDL format and it is
more complicated to manage, whereas, L<PDL::Opt::Simplex:Simple> uses
all scalar Perl values. (PDL values are not supported, or at least,
have not been tested.)

With the original L<PDL::Opt::Simplex> module, a single vector array
had to be sliced into the different variables represented by the array.
This was non-intuitive and error-prone.  This class attempts to improve
on that by defining data structure of variables, values, and whether or
not a value is enabled for optimization.

This means you can selectively disable a particular value and it will be
excluded from optimization but still included when passed to the user's
callback function C<f>.  Internal functions in this class compile the state
of this variable structure into the vector array needed by simplex,
and then extract values into a usable format to be passed to the user's
callback function.


=head1 FUNCTIONS

=item * $self->new(%args) - Instantiate class

=item * $self->optimize() - Run the optimization

=item * $self->get_vars_expanded() - Returns the original C<vars> in a fully expanded format

=item * $self->get_vars_simple() - Returns C<vars> in the simplified format

This format is suitable for passing into your C<f> callback.

=item * $self->get_vars_orig() - Returns C<vars> in originally passed format

=item * $self->get_result_expanded() - Returns the optimization result in expanded format.

=item * $self->get_result_simple() - Returns the optimization result in the simplified format

This format is suitable for passing into your C<f> callback.

=item * $self->set_vars(\%vars) - Set C<vars> as if passed to the constructor.

This can be used to feed a result from $self->get_result_expanded() into
a new refined simplex iteration.

=item * $self->set_ssize($ssize) - Set C<ssize> as if passed to the constructor.

Useful for calling simplex again with refined values

=item * $self->scale_ssize($scale) - Multiply the current C<ssize> by C<$scale>

=head1 ARGUMENTS

=head2 C<vars> - Hash of variables to optimize: the answer to your question.

=head3 Simple C<vars> Format 

Thes are the variables being optimized to find a minimized result.
The simplex() function returns minimized set of C<vars>. In its Simple
Format, the C<vars> setting can assign values for vars directly as in the
synopsis above:

	vars => {
		# initial guesses:
		x => 1,
		y => 2, ...
	}

or as vectors of (possibly) different lengths:

	vars => {
		# initial guess for x
		u => [ 4, 5, 6 ],
		v => [ 7, 8 ], ...
	}

=head3 Expanded C<vars> Format 

You may find during optimization that it would
be convenient to disable certain elements of the vector being optimized
if, for example, you know that one value is already optimal but that it
needs to be available to the f() callback.  The expanded format shows
that the 4th element is excluded from optimization by setting enabled=0
for that index.

Expanded format:  

	vars => {
		varname => {
			"values"         =>  [...],
			"minmax"         =>  [ [min=>max],  ...
			"perturb_scale"  =>  [...],
			"enabled"        =>  [...],
		},  ...
	}

=item C<varname>: the name of the variable being used.

=item C<values>:  an arrayref of values to be optimized

=item C<minmax>:  a double-array of min-max pairs (per index for vectors)

Min-max pairs are clamped before being evaluated by simplex.

=item C<round_result>:  Round the value to the nearest increment of this value upon completion

You may need to round the final output values to a real-world limit after optimization
is complete.  Setting round_result will round after optimization finishes, but leave 
full precision while iterating.  See also: C<round_each>.

This function uses L<Math::Round>'s C<nearest> function:

	nearest(10, 44)    yields  40
	nearest(10, 46)            50
	nearest(10, 45)            50
	nearest(25, 328)          325
	nearest(.1, 4.567)          4.6
	nearest(10, -45)          -50

=item C<round_each>:  Round the value to the nearest increment of this value on each iteration.

It is probably best to round at the end (C<round_result>) to keep precision
during each iteration, but the option is available in case you wish to
use it.

=item C<perturb_scale>:  Scale parameter before being evaluated by simplex (per index for vectors)

=over 4

This is useful because Simplex's C<ssize> parameter is the same for all
values and you may find that some values need to be perturbed more or
less than others while simulating.  User interaction with C<f> and the
result of C<optimize> will use the normally scaled values supplied by
the user, this is just an internal scale for simplex.

=item Bigger value:  perturb more

=item Smaller value:  perturb less

Internal details: The value passed to simplex is divided by perturb_scale
parameter before being passed and multiplied by perturb_scale when
returned.  Thus, perturb_scale=0.1 would make simplex see the value as
being 10x larger effectively perturbing it less, whereas, perturb_scale=10
would make it 10x smaller and perturb it more.

=back


=item C<enabled>: 1 or 0: enabled a specific index to be optimized (per index for vectors)

=over 4

=item * If 'enabled' is undefined then all values are enabled.

=item * If 'enabled' is not an array, it can be a scalar 0 or 1 to
indicate that all values are enabled/disabled.  In this case your original
structure will be replaced with an arrayref of all 0/1 values.

=item * Enabling or disabling a variable may be useful in testing
certain geometry charactaristics during optimization.

Internally, all values are vectors, even if the vectors are of length 1,
but you can pass them as singletons like C<spaces> is shown below if
you need to disable a single value:

    # Element lengths                                                
    vars => {
        lengths => {                                                     
            values         =>  [  1.038,       0.955,        0.959 ],
            minmax         =>  [  [0.5=>1.5],  [[0.3=>1.2],  [0.2=>1.1] ],
            perturb_scale  =>  [  10,          100,          1 ],
            enabled        =>  [  1,           1,            1 ],
        },                                                       
        spaces => {
            values => 5, 
            enabled => 0
        },
        ...
    }

=back

=head2 * C<f> - Callback function to operate upon C<vars>

The C<f> argument is a coderef that is called by the optimizer.  It is passed a hashref of C<vars> in 
the Simple Format and must return a scalar result:

	f->({ lengths => [ 1.038, 0.955, 0.959, 0.949, 0.935 ], spaces => 5 });

Note that a single-length vector will always be passed as a scalar to C<f>:

	vars => { x => [5] } will be passed as f->({ x => 5 })

The Simplex algorithm will work to minimize the return value of your C<f> coderef, so return 
smaller values as your variables change to produce a (more) desired outcome.

=head2 * C<log> - Callback function log status for each iteration.

	log => sub { 
			my ($vars, $state) = @_;
		
			print "LOG: " . Dumper($vars, $state);
		}

The log() function is passed the current state of C<vars> in the
same format as the C<f> callback.  A second C<$state> argument is passed
with information about the The return value is ignored.  The following 
values are available in the C<$state> hashref:

    {
	'ssize' => '704.187123721893',  # current ssize during iteration
	'minima' => '53.2690700664067', # current minima returned by f()
	'elapsed' => '3.12',            # elapsed time in seconds since last log() call.
	'srand' => 55294712,            # the random seed for this run
	'log_count' => 5,               # how many times _log has been called
	'optimization_pass' => 3,       # pass# if multiple ssizes are used
	'num_passes' => 6,              # total number of passes
	'best_pass' =>  3,              # the pass# that had the best goal result
	'log_count' => 22,              # number of times log has been called
	'prev_minima_count' => 10,      # number of same minima's in a row
	'cancel' =>     0               # true if the simplex iteration is being cancelled
    }


=head2 * C<ssize> - Initial simplex size, see L<PDL::Opt::Simplex>

Think of this as "step size" but not really, a bigger value makes larger
jumps but the value doesn't translate to a unit.  (It actually stands
for simplex size, and it initializes the size of the simplex tetrahedron.)

You will need to scale the C<ssize> argument depending on your search
space.  Smaller C<ssize> values will search a smaller space of possible
values provided in C<vars>.  This is problem-space dependent and may
require some trial and error to tune it where you need it to be.

Example for optimizing geometry in an EM simulation: Because it is
proportional to wavelength, lower frequencies need a larger value and
higher frequencies need a lower value.

The C<ssize> parameter may be an arrayref:  If an arrayref is specified
then it will run simplex to completion using the first ssize and then
restart with the next C<ssize> value in the array.  Each iteration uses
the best result as the input to the next simplex iteration in an attempt
to find increasingly better results.  For example, 4 iterations with each
C<ssize> one-half of the previous:

	ssize => [ 4, 2, 1, 0.5 ]


Default: 0.1

=head2 * C<max_iter> - Maximim number of Simplex iterations

Note that one Simplex iteration may call C<f> multiple times.

Default: 1000

=head2 * C<tolerance> - Conversion tolerance for Simplex

The default is 1e-6.  It tells Simplex to stop before C<max_iter> if 
very little change is being made between iterations.

Default: 1e-6

=head2 * C<srand> - Value to seed srand

Simplex makes use of random perturbation, so setting this value will make
the simulation deterministic from run to run.

The default when not defined is to call srand() without arguments and use
a randomly generated seed.  If set, it will call srand($self->{srand})
to initialize the initial seed.  The result of this seed (whether passed
or generated) is available in the status structure defined above.

Default: system generated.

=head2 * C<stagnant_minima_count> - Abort the simplex iteration if the minima is not changing

This is the maximum number of iterations that can return a worse minima
than the previous minima. Once reaching this limit the current iteration
is cancelled due to stagnation. Setting this too low will provide poor
results, setting it too high will just take longer to iterate when it
gets stuck.

Note: This value may be somewhat dependent on the number of variables
you are optimizing.  The more variables, the bigger the value.  A value
of 30 seems to work well for 10 variables, so adjust if necessary.

Default: 30

=head1 SEE ALSO

L<http://pdl.perl.org/>, L<PDL::Opt::Simplex>, L<https://en.wikipedia.org/wiki/Simplex_algorithm>

=head1 AUTHOR

Originally written at eWheeler, Inc. dba Linux Global Eric Wheeler to
optimize antenna geometry for the L<https://www.xnec2c.org> project.


=head1 COPYRIGHT

Copyright (C) 2021 eWheeler, Inc. L<https://www.linuxglobal.com/>

This module is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

This module is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with this module. If not, see <http://www.gnu.org/licenses/>.

