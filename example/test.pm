package example::test;
use web::Db;
use strict;
use web::Object;
use web::Table;
use vars qw(@ISA);
@ISA=qw(web::Object);

sub ACTION_default {
	my $doc=$web::Templ::parser_xml->
		parse_file('/home/danil/projects/web/example/test.xml');
#	die $doc->documentElement();
	output::dataDocument()->
			setDocumentElement($doc->documentElement());
	my $table=table();
	#		log::notice('table',$table);
#	my $res=$table->delete({text1=>'abc'});
#	log::notice('res',$res);
#	my $a=table::load(1);
	return 1;
}

sub ACTION_showparams {
	my %params=map {"$_=".context::param($_)} context::param();
	my %groups;
	foreach my $group (keys %{$web::Conf::CONFIG}) {
		$groups{$group}={};
		foreach (keys %{conf::subGroup($group)}) {
			$groups{$group}->{$_}=conf::get($group,$_);
		}
	}
	setOutput({params=>\%params,
						 groups=>\%groups});
	#	error(10,'test1','test2');
	return 1;
}


1;
