package awe::Default;
use awe::Object;
use awe::Data;
use vars qw(@ISA);

@ISA=qw(awe::Object);

sub checkLogin {
#	die context::action() eq 'logout';
	return (context('action') eq 'logout')
		? awe::Login::login('')
			: awe::Object::checkLogin();
}

sub ACTION_login  { 	return 1; } # AUTH_REQUIRED
sub ACTION_logout {  	return 1; } # AUTH_REQUIRED
