package awe::Fake::Controller;
use Exporter;
use strict;
use Apache::Constants;
use awe::Context;
use awe::Conf;
use awe::Log;
use awe::Controller;
use awe::Fake::Request;
use Error qw(:try);
#use Devel::DProf;

use vars qw($VERSION @EXPORT @ISA);

@ISA    =qw(Exporter);

@EXPORT=qw(handler);

#( $VERSION ) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

# $Id: AuthCookieURL.pm,v 1.3 2000/11/21 00:46:01 lii Exp $
$VERSION = sprintf '%d.%03d', q$Revision: 1.3 $ =~ /: (\d+)\.(\d+)/;



sub handler {
	my $hr = shift;
	my $r = awe::Fake::Request->new(get_remote_host=>$hr->{server_name},
																	server_hostname=>$hr->{server_name},
																	dir_config=>{subsystem=>$hr->{subsystem},
																							 config=>$hr->{config},
																							 location=>$hr->{location},
																							},
																	cookie=>$hr->{cookie},
																	params=>$hr->{params},
																	is_initial_req=>1);
	
	#	print STDERR "Start handler: $r ref=".ref($r)."\n";
	my $res=try {
		awe::Context::register($r);
		return DECLINED
			unless findModule($hr);
		return awe::View::show(awe::Controller::runModule());
	} catch Error with {
		my $e=shift;
		print STDERR "CATCH: $e\n";
		showError($r,$e->stringify);
	} otherwise {
		print STDERR "otherwise\n";
		showError($r,"UNKNOWN ERROR: $@");
	};
	return $res;
}

sub showError {
	my ($r,$text)=@_;
	#	$r->custom_response(SERVER_ERROR,
	#											awe::View_error::getPage($text));
	print STDERR "Server Error".awe::View_error::getPage($text);
	return SERVER_ERROR;
}

sub findModule {
	my $hr=shift;
	setContext('action',$hr->{action});
	setContext('object',$hr->{object});
	setContext('module', conf('objects',$hr->{object},'module')
						 || fatal(8,$hr->{object}));
}

1;
