package awe::Object::Base;
use strict;
use Apache::Constants;
use awe::Log;
use awe::Conf;
use awe::View;
use awe::Context;

sub instance {
  my ($class)=@_;
  my $self = {data=>{}};
  $self = bless $self, $class;
  return $self->init() ? $self : undef;
}

sub runContextAction {
  my $self=shift;
  $self->findAction();
  log_notice(103,uri()->actionPath());
  my $action = context('action');
  http_code(OK);
  template($action);
  return $self->runAction($action);
}

sub runAction {
  my ($self,$action)=@_;
  return undef
    unless $self->preAction($action);
  my $ref;
  return fatal(9,$action,$self)
    unless $ref=$self->can("ACTION_$action");
  return $self->postAction($action,&$ref($self,param()));
}

sub findAction {
  my $self = shift;
  my $action = context('action');
  return if $action;
  my $a = confObjectA('URI');
  my $uri = uri()->actionPath();
  if (@$a) {
    foreach (@$a) {
      fatal(53,'URI',$_) unless /^([^*:]*)(\*?):(\S+)$/;
      my ($u,$a,$act)=($1,$2,$3);
      $u='' if $u eq '/';
      if ($uri eq $u) {
	$action=$act;
	last;
      } elsif ($a && $uri=~/^$u/i) {
	$action=$uri;
	$action=~s/^$u//i;
	last;
      }
    }
    $action=~s/[^A-Z0-9_]+//gi;
    return fatal(9,'',$self)
      unless $action;
  } else {
    $action='default';
  }
  return setContext('action',$action || 'default');
}

sub data {
  my $self = shift;
  return $self->{data} unless @_;
  my $key = shift;
  return @_ ? $self->{data}->{$key}=shift : $self->{data}->{$key};
}

sub preAction   { 1; }
sub postAction  { my ($self,$action,$res)=@_; return $res; }
sub init        { 1; }
sub deinit      { 1; }

1;
