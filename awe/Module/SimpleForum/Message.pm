package awe::Module::SimpleForum::Message;
use strict;
use awe::Table;
use awe::Context;
use awe::Login;
use base qw(awe::Object::Login);
use vars qw(%CONFIG);

%CONFIG =
	(
	 'tables.simpleforum_message' =>
	 {
		table   => 'simpleforum_message',
		attr    => 'message_id:numeric forum_id:numeric subject:char(200) name:char(100) text:char(10000) dateCreate:date user_id:numeric',
		default => 'dateCreate:now',
		id      => 'message_id',
		order   => 'dateCreate desc',
	 },
	 'objects.simpleforum_message' =>
	 {
		table   => 'simpleforum_message',
		module  => 'awe::Module::SimpleForum::Message',
	 },
	 'objects.simpleforum_message.fields' =>
	 {
		create  => 'forum_id:data(forum) user_id:user() subject:param text:param name:param',
	 }
	);
awe::Conf::addDefaultConfig(\%CONFIG);


sub init {
	my $self = shift;
	return undef unless $self->SUPER::init(@_);
	return $self->loadForum();
}

sub loadForum {
	my ($self,$forum_id)=@_;
	$forum_id=param('forum_id')
		unless defined $forum_id;
	return
		$self->data('forum',
								table('simpleforum_forum')->
								Load($forum_id));
}

sub lastUsersMessage {
	my ($self,$user_id)=@_;
	$user_id=user('user_id')
		unless defined $user_id;
	return $self->lastMessage({user_id=>$user_id});
}

sub lastMessage {
	my $self = shift;
	return table()->
		SelectOne([@_,"message_id = (select max(message_id) from simpleforum_message)"]);
}

sub ACTION_default {
	my $self=shift;
 	return $self->action_list();
}

sub ACTION_create {
	my $self=shift;
 	return $self->action_create();
}


=pod

create table simpleforum_message (
	user_id     integer not null,
	message_id  integer not null,		
	forum_id    integer not null,
  name        varchar(100) not null,
  subject     varchar(200) not null,
	text        varchar(10000) not null,
	dateCreate  timestamp,
	primary key (message_id),
 	foreign key (forum_id)
		references simpleforum_forum (forum_id)
);

create generator simpleforum_message_seq;

=cut


1;
