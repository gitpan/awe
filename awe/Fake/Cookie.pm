package awe::Fake::Cookie;
use strict;
use awe::Context;
use awe::Log;
use awe::Conf;
use Apache::Util;
use Apache::Cookie;

sub new {
	my $class=shift;
	return bless {cookie=>awe::Context::apr()->cookie()}, $class;
}

sub get {
	my $self=shift;
	return $self->{cookie};
}


sub set {
	my $self=shift;
	my $hr = shift;
}

1;
