package awe::View;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);
use Exporter;
use Apache;
use strict;
use awe::Log;
use awe::Conf;
use awe::Data;

#use CGI qw(:html);
use vars qw(@ISA
						@EXPORT
						$TEMPLATE

					 );

@ISA = qw(Exporter);

@EXPORT = qw(
						 template
						);

$TEMPLATE=undef;

sub init {}
sub deinit {}


sub template {
	my $name = shift;
	return $TEMPLATE=undef unless $name;
	$name=context('object').".$name";
	my ($templ,$dir)  = ( conf('templates',$name),
												conf('templates.dir'));
	my $global_style=conf('templates.*');
	unless ($templ) {
		$templ=conf("templates.$name:noglobal");
		$global_style=0;
	}
	fatal(11,$name) unless $templ;
	my $type=$templ=~s/^([A-Z0-9_]+):\s*//i
		? $1
			: conf('templates.type');
	fatal(44) unless $type;
	unless ($type eq 'redirect') {
		my @templ;
		foreach (split(/\s+/,$templ)) {
			push @templ,$dir.$_;
		}
		push @templ,$dir.$global_style
			if $global_style;
		$templ=@templ ? \@templ : undef;
	}
	return $TEMPLATE={type    => $type,
										name    => $name,
										method  => "awe::View_$type"->can('show') || fatal(12,$type),
										templ   => $templ || fatal(18,$name)};

}

sub show {
	my $r=arr();
	# При неустановленном темплейте просто ненадо ничего показывать
	# при условии конечно что результат не OK
	unless ($TEMPLATE) {
		fatal(18) if http_code()==OK;
		return;
	}
	return &{$TEMPLATE->{method}}($TEMPLATE,
																arr(),
																output(),
																outputParams());
}


#sub urlenc
#  {
#    my $self=shift;
#    my $s = shift;
#    $s =~ s/([^\ a-zA-Z0-9\.\*_-])/sprintf "%%%02X", ord $1/eg;
#    $s =~ tr/ /+/;
#    return $s;
#  }



##########################################################
# Show templates methods
##########################################################

package awe::View_error;
use awe::XML;
use awe::Data;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);


## Внимание! Во время вызова этой процедуры все deinit-ено

sub getPage {
	my $r=shift;
	my $error=shift;
	return "<html><h1>Fatal Error</h1><h2>$error</h2></html>";
}

sub show {
	my ($template,$r,$error)=@_;
	
	$r->content_type('text/html');
	$r->send_http_header;
	return 1 if
		my $original_request = $r->prev;
	
	return 1
		if $r->header_only;
	$r->print(getPage($r,$error));
	return http_code(OK);
}


package awe::View_xslt;
use awe::XML;
use awe::Log;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);

sub show {
	my ($template,$r,$data,$params)=@_;
	if (my $original_request=$r->prev || $r->header_only) {
		$r->content_type('text/html');
		$r->send_http_header;
		return 1;
	}
	
	my $stylesheet;
#	notice('input',$data->toString(),"\n\n");
	foreach (@{$template->{templ}}) {
		$stylesheet=xsltFile($_);
		$data=$stylesheet->transform($data,%$params);
#		notice("output ($_)",$data->toString(),"\n\n");
	}
	my $text=$stylesheet->output_string($data);
	$r->content_type($stylesheet->media_type());
	$r->send_http_header;
	$r->print($text);
}


package awe::View_redirect;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);

sub show {
	my ($template,$r)=@_;
	http_code(REDIRECT);
	my $url=$template->{templ};
	foreach (split('\|',$url)) {
		$_=URIhome().$_
			if /^\?/ || /^[^\/:]+\//;
		if ($_) {
			s/\&/\?/
				if !/\?/;
			if (URIcurrent() eq $_) {
				warning(25);
				$_=URIhome();
			}
			$r->header_out(Location => $url || fatal(24));
		}
	}
	while ($url =~ /([=?]?)\$([a-zA-Z0-9_]+)/) {
		my $encode=$1;
		my $name=$2;
		my $value;
		my $check_lp=0;
		if ($name eq 'referer') {
			$check_lp=1;
			$value=URIreferer();
		} elsif ($name eq 'current') {
			$check_lp=1;
			$value=URIcurrent();
		} elsif ($name eq 'home') {	
			$value=URIhome();
		} elsif ($name eq 'base') {	
			$value=URIbase();
		}
		die 1;
		#URI::Escape::uri_escape - кодирует все
		$value=encode_uri($value) # кодирует не все, например оставляет &, кажется
			if $encode;
		if ($check_lp) {
			$value=~s/[\&|\?]login=([^&]*)//;
			$value=~s/[\&|\?]password=([^&]*)//;
		}
		$url =~ s/\$$name/$value/e;
			
	}
	$r->header_out(Location => $url || fatal(24));
}

1;


