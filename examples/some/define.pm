package example::define;
use web::Data;
use web::Main;
use Exporter;
#use web::Conf;
use strict;
use vars qw(@ISA @EXPORTER);
@ISA=qw(Exporter web::Main);


# Examples external (non web:: web-modules)
use example::test;


sub register {
	my ($subsystem,$config)=@_;
	return web::Data::register($subsystem,
														 {modules   =>{default => 'example::test',
																					 test    => 'example::test'},
															config    =>$config});
}



1;
