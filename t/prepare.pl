#!/usr/bin/perl
use strict;
use lib qw(..);
use awe::Db;

my @TEST=(
	  'a=b and c=b',
	  
	  {a=>'1',c=>'2'},
	  
	  ['b=1','c=2'],
	  
	  {or=>
	   {a=>'1',c=>'2'}
	  },

	  {or =>{
                 name  => 'vasya',
                 login => 'petya',
                },
           and=>[
                        "login_date >= '01/02/02'",
                        "login_date <= '01/10/02'",
                 ]
	  },
	  
	  ["login_date >= '01/02/02'",
           "login_date <= '01/10/02'",
           {or =>{
                 name  => 'vasya',
                 login => 'petya',
                }}],

	  ["login_date >= '01/02/02'",
           "login_date <= '01/10/02'",
           "(name = ? or login = ?)",
           {'-' =>['vasya','petya']}

	  ],
	  

	  
	  );


foreach (@TEST) {
  my @bind;
  print awe::Db::prepareData($_,'and',\@bind,1)."\n";
  print "Bind: ".join(',',@bind)."\n" if @bind;
  print "\n";
  
}


