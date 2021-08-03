package NEC2::Card::CM;

use strict;
use warnings;

use parent 'NEC2::Card';

use overload '""' => \&stringify;


sub param_map
{
	# always return 0, there is only one index:
	return 0;
}


# this seems cumbersome to override stringify, but CM is neither a geo_card nor a program_card
# so ... this works to split the card into multiple lines. Maybe there should be 
# comment_cards() and is_comment_card() functions.
sub stringify
{
	my $self = shift;

	my @ret;
	if (defined($self->{card}) && defined($self->{card}->[0]) && $self->{card}->[0] =~ /[\r\n]/s)
	{
		foreach my $comment (split /[\r\n]/, $self->{card}->[0])
		{
			push @ret, NEC2::Card::CM->new(comment => $comment);
		}
	}
	else
	{
		return $self->SUPER::stringify();
	}

	return join('', @ret);
}

1;


# Nothing special about CE, so use CM.
package NEC2::Card::CE;
use parent 'NEC2::Card::CM';

1;
