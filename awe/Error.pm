package awe::Error;
use vars qw(@ISA
						@EXPORT
					 );

@ISA = qw(Error);

sub new {
    my $self  = shift;
    my $code  = shift;
		unshift @_,$code unless $code=~/^\d+$/;
    local $Error::Depth = $Error::Depth + 1;
    $self->SUPER::new(-text => awe::Conf::getMessage($code,@_),
											-value => $code);
}

sub stringify {
	my $self = shift;
	$self->SUPER::stringify();
}

1;
