package awe::Object::User;
use strict;
use awe::Table;
use awe::URI;
use awe::Login;
use awe::Conf;
use awe::Log;
use awe::Context;
use base qw(awe::Object::Db);
use vars qw(%CONFIG);

%CONFIG =  (
	    'objects.user' =>
	    {
	     table   => 'user',
	     module  => 'awe::Object::User',
	    },
	    'templates.user' =>
	    {
	     nologin => '',
	     login   => 'redirect:${param:backurl}',
	     logout  => 'redirect:${param:backurl}',
	    }
	   );

awe::Conf::addDefaultConfig(\%CONFIG);


sub ACTION_login {
  param()->{backurl} = uri()->home()
    unless param('backurl');
  template('nologin')
    unless awe::Login::Login(param(),2);
}

sub ACTION_logout {
  param()->{backurl} = uri()->home()
    unless param('backurl');
  template('nologin')
    unless awe::Login::Login(undef,2);
}

sub ACTION_list {
  my $self=shift;
  return {registered => table()->List({anonymous=>0}),
	  anonymous  => table()->List({anonymous=>1})};
}

1;
