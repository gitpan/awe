package awe::Login;
use strict;
use Apache::Session::Generate::MD5;
use awe::Context;
use awe::Conf;
use awe::Log;
use awe::Db;
use awe::Table;
use awe::URI;
use base qw(Exporter);
use vars qw(
	    @EXPORT
	    %CONFIG
	   );

@EXPORT = qw(
	     user
	    );

%CONFIG =
  (
   'login.fields' =>
   {
    login     => 'loginDate',   # last login date
    counter   => 'counter',     # login counter
    register  => 'registerDate', # registration date
    anonymous => 'anonymous',   # anonymous flag
    # Устанавливается при автогенерации пользователя. И означает
    # что этот пользователь чисто сессионный и анонимный.
   },
   'login.cookie' =>
   {
    expires   => '+100d',
    path      => '',
   },
	 
   'login' =>
   {
    allowCGI  => 0, # Allow to login by CGI parameters

    delete_anonymous_after_login => 1,
    
    # What we must to do if there is no defined login (user is anonymous).
    #
    # default - Load default user (there is user with login='' in database)
    # session - Generate session user
    #
    # Otherwise it creates empty user's record.
		
    anonymous => 'session',
   },
	 
   'tables.user' =>
   {
    table  => 'table_user',
    attr	 => 'user_id:numeric login:char(50) name:char(200) passkey:char(50) counter:numeric anonymous:boolean registerDate:date loginDate:date',
    id		 => 'user_id'
   }
  );

awe::Conf::addDefaultConfig(\%CONFIG);

sub CheckLogin {
  my $p=param();
  return Login($p,2)
    if conf('login.allowCGI') && exists $p->{login};
  return Login(cookie()->get(),1);
}

sub user {
  my $user =  context('user');
  setContext('user',$user=awe::Table->new('user'))
     unless $user;
  return @_ ? $user->get(@_) : $user;
}

sub Failed {
  my $reason=shift;
  my $hr=shift;
  user()->clear();
  log_warn(105,$hr->{login},$reason);
  setContext('access',{reason=>$reason,
		       login=>$hr->{login}});
  return 0;
}

sub generateEmptyUser {
  log_info('Generate Empty user');
}

# Делает запись о заходе пользователя в базу,
# устанавливает при необходимости куку

sub doLogin {
  my $setCookie = shift;
  my $login = user('login');
  my ($loginDate,$counter)=(conf('login.fields.login'),conf('login.fields.counter'));
  if (($loginDate || $counter) && user('user_id')) {
    my @a;
    push @a,"$counter=$counter+1" if $counter;
    push @a,{$loginDate=>'now'}   if $loginDate;
    dbTransaction {
      user()->Modify(\@a);
    };
  }
  if ($setCookie) {
    my %hr=(login    =>$login,
	    password =>user('passkey'));
    my $anonymous=conf('login.fields.anonymous');
    $hr{anonymous}=user($anonymous) if $anonymous;
    cookie()->set(\%hr);
    log_info('Set cookie:',join(',',%hr));
  }
  setContext('access',{user=>user()->get()});
  log_info(107,$login);
  return 1;
}

# $type:
# 1 - login by cookie
# 2 - login by CGI parameters
# false - login by internal operation

sub Login {
  my ($hr,$type)=@_;

  $hr={login=>'',password=>''}
    unless $hr && $hr->{login};
  $type+=0;
  my $anonConf=conf('login.anonymous');
  my $anonymous=conf('login.fields.anonymous');
  
  return createSessionUser()
    if $anonConf eq 'session' && !$hr->{login};
	
  # Если есть логин, или установлен режим загрузки дефолтного
  # пользователя (такой должен быть в базе), продолжаем
  log_info('There is user:',$hr->{login});
  if ($hr->{login} || $anonConf eq 'default') {
    my $where={login=>$hr->{login}};
    $where->{$anonymous}=0
      if $anonymous && $type != 1;
    unless (user()->Load($where)) {
      log_warn('No such user',$hr->{login});
      # Такой пользователь не найден.
      # Если не включен режим сессий (автогенерации), то вылетаем сразу.
      
      # Если режим автогенерации (сессии) включен и мы логируемы через
      # куки и в куке есть параметр anonymous (только при таких условиях
      # это настоящий сессионный пользователь), то сгенерируем его заново.
      return createSessionUser() if $type==1 && $hr->{anonymous} && $anonConf eq 'session';
      
      # Иначе говорим, что такого пользователя нет.
      return Failed('nouser',$hr);
    }
    if (user('passkey') ne $hr->{password}) {
      log_warn('Bad password',$hr->{password},' must be ',user('passkey'));
      # Тоже, что и выше. Хотя странно, почему пользователь есть, а пароль не подходит?
      return createSessionUser() if $type==1 && $hr->{anonymous} && $anonConf eq 'session';
      return Failed('wrong',$hr);
    }
    # Если включен режим авторегистрации и пользователь заходит на сайт не через
    # куки, то возможно у него в куке осталась запись о сессионном
    # пользователе (например он сначала зашел на сайт, сгенерировалась сессия, затем он
    # залогировался), попытаемся удалить этого сессионного пользователя из базы.
    # Естественно делаем это только если разрешено в конфиге
    deleteSessionUser()
      if conf('login.delete_anonymous_after_login') &&
	$anonConf eq 'session' && $type!=1;
    log_info('User is found and password is OK');
  } else {
    # Генерируем пустую записть для пользователя, так как
    # режим генерации сессии и загрузки дефолтного юзера отключены
    generateEmptyUser();
  }
  return doLogin($type!=1);
}

sub createSessionUser {
#  log_info(104);
  my %h=(login     =>generateSessionLogin(),
	 passkey   =>generateSessionKey());

  my $a=$h{passkey};
  my $anonymous=conf('login.fields.anonymous');
  $h{$anonymous}=1 if $anonymous;
	
  my $registerdate=conf('login.fields.register');
  $h{$registerdate}='now'	if $registerdate;
  log_info('create session user',join(',',map {"$_=$h{$_}"} keys %h));
  fatal(40)
    unless user()->Create(\%h);
  dbCommit();
  return doLogin(1);
}

sub deleteSessionUser {
  my $anonymous=conf('login.fields.anonymous');
  return unless $anonymous;
  # Еще раз проверим не является ли залогиненый пользователь
  # сессионный, хотя этого не может быть.
  if (!user($anonymous)) {
    my $value=cookie()->get();
    if ($value->{login} && $value->{anonymous}) {
      #			notice(108,$value{login});
      user()->Delete({login  =>$value->{login},
		      passkey=>$value->{password},
		      $anonymous=>1})
	|| log_warn(9,$value->{login});
    }
  } else {
    log_warn(48);
  }

}

sub generateSessionLogin { 	return Apache::Session::Generate::MD5::generate(); }
sub generateSessionKey   { 	return Apache::Session::Generate::MD5::generate(); }

=pod

create table table_user (
			 user_id   integer not null,
			 name      varchar(200),
			 login     varchar(50) not null unique,
			 counter   integer default 0 not null,
			 passkey   varchar(50),
			 loginDate timestamp,
			 registerDate timestamp,
			 anonymous integer not null,

			 primary key (user_id)
			);

create generator table_user_seq;

insert into table_user values (0,'Administrator','admin',0,'supersecret','now','now',0);

=cut



1;
