package awe::Object;
use strict;
use Apache::Constants qw(:common BAD_REQUEST REDIRECT);
#use Exporter;
use awe::Db;
use awe::Log;
use awe::Login;
use awe::Conf;
use awe::View;
use awe::Data;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
@EXPORT=qw(
					 confObject
					 confObjectA
					 confObjectH
					);


sub init {
	my ($self,$init)=@_; # Устанавливается, когда это init из awe::Main2 и нужно инициализировать базу
	return fatal(13)
		unless $self->connectToDB();
	return 1;
}

sub runContextAction {
	my $self=shift;
	http_code(OK);
	setContext('action',context('action') || $self->getAction());
	notice(103);
	return $self->run('nologin')
		unless $self->checkLogin();
	return undef
		unless $self->checkAuth();
	return undef
		unless $self->preAction();
	my $res=$self->run(context('action'));
	output({result=>$res});
}

sub run {
	my ($self,$action)=@_;
	my $ref;
	return fatal(9,$action,$self)
		unless $ref=$self->can("ACTION_$action");
	template($action);
	return &$ref(param());
}


sub getAction {
	my $action=param('action');
	$action=~s/[^A-Z0-9_]+//gi;
	return  $action || 'default';
}

sub connectToDB { 1; } # return awe::Db::CONNECT();

sub deinit {
	return 1;
}

sub preAction {
	return 1;
}

sub confObject { 	return conf('objects',context('object'),@_);}
sub confObjectA { 	return confA('objects',context('object'),@_);}
sub confObjectH { 	return confH('objects',context('object'),@_);}

# OK DELINED NOT_FOUND REDIRECT

sub ACTION_nologin { 	return 1; } # AUTH_REQUIRED
sub ACTION_noauth  { 	return 1; } # FORBIDDEN

sub noauth {
	my $self=shift;
	notice(114,@_);
	output::noauth(@_);
	$self->run('noauth');
	return undef;
}

sub checkLogin {
	return awe::Login::checkLogin();
}

sub checkAuth {
	my $action=shift;
	#	noauth(2);
	return 1;
}

1;
