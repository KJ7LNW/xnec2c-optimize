package NEC2;

use strict;
use warnings;

use NEC2::CM;
use NEC2::GW;
use NEC2::GE;
use NEC2::EX;
use NEC2::RP;
use NEC2::GN;
use NEC2::NH;
use NEC2::NE;
use NEC2::FR;
use NEC2::EN;

use overload '""' => \&stringify;

sub new
{
	my ($class, %args) = @_;

	my %h = $class->defaults;
	foreach my $k (keys(%args))
	{
		$h{$k} = $args{$k};
	}

	return bless(\%h, $class);
}

sub stringify
{
	my ($self) = @_;
	my $class = ref $self;

	my $card = $class;
	$card =~ s/.*:://;
	$card =~ s/(^[A-Z]{2}).*$/$1/;

	return "$card " . join("\t", $self->card_vals) . "\n";
}

# Allow shorthand keys defined by the class, but remap them to those
# officially defined by NEC2 and make them upper case:
sub fix_keys
{
	my $self = shift;

	foreach my $k (keys(%$self)) {
		if (!scalar(grep { lc($k) eq lc($_) } $self->params()) && !$self->param_map(lc($k)))
		{
			die "invalid key '$k' for class " . ref($self);
		}

		if (defined($self->param_map(lc($k)))) {
			$self->{ $self->param_map(lc($k)) } = $self->{$k};
		}
		elsif (uc($k) ne $k) {
			$self->{ uc($k) } = $self->{$k};
		}
	}

}

sub card_vals
{
	my $self = shift;
	$self->fix_keys;
	return map { $self->{$_} || 0 } $self->params();
}

# Return nonzero if this is a tagged geometry.
sub tagged
{
	my $self = shift;

	scalar(grep {ref($self) eq $_} map { "NEC2::$_" } qw/GA GH GW/);
}

sub save
{
	my ($fn, @structure) = @_;

	open(my $structure, "|column -t > $fn") or die "$!: $fn";

	print $structure @structure;

	close($structure);
}

# Default card override functions
sub params
{
	my $self = shift;

	die "incomplete class: " . ref($self);
}

sub param_map
{
	my ($self, $param) = @_;
	die "incomplete class: " . ref($self);
}

sub defaults
{
	return ()
}

1;
