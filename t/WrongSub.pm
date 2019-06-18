package t::WrongSub;
use strict;
use warnings;

sub some_event
{
	die 'Throw exception';
}

1;