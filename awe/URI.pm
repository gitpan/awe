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

# ���� ������� ������ � ������� ������� � objectsURI
# �� ���� ��� ����� �������������� ���������� ������

sub objectPath    { return awe::Context::context('uri')->{objectPath}; }
sub setObjectPath {
  my $path=shift;
  $path=~s!^/+!!;
  return awe::Context::context('uri')->{objectPath}=$path;
}

# ���, ��� �������� �� executed
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

# ������ ���� (��� ����� �������) �������� ��������
sub realHomePath { return location(); }

# ������ URL  � ��������) �������� ��������
sub realHome     { return 'http://'.awe::Context::apr()->server->server_hostname().realHomePath(); }

sub homePath { return location(); }

# ������ URL  � ��������) �������� ��������
sub home     { return 'http://'.awe::Context::apr()->server->server_hostname().homePort().homePath(); }


# ������ ���������� ����
sub realCurrentPath  { return awe::Context::apr()->uri(); }

# ������ ���������� URL: ���� + ����
sub realCurrent      { return 'http://'.awe::Context::apr()->hostname().homePort().realCurrentPath(); }

# ������������ ����. ���� ����� ��������� URI ����� (realCurrentPath -
# location). �� ���� � ������ ���� ��� �� ���������� ����������� ���
# ��������� ��������, �� �� ����� ��������� � realCurrentPath

sub realExecuted	{
  my $path     = realCurrentPath();
  my $location = location();
  $path=~s/^$location//;
  $path=~s!^/!!g;
  return $path;
}


# ���� �����, ��� � real* ������ ����� ��������� �������� ���������
# � ������ ���� ��������� ����� ��� ��� ��� �������������� �� �����
# URI, �� ��������� ��������� � real*
# ������! ������������ ������ �� real*, ���-�� ��� � home ������ base

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
