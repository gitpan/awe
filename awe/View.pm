package awe::View;
use strict;
use awe::Context;
use awe::Conf;
use awe::Log;
use Apache::Constants;

sub show {
  my $template=shift;
  # При неустановленном темплейте просто ненадо ничего показывать
  # при условии конечно что результат не OK
  unless ($template) {
    fatal(18) if http_code()==OK;
    return http_code();
  }
  my $method  = "awe::View_$template->{type}"->can('show')
    || awe::Log::fatal(12,$template->{type});
	
  return &$method(apr(),$template,@_);
}


sub getTemplateDir {
  my $template=shift;
  return $template->{dir}
    || conf("templateType.$template->{type}.dir")
      || conf('templateType.default.dir');
}



##########################################################
# Show templates methods
##########################################################


package awe::View_error;
use awe::Context;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);


## Внимание! Во время вызова этой процедуры все deinit-ено

sub getPage {
  my $error=shift;
  my $str="<html><h1>Fatal Error</h1><code>$error</code></html>";
  $str=~s/\n/<br>/g;
  return $str;
}

sub show {
  my ($r,$template,$error)=@_;
	
  $r->content_type('text/html');
  $r->send_http_header;
  return 1 if
    my $original_request = $r->prev;
	
  return 1
    if $r->header_only;
  $r->print(getPage($error));
  return SERVER_ERROR;
}



################################################################################

package awe::View_tt2;
use strict;
use Template;
use awe::Conf;
use awe::Log;
use awe::Context;
use awe::View;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);

sub show {
  my ($r,$template,$result,$data)=@_;

  $r->content_type('text/html');
  $r->send_http_header;
  unless ($r->prev || $r->header_only) {
    my $dir = awe::View::getTemplateDir($template);
    my $objectsDir = conf('templates.'.context('object').'.DIR');
    if ($objectsDir) {
      $objectsDir="$dir$objectsDir" if $objectsDir=~m!^[^/]!;
      $template->{template}=$objectsDir.$template->{template};
      $dir="$objectsDir:$dir";
    }
    my $tt = Template->
      new({
	   OUTPUT      => $r,
	   COMPILE_DIR => '/tmp/ttc',
	   COMPILE_EXT => '.ttc',
	   INTERPOLATE => 1,	# Позволяет использовать $vasya вместо [% vasya %]
	   POST_CHOMP  => 1,
	   PRE_CHOMP   => 1,
	   INCLUDE_PATH=> $dir,
	   ABSOLUTE    => 1,
	   TRIM        => 1,	# Удаляет CR/LF
	   #					 AUTO_RESET  => 1, #?
	  }) || fatal(49,Template->error());

    $tt->process($template->{template},
		 {context => context(),
		  result  => $result,
		  data    => $data})
      || fatal(49,$tt->error());
		
  }
		
  return http_code();
	
}

################################################################################

package awe::View_fd;
use strict;

sub show {
  my ($r,$template,$data)=@_;

  #	$r->content_type($stylesheet->media_type());
  $r->send_http_header;
  $r->send_fd($data)
    unless $r->prev || $r->header_only;
  return http_code();
}


################################################################################

package awe::View_file;
use strict;
use awe::Context;
use Apache::Constants;
use Apache::Constants qw(:response :methods :http);
use Apache::File ();
use Apache::Log ();

sub show {
  my ($r,$template,$result,$data)=@_;

  $result={file=>$result} unless ref($result);

  #	my $ct=$result->{ct} || 'application/octet-stream';

  #	if ($r->prev || $r->header_only) {
  #		$r->content_type($ct);
  #		$r->send_http_header;
  #		return;
  #	}
  #	my $fh = Apache::gensym();
  #	open($fh, $result->{file} || $r->filename()) || return http_code(NOT_FOUND);
  #	$r->content_type($ct);
  #	$r->send_http_header;
  #	$r->send_fd($fh);
  #	close($fh);

  if ((my $rc=$r->discard_request_body)!=OK) {
    return http_code($rc);
  }
	
  if ($r->method_number==M_INVALID) {
    $r->log->error("Invalid method in request",$r->the_request);
    return http_code(NOT_IMPLEMENTED);
  }
	
  if ($r->method_number==M_OPTIONS) {
    return http_code(DECLINED);	#http_core.c:default_handler()willpickthisup
  }
	
  if ($r->method_number==M_PUT) {
    return http_code(HTTP_METHOD_NOT_ALLOWED);
  }
	
  $r->filename($result->{file}) if $result->{file};
	
  unless(-e $r->finfo){
    $r->log->error("File does not exist:",$r->filename);
    return http_code(NOT_FOUND);
  }
  $r->content_type($r->lookup_file($r->filename)->content_type);
  if ($r->method_number!=M_GET) {
    return http_code(HTTP_METHOD_NOT_ALLOWED);
  }
	
  my $fh=Apache::File->new($r->filename);
  unless($fh){
    $r->log->error("file permissions deny server access:",
		   $r->filename);
    return http_code(FORBIDDEN);
  }
  unless ($result->{nomtime}) {
    $r->update_mtime(-s $r->finfo);
    $r->set_last_modified;
    $r->set_etag;
		
    if ((my $rc = $r->meets_conditions )!=OK) {
      return http_code($rc);
    }
  }
	
  $r->set_content_length;
  $r->send_http_header;
	
  unless($r->header_only){
    $r->send_fd($fh);
  }
  close $fh;
  return http_code();	
}



#####################################################################

package awe::View_redirect;
use strict;
use awe::Context;
use awe::Log;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);

sub show {
  my($r,$template)=@_;

  my $url=$template->{template}||fatal(24);
  my $orig=$url;
  foreach (split('\|',$url)) {
    $_=uri()->home().$_
      if /^\?/||/^[^\/:]+\//;
    if ($_) {
      s/\&/\?/
	if !/\?/;
      if (uri()->current() eq $_) {
	warning(25);
	$_=uri()->home();
      }
      $r->header_out(Location=>$url||fatal(24));
    }
  }

  $url=~s/([=?]?)\$\{([a-zA-Z0-9_:]+)\}/_parseParam($1,$2)/ge;

  fatal(24,$orig)
    unless $url;
  $r->header_out(Location=>$url);
  return REDIRECT;
}

sub _parseParam {
  my ($encode,$name)=@_;
  my $value;
  my $check_lp=0;

  if ($name eq 'referer') {
    $check_lp=1;
    $value=uri()->referer();
  } elsif ($name eq 'current') {
    $check_lp=1;
    $value=uri()->current();
  } elsif ($name eq 'home') {	
    $value=uri()->home();
  } elsif ($name eq 'base') {	
    $value=uri()->base();
  } elsif ($name=~/^param:(.+)$/){
    $value=param($1);
  }
  #URI::Escape::uri_escape-кодируетвсе
  $value=encode_uri($value)	#кодируетневсе,напримероставляет&,кажется
    if $encode;
  if ($check_lp) {
    #	die'checkloginandpasswordparameters';
    #	$value=~s/[\&|\?]login=([^&]*)//;
    #	$value=~s/[\&|\?]password=([^&]*)//;
  }
  return $value;
}

1;



#suburlenc
#{
#my$self=shift;
#my$s=shift;
#$s=~s/([^\a-zA-Z0-9\.\*_-])/sprintf"%%%02X",ord$1/eg;
#$s=~tr//+/;
#return$s;
#}
