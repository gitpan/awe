package awe::Data;
use strict;
use Exporter;
use awe::Log;
use awe::XML;
use Cache::SharedMemoryCache;
use Cache::FileCache;

use vars qw(@ISA
						@EXPORT

						$OUTPUT_SYS
						$OUTPUT_DOM
						%OUTPUT_PARAMS
						
						$HTTP_CODE

						$VERSION
						
						%SUBSYSTEMS
						
						$APACHE_REQUEST_REC
						$APACHE_REQUEST
						
						$CONTEXT
						
						$CACHE
						
						);

@ISA = qw(Exporter);

@EXPORT = qw(
						 http_code
						 output
						 outputSys
						 outputParams

						 subsystem
						 
						 arr
						 ar
						 
						 param

						 context

						 setContext

						 URIbaseLocation
						 URIbase
						 URIhome
						 URIcurrent
						 URIreferer
						 URIexecuted
						);

%OUTPUT_PARAMS         = ();
$HTTP_CODE             = undef;
$CACHE                 = undef;

( $VERSION ) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

# Тоже, что и uri::base, но с учетом страны или каких-либо подоюным параметров

sub URIbaseLocation { return arr()->dir_config('location');}
# Возвращает базовый prot://hostname/path ниего которого не бывает и который является домом
# Впринципе это негде использоватья не должно. Веьде надо юзать url::home
sub URIhome     { return URIbase(); }
sub URIbase     { return 'http://'.ar()->server->server_hostname().URIbaseLocation(); }
sub URIcurrent  { return 'http://'.ar()->hostname().arr()->uri(); }
sub URIreferer  { return arr()->header_in('Referer');}
sub URIexecuted {
	my $s=arr()->uri();
	my $l=URIbaseLocation();
	$s=~s/^$l//;
	$s=~s!^([^/])!/$1!;
	return $s || '/';
}

sub arr { return $APACHE_REQUEST_REC;        }
sub ar  { return $APACHE_REQUEST;            }
sub param { return scalar $APACHE_REQUEST->param(@_); }

sub subsystem      { return @_ ? $SUBSYSTEMS{context('subsystem')}->{$_[0]}
											 : $SUBSYSTEMS{context('subsystem')};
									 }

sub context        { return $_[0] ? $CONTEXT->{$_[0]} : $CONTEXT; }
sub setContext     { return $CONTEXT->{$_[0]}=$_[1]; }


sub http_code        { 	return defined $_[0] ? $HTTP_CODE=shift : $HTTP_CODE; }

sub outputParams       {  return \%OUTPUT_PARAMS; }
sub outputSys { 	return @_ ? hashToDOM($OUTPUT_SYS,@_) : $OUTPUT_SYS; }
sub output { 	return @_ ? hashToDOM($OUTPUT_DOM->documentElement(),@_) : $OUTPUT_DOM; }

sub cache {
	return $CACHE;
}

sub init {
	my $r=shift;
	$APACHE_REQUEST = Apache::Request->new($APACHE_REQUEST_REC=$r);
	$CONTEXT        = {};
	setContext('subsystem',
						 $r->dir_config('subsystem') || fatal(14));

	my %cache_options = ( namespace => 'awe'); #'default_expires_in' => 600 

	$CACHE = new Cache::FileCache( \%cache_options ) ||
		fatal(46);

	return 1;
}

sub deinit {
	$OUTPUT_DOM             = undef;
	%OUTPUT_PARAMS          = ();
	$OUTPUT_SYS             = undef;

	$APACHE_REQUEST         = undef;
	$APACHE_REQUEST_REC     = undef;
	$CONTEXT                = undef;
	$CACHE                  = undef;

}

sub register {
 	unless ($SUBSYSTEMS{context('subsystem')}) {
		my $config=$APACHE_REQUEST_REC->dir_config('config') || fatal(20);
		awe::Log::notice(102);
		
		my %h;
		# name, config, modules, sysobject
		$h{config_time} = 0;
		$h{config_data} = {};
		$h{config}      = $config;
		$SUBSYSTEMS{context('subsystem')}=\%h;
		
	}
	fatal(7,context('subsystem'))
		unless $SUBSYSTEMS{context('subsystem')}->{config};

	
	($OUTPUT_DOM,$OUTPUT_SYS)=awe::XML::initOutput();
	
	%OUTPUT_PARAMS          = ();# Незыбывай, что сюда передаются не чисто текст, а XPath
	outputSys({uri=>{home  =>URIhome(),
									 current=> URIcurrent(),
									 base  =>URIbase()},
						 params=>param()});

}

1;
