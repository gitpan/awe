package awe::Cookie;
use strict;
use awe::Context;
use awe::Log;
use awe::Conf;
use Apache::Util;
use Apache::Cookie;

sub new {
  my $class=shift;
  return bless {name => conf('cookie.name') || context('subsystem')}, $class;
}

sub get {
  my $self=shift;
  my $name = shift || $self->{name};
  $self->{cookies} = Apache::Cookie->fetch() || {}
    unless $self->{cookies};
  
  return $self->{cookies}->{$name} ? decode($self->{cookies}->{$name}->value()) : undef;
}


# Устанавливать куку на клиенте

sub set {
  my $self=shift;
  my $hr = shift;
  my $path = conf('login.cookie.path') || uri()->location();
  my $domain = conf('cookie.domain');
	
  $domain=apr()->server->server_hostname()
    unless $domain;
  # Домайн не устанавливается, потому что
  # у меня он не работает - имя хоста короткое
  # Но если ставить надо, так-как иначе кука автоматом
  # савит имя домейна с номером порта
  #	notice("Cookie domain: $domain, path: $path");
  my %ch=(
	  -name    =>  $self->{name},
	  -value   =>  encode($hr),
	  -expires =>  conf('login.cookie.expiries') || '+3d',
	  #					-domain  =>  $domain,
	  -path    =>  $path,
	  # -secure  =>  conf('cookie.secure')
	 );

  Apache::Cookie->new(apr(),%ch)->bake();
}

sub decode {
  my $str=Apache::Util::unescape_uri(shift);
  my %h;
  foreach (split(':',$str)) {
    if (/^(.+)=(.*)$/) {
      $h{$1}=$2;
    }
  }
  return \%h;
}

sub encode {
  my $str=shift;
  return Apache::Util::escape_uri(join(':',map {"$_=$str->{$_}"} keys %$str));
}



#sub realize_session {
#    my ($foo) = @_;
#    my ($i, $s);
#    
#    $i = thaw(uncompress(decode_base64($foo)));
#    
#    if (sha1_hex($i->{content} . BIG_SECRET) eq $i->{hash}) {
#        $s = thaw($i->{content});
#        return $s;
#    }
#    
#    return undef;
#}
#
#sub serialize_session {
#    my ($s) = @_;
#    my ($i, $frz, $foo);
#    
#    $frz = nfreeze($s);
#    
#    $i = {
#        content => $frz
#      , hash    => sha1_hex($frz . BIG_SECRET)
#    };
#
#    $foo = encode_base64(compress(nfreeze($i)));
#
#    return $foo;
#}

1;
