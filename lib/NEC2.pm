package NEC2;

use strict;
use warnings;

use overload '""' => \&stringify;

sub new
{
	my ($class, %args) = @_;

	return bless(\%args, $class);
}

sub stringify
{
	my ($self) = @_;
	my $class = ref $self;

	my $card = $class;
	$card =~ s/.*:://;

	return "$card " . join("\t", $self->card_vals) . "\n";
}

# Allow shorthand keys defined by the class, but remap them to those
# officially defined by NEC2 and make them upper case:
sub fix_keys
{
	my $self = shift;

	foreach my $k (keys(%$self)) {
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

1;
