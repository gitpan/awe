package awe::Controller;
use Exporter;
use strict;
use Apache::Constants;
use awe::Context;
use awe::URI;
use awe::Conf;
use awe::Log;
use awe::View;
use Error qw(:try);
#use Devel::DProf;

use vars qw($VERSION);

( $VERSION ) = '$Revision: 0.2 $ ' =~ /\$Revision:\s+([^\s]+)/;



sub handler {
  my $r = shift;
  return DECLINED
    unless $r->is_initial_req;
  return DECLINED
    unless $r->dir_config('subsystem');
  return try {
    awe::Context::register(ref($r)=~/Request/ ? $r : Apache::Request->new($r));
    return DECLINED
      unless findModule();
    return awe::View::show(runModule());
  } catch Error with {
    showError($r,shift->stringify);
  } otherwise {
    showError($r,"UNKNOWN ERROR: $@");
  };
}

sub runModule {
  my $object;
  fatal(45)
    unless setContext('object_inst',
		      $object=context('module')->instance());
  return try {
    my $result = $object->runContextAction();
    my $data   = $object->data();
    return (context('template'),$result,$data);
    # Если расскоментарить, то не ловится отсутсвие куки для Fake, то есть языковые ошибки
    #	} catch Error with {
    #		my $e=shift;
    #		print STDERR "CATCH rm: $e\n";
    #		#		$e->throw($e);
    #		Error::throw $e;
  } otherwise {
    my $e=shift;
    throw Error::Simple $e;
  } finally {
    $object->deinit();
  };
}

sub showError {
  my ($r,$text)=@_;
  $r->custom_response(SERVER_ERROR,
		      awe::View_error::getPage($text));
  return SERVER_ERROR;
}

sub findModule {
  my $uri = uri()->executed();
  #	print STDERR uri()->current()."\n";
  my $a = confA('main.objectsURI');
  my $object;
  foreach (@$a) {
    fatal(53,'objectsURI',$_) unless /^([^*:]*)(\*?):(\S+)$/;
    my ($u,$a,$object)=($1,$2,$3);
    $u='' if $u eq '/';
    if ($uri eq $u || ($a && $uri=~/^$u/i)) {
      return 0 if $object eq 'DECLINE';
      if ($object=~/^([A-Z0-9_:]+)\(([A-Z0-9_*]*)\)$/i) {
	$object=$1;
	my $action = $2;
	if ($action eq '*') {
	  $action=$uri;
	  $action=~s/^$u//i;
	}
	$action=~s/[^a-z_0-9]//gi;
	
	setContext('action',$action);
      } elsif ($object=~/^[^A-Z0-9_]+$/i) {
	fatal(39,$object);
      }
      awe::URI::setObjectPath($u);
      $uri=~s/^$u//;
      awe::URI::setActionPath($uri);
      
      setContext('object',$object);
      setContext('module', conf('objects',$object,'module')
		 || fatal(8,$object));
      return 1;
    }
  }
  return 0;
}

1;
