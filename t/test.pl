#!/usr/bin/perl -d:DProf
#use lib qw(..);
use lib qw(/home/danil/projects/
					 /home/danil/projects/awe/);
use strict;
use awe::Context;
use awe::Fake::Controller;
use dapi::define;


handler({server_name=>'dapi',
				 subsystem=>'dapi',
				 config=>'/home/danil/projects/dapi/default.conf',
				 params=>{},
				 cookie=>{login    => '9d716a61b9a7b9bc327484a47c9d753b',
									password => 'fe94cb9565e46bd457a84b0a6f58d5e9'},
				 object=>'glern',
				 action=>'default'});
