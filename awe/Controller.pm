package awe::Controller;
use Exporter;
use strict;
use Apache::Constants;
use awe::Data;
use awe::Conf;
use awe::Log;
use awe::View;
use vars qw(@ISA
						@EXPORT
					 );
@ISA = qw(Exporter);
@EXPORT = qw();


sub handler {
	my $r = shift;
	return DECLINED
		unless $r->is_initial_req;
	return DECLINED
		unless $r->dir_config('subsystem');
	my $inited=0;
	eval {
		return SERVER_ERROR
			unless initSubsystem($r);
		if (findObject()) {
			fatal(45)
				unless $inited=context('module')->init(1);
			context('module')->runContextAction();
			context('module')->deinit() if $inited;
			$inited=0;
		} else {
			http_code(DECLINED);
		}
		outputSys({errors=>getErrorLog()});
		awe::View::show()
				if http_code()!=DECLINED;
		deinitSubsystem();
	};
	
	if ($@) {
		context('module')->deinit()
			if $inited;
		deinitSubsystem()
			if context('subsystem');
		showError($r,$@);
		undef $@;
	}
	notice();
	return http_code();

}

sub showError {
	my $r=shift;
	$r->custom_response(SERVER_ERROR,
											awe::View_error::getPage($r,@_));
	http_code(SERVER_ERROR);
}

sub findObject {
	my $uri=URIexecuted();
	my $a=confA('main.objectsURI');
	unless (@$a) {
		setContext('object',cgi('object') || 'default');
		return 1;
	}
	my $object;
	foreach (@$a) {
		my ($u,$a,$object)=(/^([^*:]+)(\*?):(\S+)$/);
		if ($uri eq $u || $uri=~/^$u/ && $a) {
			return 0 if $object eq 'DECLINED';
			if ($object=~/^([A-Z0-9_]+)\(([A-Z0-9_]+)\)$/i) {
				$object=$1;
				setContext('action',$2);
			} elsif ($object=~/^[^A-Z0-9_]+$/i) {
				fatal(39,$object);
			}
			$uri=~s/^$u//;
			setContext('path',$uri);
			$uri=~s/(\.\.|^\/+)//g;
			setContext('subpath',$uri);
			setContext('object',$object);
			setContext('module', conf('objects',$object,'module')
								 || fatal(8,$object));

			return 1;
		}
	}
	return 0;
}

sub initSubsystem {
	my $r=shift;
	awe::Log::init($r->log());
	awe::Data::init($r);
	awe::Conf::init();
	awe::Data::register();
	awe::Conf::loadConfig();
	awe::View::init();
	awe::Db::init();
	awe::Table::init();
	awe::Login::init();
	return 1;
}

sub deinitSubsystem {
	awe::Login::deinit();
	awe::Table::deinit();
	awe::Db::deinit();
	awe::View::deinit();
	awe::Conf::deinit();
	awe::Log::deinit();
	awe::Data::deinit();
}


1;
