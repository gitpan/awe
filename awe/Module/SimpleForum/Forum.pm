package awe::Module::SimpleForum::Forum;
use strict;
use awe::Context;
use awe::Table;
use base qw(awe::Object::Login);
use vars qw(%CONFIG);

%CONFIG =
	(
	 'tables.simpleforum_forum' =>
	 {
		table => 'simpleforum_forum',
		attr  => 'forum_id:numeric name:char(200) description:char(3000) dateCreate:date user_id:numeric',
		id    => 'forum_id'
	 },
	 'objects.simpleforum_forum' =>
	 {
		table  => 'simpleforum_forum',
		module => 'awe::Module::SimpleForum::Forum',
	 }
	);
awe::Conf::addDefaultConfig(\%CONFIG);

sub ACTION_default {
	return table()->List();
}


=pod

create table simpleforum_forum (
	user_id     integer not null,
	forum_id    integer not null,		
	name        varchar(200) not null,
	description varchar(3000) not null,
	dateCreate  timestamp,
	primary key (forum_id),
 	foreign key (user_id)
		references table_user (user_id)
);

create generator simpleforum_forum_seq;

insert into simpleforum_forum values(0,0,'Поговори со мной..','','now');

=cut


1;
