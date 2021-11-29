package NEC2::Polyline;

use parent 'NEC2::Shape';

use strict;
use warnings;

use NEC2;


sub defaults
{
	return ( );
}


# points => [ [x,y,z], [x,y,z], [x,y,z], ... ]
sub new 
{
	my ($class, %args) = @_;
	my $self = bless(\%args, $class);

	my %defaults = $self->defaults;
	foreach my $k (keys %defaults)
	{
		$self->{$k} //= $defaults{$k};
	}

	$self->gen_cards;

	return $self;
}


sub gen_cards
{
	my $self = shift;

	my (@geo, @program);
	my $prev;

	die "Must have at least 2 points" if (scalar(@{ $self->{points} }) < 2);

	$self->{_tag} = $self->{tag};

	foreach my $point (@{ $self->{points} })
	{
		if ($prev)
		{
			# All parameters in $self except 'points' and 'tag' are passed to GW:
			my $gw = GW(points => [ $prev => $point ], 
				tag => $self->{_tag}++,
				map { $_ => $self->{$_} } grep { $_ !~ /(^_|points$|tag$)/ } keys %$self);

			push @geo, $gw;
		}
		$prev = $point;
	}

	$self->{_geo_cards} = \@geo;
}

sub geo_cards
{
	my $self = shift;

	return @{ $self->{_geo_cards} };
}

sub program_cards
{
	my $self = shift;

	return ();
}

1;
