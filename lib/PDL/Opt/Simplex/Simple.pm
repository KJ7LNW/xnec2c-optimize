package PDL::Opt::Simplex::Simple;

use strict;
use warnings;

use PDL;
use PDL::Opt::Simplex;

sub new
{
	my ($class, %args) = @_;

	my $self = bless(\%args, $class);

	$self->{tolerance}  //=  1e-6;
	$self->{max_iter}   //=  100;
	$self->{ssize}      //=  0.1;

	# vars, ssize, tolerance, max_iter, f, log
	return $self;
}

sub optimize
{
	my $self = shift;

	my $vec_initial = $self->_build_simplex_vars($self->{vars});

	my ( $vec_optimal, $opt_ssize, $optval ) = simplex($vec_initial,
		$self->{ssize},
		$self->{tolerance},
		$self->{max_iter},

		# This is the simplex callback to evaluate the function "f()"
		# based on the content of $self->{vars}:
		sub {
			my ($vec) = @_;

			# Call the user's function and pass their vars.
			# $f_ret is the resulting weight:
			my $f_ret = $self->{f}->($self->_get_simplex_vars($vec));

			# Whatever vector format $vec->slice("(0)") is, so $ret must be also.
			# So slice it, multiply times zero, and then add the result from f() above. 
			my $ret = $vec->slice("(0)");
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

			my $minima = $vec->slice("(0)", 0)->sclr;
			$self->{log}->($self->_get_simplex_vars($vec), 
				{ ssize => $ssize, minima => $minima });
		}
	);

	$self->{vec_optimal} = $vec_optimal;
	$self->{opt_ssize} = $opt_ssize;
	$self->{minima} = $optval->sclr;

	return $self->_get_simplex_vars($vec_optimal);
}

sub get_vars_initial
{
	my $self = shift;

	return _get_vars($self->{vars});
}

sub set_vars
{
	my ($self, $vars) = @_;

	# validate vars, will die if invalid:
	_get_vars($self->{vars});

	$self->{vars} = $vars;

	# return user-formated vars:
	return $self->get_vars_initial();

}

# Return vars as documented below in POD:
sub _get_vars
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

		if (scalar(@{ $h{$var} } ) == 1)
		{
			$h{$var} = $h{$var}->[0];
		}
	}

	return \%h;
}

# build a pdl for use by simplex()
sub _build_simplex_vars 
{
	my ($self, $vars) = @_;

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

# get a var by name from $self->{vars} but get the value from the pdl if
# the var is enabled for optimization.
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

# get all vars
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
		ssize => 0.1,   # initial simplex size, smaller means less purturbation
		max_iter => 100 # max iterations
	);


	$result_vars = $simpl->optimize();

	use Data::Dumper;

	print Dumper($result_vars);


=head1 DESCRIPTION

This class uses L<PDL::Opt::Simplex> to find the values for C<vars>
that cause the C<f> sub to return the minimum value.  The difference
between L<PDL::Opt::Simplex> and L<PDL::Opt::Simplex::Simple> is that
L<PDL::Opt::Simplex> expects all data to be in PDL format and it is
more complicated to manage, whereas, L<PDL::Opt::Simplex:Simple> uses
all scalar Perl values. (PDL values are not supported, or at least,
have not been tested.)

=head1 FUNCTIONS

=item * new()
=item * optimize()

=head1 ARGUMENTS

=item * C<vars> - Hash of variables to optimize: the answer to your question.

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

Expanded C<vars> format: You may find during optimization that it would
be convenient to disable certain elements of the vector being optimized
if, for example, you know that one value is already optimal but that it
needs to be available to the f() callback.  The expanded format shows
that the 4th element is excluded from optimization by setting enabled=0
for that index.


	# Element lengths                                                
	vars => {
		lengths => {                                                     
				        values  => [ 1.038, 0.955, 0.959, 0.949, 0.935 ],
				        enabled => [ 1,     1,     1,     0,     1 ]     
		},                                                       
		spaces => {
			values => 5, 
			enabled => 0
		},
		...
	}

Internally, all values are vectors, even if the vectors are of length 1,
but you can pass them as singletons like C<spaces> is shown above if
you need to disable a single value.

=item * C<f> - Callback function to operate upon C<vars>

The C<f> argument is a coderef that is called by the optimizer.  It is passed a hashref of C<vars> in 
the Simple Format and must return a scalar result:

	f->({ lengths => [ 1.038, 0.955, 0.959, 0.949, 0.935 ], spaces => 5 });

Note that a single-length vector will be passed as a scalar:

	vars => { x => [5] } will be passed as f->({ x => 5 })

The Simplex algorithm will work to minimize the return value of your C<f> coderef.

=item * C<log> - Callback function log status for each iteration.

	log => sub { 
			my ($vars, $state) = @_;
		
			print "LOG: " . Dumper($vars, $state);
		}

The log() function is passed the current state of C<vars> in the
same format as the C<f> callback.  A second C<$state> argument is passed
with information about the The return value is ignored.

=item * C<ssize> - Initial simplex size, see L<PDL::Opt::Simplex>

You will need to scale the C<ssize> argument depending on your search
space.  Smaller C<ssize> values will search a smaller space of possible
values provided in C<vars>.  This is problem-space dependent and may
require some trial and error to tune it where you need it to be.

Default: 0.1

=item * C<max_iter> - Maximim number of Simplex iterations

Note that one Simplex iteration may call C<f> multiple times.

Default: 100

=item * C<tolerance> - Conversion tolerance for Simplex

The default is 1e-6.  It tells Simplex to stop before C<max_iter> if 
very little change is being made between iterations.

Default: 1e-6

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

