package awe::Log;
use Exporter;
use awe::Conf;
use awe::Context;
use awe::Error;
use Error;
use Carp;
use strict;
use vars qw(@ISA
	    @EXPORT
	   );
@ISA = qw(Exporter);
@EXPORT = qw(fatal
	     log_notice
	     log_info
	     log_debug
	     log_warn
	    );

# error debug notice warning info

sub getLogObject {
  return awe::Context::apr() ? awe::Context::apr()->log() : 'awe::Log::STDERR';
}

sub fatal {
  my $error='awe::Error';
  if ($_[0]=~/^Error(::.*)?$/ || $_[0]=~/^awe::Error/) {
    $error=shift;
  }
  print STDERR "Error $error: ".join(',',@_)."\n";
  throw $error @_;
}

sub error {
  getLogObject()->error(getMessage(@_));
  return undef;
}

sub log_notice {
  getLogObject()->notice(getMessage(@_));
}

sub log_info {
  getLogObject()->info(getMessage(@_));
}

sub log_debug {
  getLogObject()->debug(getMessage(@_));
}
	
sub log_warn {
  getLogObject()->warn(getMessage(@_));
}
	


sub timemark {
  notice(@_,time());
  return 0;
}

sub getMessage {
  if ($_[0]=~/^\d+$/) {
    return awe::Conf::getMessage(shift,@_);
  } else {
    return join("\t",@_);
  }
}


package awe::Log::STDERR;
use strict;
use awe::Log;

sub notice {
  my $self=shift;
  print STDERR awe::Log::getMessage(@_)."\n";
}
	
sub error {
  my $self=shift;
  print STDERR awe::Log::getErrorMessage(@_)."\n";
}

sub debug {
  my $self=shift;
  print STDERR awe::Log::getMessage(@_)."\n";
}

sub info {
  my $self=shift;
  print STDERR awe::Log::getMessage(@_)."\n";
}

sub warn {
  my $self=shift;
  print STDERR awe::Log::getMessage(@_)."\n";
}


=pod


=cut

1;
