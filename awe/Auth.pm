package awe::Auth;
use base qw(Exporter);
use strict;
use awe::Context;
use awe::Conf;
use awe::Login;
use awe::Log;
use vars qw(@EXPORT
	    %CONFIG
	   );

@EXPORT = qw(
	     hasPerm
	     inquirePerm
	     group
	     CheckAllPerms
	    );

%CONFIG =
  (
   main =>
   {permissions => 'is_admin:group groups:sys'},
   'tables.userGroup' =>
   {
    table  => 'table_usergroup',
    attr   => 'usergroup_id:numeric usergroup_name:char(100) usergroup_desc:char(500) is_admin:boolean',
    id	   => 'usergroup_id'
   },
   'tables.u2g'   =>
   {
    table  => 'table_user2group',
    attr   => 'usergroup_id:numeric user_id:numeric',
   }
  );

awe::Conf::addDefaultConfig(\%CONFIG);


sub groups {
  my $group = context('group');
  $group=loadGroups()
    unless $group;
  return $group->getList(@_);
}

sub loadGroups {
  my $group = awe::Table->new('userGroup');
  my $u2g   = awe::Table->new('u2g');
  $group->List(['usergroup_id in ( select usergroup_id from table_user2group where user_id = ?)',
		{'-'=>user('user_id')}
	       ]);
  return setContext('group',$group);
}

# The reasone to use this function is cache and store the value of all
# permissions into the CONTEXT


sub CheckAllPerms {
  return hasPerm(keys %{confH('main.permissions')});
}


sub hasPerm {
  my $perms = context('permission') || {};
  my $sum=0;
  foreach (@_) {
    $perms->{$_}=inquirePerm($_)
      unless exists $perms->{$_};
    $sum++ if $perms->{$_};
  }
  setContext('permission',$perms);
  return $sum;
}

sub inquirePerm {
  my ($name) = @_;
  my $type = confH('main.permissions')->{$name} || fatal(60,$name);
  if ($type eq 'user') {
    return user()->get($name);
  } elsif ($type eq 'group') {
    foreach (@{groups()}) {
      return 1 if $_->{$name};
    }
  } elsif ($type eq 'sys') {
    if ($name eq 'groups') {
      return groups();
    } else {
      fatal(62,$name);
    }
  } else {
    fatal(61,$type);
  }
  return undef;
}

=pod

create table table_userGroup (
			 userGroup_id   integer not null,
			 userGroup_name  varchar(100) not null unique,
			 userGroup_desc  varchar(500) not null,
                         is_admin       integer default 0 not null,
			 primary key (userGroup_id)
			);

create generator table_userGroup_seq;

insert into table_userGroup values (0,'Administrators','Allow all',1);

create table table_user2group (
			 usergroup_id   integer not null,
			 user_id    integer not null,
			 foreign key (user_id)
			 references table_user (user_id)
			 on delete cascade,
			 foreign key (usergroup_id)
			 references table_usergroup (usergroup_id)
			 on delete cascade
			);

insert into table_user2group values (0,0);

=cut



1;
