package awe::Login;
use strict;
use awe::Data;
use awe::Conf;
use awe::Log;
use awe::Db;
use awe::Table;
use Apache;
use Apache::Cookie;
use vars qw(@ISA
						@EXPORT
						$COOKIES
						$USER_TABLE
					 );
@ISA = qw(Exporter);
@EXPORT = qw(&handler);

$COOKIES=undef;
$USER_TABLE=undef;

sub init {
	$USER_TABLE=awe::Table->new('user');
	$COOKIES = Apache::Cookie->fetch();
}


sub deinit {
	$USER_TABLE=undef;
	$COOKIES = undef;
}


sub checkLogin {
	my $p=param();
	return login($p,2)
		if exists $p->{login};
	my %value=getCookieValue();
	return login(\%value,1);
}

sub failed {
	my $reason=shift;
	my $hr=shift;
	notice(105,$hr->{login},$reason);
	outputSys({access=>{reason=>$reason,
										 login=>$hr->{login}}});
	return 0;
}

sub createSessionUser {
	notice(104);
	unless ($USER_TABLE->create({login=>generateLogin(),
															 registerdate=>'now',
															 passkey=>generateKey(),
															 isanon=>1})) {
		error(40);
		generateEmptyUser();
	}
	doLogin(1);
}

sub generateEmptyUser {
#	notice('generate empty user');
}

sub doLogin {
	my $cookie=shift;
	my ($loginDate,$counter)=(conf('login.loginDate'),conf('login.counter'));
	if (($loginDate || $counter) && user('user_id')) {
		my $res=1;
		my @a;
		push @a,"$counter=$counter+1" if $counter;
		push @a,{$loginDate=>'now'}   if $loginDate;
		notice(106,$USER_TABLE->modify(\@a));
		COMMIT();
	}
	my $login=user('login');
	setCookie({login    =>$login,
						 password =>user('passkey'),
						 anon     =>!user('isregistered')})
		if $cookie;
	outputSys({access=>{user=>user()}});
	notice(107,$login);
	return 1;
}

sub login {
	my ($hr,$type)=@_;
	
	$hr={login=>'',password=>''}
		unless $hr && $hr->{login};
	$type+=0;
	my @t=qw(internal cookie CGI);
	my $anon=conf('login.anonymous');
	
	return createSessionUser() if $anon==2 && !$hr->{login};
	# Если есть логин, или установлен режим загрузки безлогинового пользователя (такой должен быть в базе)
	if ($hr->{login} || $anon==1) {
		unless ($USER_TABLE->load({login=>$hr->{login}})) {
			# Если включен режим автогенерации, логирующийся пользователь
			# был автогенерирован и исользовал куки (если пользователь автогенерированный
			# то он может логироваться только так), то сгенерироватьнового,
			# иначе failed
			return $anon==2 && $hr->{anon} && $type==1
				? createSessionUser()
					: failed('nouser',$hr);
		}
		if (user('passkey') ne $hr->{password}) {
			# Тоже, что и выше. Хотя странно, почему пользователь есть, а пароль не подходит?
			return $anon==2 && $hr->{anon} && $type==1
				? createSessionUser()
					: failed('wrong',$hr);
		}
		# Если включен режим авторегистрации, залогинившийся пользователь не авторегистрированный
		# и он регистрируется не через куки, значет в куке возможно есть его старая запись
		# авторегистрированного пользователя, попытаемся его удалить
		if ($anon==2 && !user('isanon') && $type!=1) {
			my %value=getCookieValue();
			if ($value{login} && $value{anon}) {
				notice(108,$value{login});
				$USER_TABLE->delete({login  =>$value{login},
														 passkey=>$value{password},
														 isanon=>1})
					|| warning(9,$value{login});
			}
		}
	} else {
		generateEmptyUser();
	}
	return doLogin($type!=1); 
}

sub generateLogin {
	my $r=rand();
	$r=~s/\.//;
	$r=time().($r+0);
	return unpack('h*',pack('c*',unpack('x3 a2 a2 a2 a2 a2 a2 a2 a2 a2 a2',$r)));
}

sub generateKey {
	my $r=rand();
	$r=~s/\.//;
	$r+=0;
	return $r;
}

sub user {
	return $USER_TABLE->get(@_);
}

sub getCookieValue {
	my $name=getCookieName();
	return $COOKIES->{$name} ? decode($COOKIES->{$name}->value()) : undef;
}

sub getCookieName { return conf('cookie.name') || context('subsystem'); }

sub decode {
	my $str=unescape_uri(shift);
	my %h;
	foreach (split(':',$str)) {
		if (/^(.+)=(.*)$/) {
			$h{$1}=$2;
		}
	}
	return %h;
}

sub encode {
	my $str=shift;
	return escape_uri(join(':',map {"$_=$str->{$_}"} keys %$str));
}

# Устанавливать куку на клиенте

sub setCookie {
	my $value = shift;
	my $cookie = Apache::Cookie->
		new(ar(),
				-name    =>  getCookieName(),
				-value   =>  encode($value),
				-expires =>  conf('cookie.expiries') || '+3d',
				# -domain  =>  conf('cookie.domain') || undef,
				-path    =>  conf('cookie.path') || URIbaseLocation(),
				# -secure  =>  conf('cookie.secure')
			 );
	$cookie->bake();
}

1;
