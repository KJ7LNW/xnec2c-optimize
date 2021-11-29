# Base class for objects that need to behave similar to an NEC2::Card but are not official NEC2 cards.
package NEC2::Shape;

sub comment_cards { return () }
sub geo_cards { return () }
sub program_cards { return () }

1;
