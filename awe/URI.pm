package awe::URI;
use strict;
use awe::Context;
use Socket;
use Apache::URI;


sub all {

  return {referer      => referer(),
	  location     => location(),

	  home            => home(),
	  homePath        => homePath(),
					
	  current         => realCurrent(),
	  currentPath     => realCurrentPath(),

	  executed        => realExecuted(),

	  real => {
		   home            => realHome(),
		   homePath        => realHomePath(),
									 
		   current         => realCurrent(),
		   currentPath     => realCurrentPath(),
									 
		   executed        => realExecuted(),
									 
		  }

	 };
}

# Путь который совпал с поиском объекта в objectsURI
# то есть это тпуть идентифицирует вызываемый объект

sub objectPath    { return awe::Context::context('uri')->{objectPath}; }
sub setObjectPath {
  my $path=shift;
  $path=~s!^/+!!;
  return awe::Context::context('uri')->{objectPath}=$path;
}

# Все, что осталось от executed
sub actionPath    { return awe::Context::context('uri')->{actionPath}; }
sub setActionPath {
  my $path=shift;
  $path=~s!^/+!!;
  return awe::Context::context('uri')->{actionPath}=$path;
}

sub referer  { return awe::Context::apr()->header_in('Referer');}

sub location {
  my $location=awe::Context::apr()->dir_config('location');
  $location.='/' unless ~m/\/$/;
  return $location;
}

sub homePort {
  my ($port,$iaddr)=sockaddr_in(awe::Context::apr()->connection()->local_addr());
  return $port == 80 ? '' : ":$port";
}

# Полный путь (без имени сервера) домашней страницы
sub realHomePath { return location(); }

# Полный URL  с сервером) домашней страницы
sub realHome     { return 'http://'.awe::Context::apr()->server->server_hostname().realHomePath(); }

sub homePath { return location(); }

# Полный URL  с сервером) домашней страницы
sub home     { return 'http://'.awe::Context::apr()->server->server_hostname().homePort().homePath(); }


# полный вызыванный путь
sub realCurrentPath  { return awe::Context::apr()->uri(); }

# полный вызыванный URL: хост + путь
sub realCurrent      { return 'http://'.awe::Context::apr()->hostname().homePort().realCurrentPath(); }

# используемый путь. Путь после отсечения URI сайта (realCurrentPath -
# location). То есть в случае если сат не исопльзует подготалоги для
# начальной страницы, то он будет совпадать с realCurrentPath

sub realExecuted	{
  my $path     = realCurrentPath();
  my $location = location();
  $path=~s/^$location//;
  $path=~s!^/!!g;
  return $path;
}


# тоже самое, что и real* только после отсечения языковой иформации
# в случае если поддержки языка нет или она осуществляется не через
# URI, то полностью совпадает с real*
# Везьде! Используется именно НЕ real*, так-же как и home вместо base

sub currentPath    { return awe::Context::context('uri')->{currentPath}; }
sub current        { return awe::Context::context('uri')->{current};     }
sub executed       { return awe::Context::context('uri')->{executed};    }

sub setExecuted {
  my $path=shift;
  my $location = location();
  awe::Context::context('uri')->{executed}   =$path;
  awe::Context::context('uri')->{currentPath}=$location.$path;
  awe::Context::context('uri')->{current}    ='http://'.awe::Context::apr()->hostname().homePort().$location.$path;
}



1;
