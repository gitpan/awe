package awe::Context;
use strict;
use Exporter;
use awe::Log;
use awe::Cookie;
use awe::Fake::Cookie;
use awe::URI;
#use IPC::Shareable;
use base qw(Exporter);

use vars qw(
	    @EXPORT
	    @ISA
	    %SHARED
	    $APACHE_REQUEST
	   );

@ISA    = qw(Exporter);

@EXPORT = qw(
	     http_code

	     template
						 
	     getSubsystem
	     subsystem
	     setSubsystem

	     apr

	     cookie

	     uri
						 
	     param

	     context

	     setContext
	    );

sub uri { return "awe::URI"; }
#sub arr { return $APACHE_REQUEST_REC;        }
sub apr  { return $APACHE_REQUEST;            }

sub param { return scalar $APACHE_REQUEST->param(@_); }

sub setSubsystem {
  my ($key,$value)=@_;
  #	return apr()->pnotes('SHARED')->{$key}=$value;
  return $SHARED{$key}=$value;
}

sub getSubsystem {
  my ($key)=shift;
  #	return apr()->pnotes('SHARED')->{$key};
  return $SHARED{$key};
}

sub subsystem {
  my ($key)=shift;
  #	return apr()->pnotes('SHARED')->{$key};
  return $SHARED{$key};
}

sub context        {
  my $key = shift;
  awe::Log::fatal(47) if @_;
  my $context = apr()->pnotes('context');
  awe::Log::fatal(46) unless $context;
  return defined $key ? $context->{$key} : $context;
}

sub cookie {	return apr->pnotes('context')->{cookie}; } # Just shortcut


sub setContext     {
  my ($key,$value)=@_;
  my $context = apr()->pnotes('context');
  awe::Log::fatal(46) unless $context;
  return $context->{$key}=$value;
}

sub http_code {
  my ($code)=@_;
  if ($code) {
    apr()->pnotes('http_code',$code);
  } else {
    $code=apr()->pnotes('http_code');
  }
  return $code
}

sub addToHash {
  my ($root,$hr)=@_;
  #die 'error' unless ref($hr)=~/HASH/ || ($hr=~/HASH/ && ref($hr));
  foreach (keys %$hr) {
    $root->{$_}=$hr->{$_};
  }
}

sub template {
  my $name = shift;
  return setContext('template')
    unless $name;
  return setContext('template',$name) if ref($name)=~/HASH/;
	
  my $config = {template =>
		awe::Conf::conf('templates',context('object'),$name)
		|| awe::Log::fatal(54,$name)};
	
  if ($config->{template}) {
    $config->{type}=$config->{template}=~s/^([A-Z0-9_]+):\s*//i
      ? $1
	: awe::Conf::conf('templateType.default.type');
  } else {
    my $config = awe::Conf::confGroup('templates',context('object'),$name);
    $config->{type}=awe::Conf::conf('templateType.default.type')
      unless $config->{type};
  }
  return setContext('template',$config);
}


sub checkLanguage {
  my $langList = awe::Conf::confA('language.list');
  my $langGet  = awe::Conf::confA('language.get');
  my $path=uri()->executed();
  my $lang=awe::Conf::conf('language.default');
  if (@$langList && @$langGet) {
    foreach (@$langGet) {
      if (/^uri$/) {
	foreach (@$langList) {
	  if ($path=~s!/$_/!/!) {
	    $lang=$_;
	    awe::URI::setExecuted($path);
	    last;
	  }
	}
      } elsif (/^param(\((.*)\))?$/) {
	my $param=param($2 || 'lang');
	$lang=$param if grep(/$param/,@$langList);
      } else {
	warning(52,$_);
      }
    }
  }
  setContext('language',$lang);
  #	notice("Language: $lang");
}

sub register {
  #	print STDERR "register:".shift;
  $APACHE_REQUEST=shift;
  my $subsystem=$APACHE_REQUEST->dir_config('subsystem') || awe::Log::fatal(14);
  #	makeShared();
  unless ($SHARED{config_file}) {
    #		log_notice(102,$subsystem,$APACHE_REQUEST->dir_config('config'));
    %SHARED=
      (config_time =>0,
       config_file => $APACHE_REQUEST->dir_config('config') || awe::Log::fatal(20));
  }

  awe::Log::fatal(7,$subsystem)
      unless subsystem('config_file');
  apr()->pnotes('context',{
			   params    => param(),
			   subsystem => $subsystem,
			  });
  awe::Conf::loadConfig();
	
  # Установить после конфига
  setContext('uri',awe::URI::all());
	
  setContext('cookie',apr()=~/Fake/ ? awe::Fake::Cookie->new() : awe::Cookie->new());
	
  checkLanguage();
	
  return 1;
}

#sub makeShared {
#	my %SHARED;
#	tie %SHARED,
#		'IPC::Shareable',
#			"awe_$subsystem",
#				{create    => 'yes',
#				 exclusive => 0,
#				 mode      => 0644,
#				 destroy   => 'yes'}
#					if awe::Conf::conf('subsystem','shared');
#	apr()->pnotes('SHARED',\%SHARED);
#}

1;
