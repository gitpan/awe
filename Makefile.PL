require 5.004;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

ExtUtils::Manifest::mkmanifest;
my $VERSION=0.5;

my $CONFIG_DIR='/usr/local/etc';

unlink 'MANIFEST.bak' if -f 'MANIFEST.bak';
unlink 'Makefile.old' if -f 'Makefile.old';

sub MY::libscan
	{
		my($self,$path) = @_;

		return '' 
			if ($path =~ m:/(RCS|CVS|SCCS)/: ||
					$path =~ m:[~%.]$: ||
					$path =~ m:\.(orig|rej|nfs)$:
				 );
		
		$path;
	}

#sub MY::post_initialize	{"";	}


WriteMakefile(
							NAME	       => 'awe',
							VERSION      => $VERSION,
							AUTHOR       => 'Danil Pismenny <dapi@mail.ru>',
							ABSTRACT     => 'Advanced Web Engine',
							PMLIBDIRS    => [ 'lib', '$(BASEEXT)', 'awe' ],
							PREREQ_PM    => { 'CGI'           => 2.752,
																'Date::Manip'   => 5.40,
																'Apache'        => 1.27,
																'Class::Fields' => 0.14,
																'XML::LibXML'   => 1.31,
																'XML::LibXSLT'  => 1.31,
																'DBI'           => 1.20,
																'URI'           => 1.12,
																'IPC::ShareLite'=> 0.08,
															},
							
							dist => {COMPRESS=>'bzip2', SUFFIX=>'bz2'},
							clean => {FILES=>'*.bz2*'}
						 );
