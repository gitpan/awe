package awe::Object::Login;
use strict;
use awe::Login;
use base qw(awe::Object::Db);

sub runContextAction {
  my $self=shift;
  if ($self->CheckLogin()) {
    return $self->awe::Object::Db::runContextAction();
  } else {
    return $self->runAction('nologin');
  }
}

sub CheckLogin {
  my $self=shift;
  return undef unless awe::Login::CheckLogin();
  return $self->PostLogin();
}

sub PostLogin { return 1; }

sub getFieldsValueBySrc {
  my ($self,$name,$src,$value)=@_;
  return $src eq 'user' ?
    user($value || $name) :
      $self->SUPER::getFieldsValueBySrc($name,$src,$value);
}

1;
