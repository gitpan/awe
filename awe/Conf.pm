package awe::Conf;
use Apache::Request;
use Exporter;
use awe::Log;
use awe::Data;
use strict;
use vars qw(@ISA
						@EXPORT
						$CONFIG
						%DEFAULT_CONFIG
						$FORCE_RELOAD_CONFIG
						$DEFAULT_CONFIG_FILE
						$DEFAULT_CONFIG_MTIME
					 );

@ISA = qw(Exporter);

@EXPORT = qw(
						 conf
						 confGroup
						 confGroupFull
						 confH
						 confA
						 );

%DEFAULT_CONFIG=(debug    => {sql =>1},
								 db       => {fieldsName=>'low'},
								 templates=> {type   =>'xslt'},
								 xml      => {encode =>'koi8-r'},
								 reload   => {config =>1,
															html   =>1,
															xml    =>1,
															xslt   =>1},
								 messages   => {
																#	Fatal errors
																1  => 'Passed parameter is not hash',
																2  => 'Error loading config file with name $1',
																3  => 'Config file is not exists or has permissions to read',
																4  => 'Error loading config file $2 for subsystem $1',
																5  => 'Error open config file $2 for sybsystem $1',
																6  => 'Error parsing hash parameter',
																7  => 'This subsystem ($1) is not defined',
																8  => 'No such object $1',
																9  => 'No such action "$1" in this object $2',
																10 => '!!! Unknown error executing action $1 in object $2',
																11 => 'Template whith name "$1" is not found',
																12 => 'No methods to show template type $1',
																13 => 'Can not connect to database',
																14 => 'Subsystem name is not defined',
																15 => 'Table for this $1 object is not found',
																16 => 'Error init table $1',
																17 => 'Error table($1)->$2',
																18 => 'Template is not defined',
																19 => 'Template file is not exists "$1"',
																20 => 'Config file is not defined',
																21 => 'Subsystem definer is not defined',
																22 => 'bad config param "$1" (line: $2)',
																23 => 'Can`t parse xml $1',
																24 => 'No url to redirect',
																25 => 'Redirect to current url failed, redirect to home url',
																26 => 'Can`t connect to database',
																27 => 'Unknown db.fieldsName parameters value',
																28 => 'Error SQL $1 for query ($2)',
																29 => 'Call table()->fetch() until STH is not defined',
																30 => 'Error call db::select',
																31 => 'Call table->load without parameter',
																32 => 'No WHERE and no preselected row for update. table->update',
																33 => 'No action specified',
																34 => 'No data to update or insert. $1',
																35 => 'Error table "$1" attribute "$2" definition',
																36 => 'WARNING! You want to $1 whole table',
																37 => 'Can`t parse xslt $1',
																38 => 'Element &lt;text&gt; is not found for text/plain output',
																39 => 'Object name error',
																40 => "WARNING! Can't create session user",
																41 => 'XML document ($1) is not found',
																42 => 'XSLT stylesheet ($1) is not found',
																43 => 'HTML document ($1) is not found',
																44 => 'Template type is not defined',
																45 => 'Error initializing module ($module)',
																46 => "Couldn't instantiate SharedMemoryCache",
																


																# Notice and debug messages
																101 => 'Loading config file $1',
																102 => 'Register subsystem $subsystem:$process',
																103 => '$subsystem: $object->$action($path)',
																104 => 'register session user',
																105 => 'Login "$1" failed, reason is $2',
																106 => 'Update result is ',
																107 => 'Login "$1"',
																108 => 'delete session user',
																109 => 'can`t delete session user',
																110=> 'Reload "$1"',
																111=> 'Load XML file "$1"',
																112=> 'Load HTML file "$1"',
																113=> 'Load XSLT file "$1"',
																114=> 'No authorization',
														
													 },
								);

$CONFIG={%DEFAULT_CONFIG};
$DEFAULT_CONFIG_MTIME=undef;

$DEFAULT_CONFIG_FILE=undef;

sub conf {
	my ($group,$key)=join('.',@_)=~/^(\S+)\.(\S+)$/;
	awe::Log::fatal('config is not defined',@_) unless $CONFIG;
	return $CONFIG->{$group}->{$key};
}

sub confA {
	return [split(/\s+/,conf(@_))];
}

sub confH {
	my $value=conf(@_);
	my %hash;
	while ($value=~s/^([^: \t]+)\s*(\:\s*(\"([^\"]*)\"|(\S*)))?\s*//) {
		$hash{$1}=$4 || $5;
	}
	awe::Log::fatal(6,"'$value'")
			if $value;
	return \%hash;
}


sub confGroupFull {
	my $group=shift;
	my %g=%{$CONFIG->{$group} || {}};
	foreach my $sg (grep(/^$group\..+/,keys %$CONFIG)) {
		my $k=$CONFIG->{$sg};
		my $ng=$sg;
		$ng=~s/^$group\.//;
		foreach (keys %$k) {
			$g{"$ng.$_"}=$CONFIG->{$sg}->{$_};
		}
	}
	
	return \%g;
}


sub confGroup {
	my $group=join('.',@_);
	return $CONFIG->{$group};
}

sub confSet {
	my ($group,$key,$value)=@_;
	$CONFIG->{$group}={}
		unless $CONFIG->{$group};
	#debug('set conf',$group,$key,$value);
	if ($key=~s/\+$//) {
		$CONFIG->{$group}->{$key}.=" $value";
	} else {
		$CONFIG->{$group}->{$key}=$value;
	}
}

sub loadConfig {
	my $force=shift || $FORCE_RELOAD_CONFIG;
	my $subsystem=awe::Data::subsystem();
	my $file=$subsystem->{config};
	if (conf('reload.config')
			|| $force
			|| !$subsystem->{config_data}
			|| !$subsystem->{config_time}
		 ) {
		awe::Log::fatal(3,$file)
				unless -f $file;
		my $mtime=(stat($file))[9];
		if ($force || $mtime!=$subsystem->{config_time}) {
			awe::Log::fatal(4,
								 $CONFIG,
								 $file)
					unless loadFile($file);
			$subsystem->{config_time}=$mtime;
			$subsystem->{config_data}=$CONFIG;
			$subsystem->{_reload}=1;
		}
	}
	$CONFIG=$subsystem->{config_data};
	return 1;
}

sub init {
	my $force=shift;
	$FORCE_RELOAD_CONFIG=0;
	$CONFIG={};

	
	if ((conf('reload.config')
			 || $force
			 || !%DEFAULT_CONFIG)
			&& $DEFAULT_CONFIG_FILE) {
		die 'fatal error';
		awe::Log::fatal(3,$DEFAULT_CONFIG_FILE)
				unless -f $DEFAULT_CONFIG_FILE ;
		my $mtime=(stat($DEFAULT_CONFIG_FILE))[9];
		if ($force
				|| $mtime!=$DEFAULT_CONFIG_MTIME
				|| !%DEFAULT_CONFIG) {
			%DEFAULT_CONFIG=();
			
			awe::Log::fatal(4,$DEFAULT_CONFIG_FILE)
					unless loadFile($DEFAULT_CONFIG_FILE);
			$DEFAULT_CONFIG_MTIME=$mtime;
			%DEFAULT_CONFIG=%$CONFIG;
			$FORCE_RELOAD_CONFIG=1;
		} else {
			$CONFIG={%DEFAULT_CONFIG};		
		}
	} else {
		$CONFIG={%DEFAULT_CONFIG};		
	}
}

sub deinit {
	$CONFIG={%DEFAULT_CONFIG};
	$FORCE_RELOAD_CONFIG=0;
}

sub loadFile  {
	my ($file)=@_;
	awe::Log::info(110,$file);	
	my %hash;
	my $line=0;
	my ($k,$v);
	awe::Log::fatal(5,$file)
			unless open(CONF,$file);
	my $curgroup='main';
	my $additional='';
	for (<CONF>) {
		$line++;
		chomp;
		my $str=$_;
		# Удаляем комментарии, оставляя проэскейпенные шарпы
		s/(^|[^\\])\#.*/$1/g; 
		s/^[\s\t]*//;
		s/[\s\t]*$//;
		if ($additional) {
			$_="$additional $_";
			$additional='';
		}
		if (s/\\$//) {
			$additional=$_;
			next;
		}
		next
			unless length($_);
		if ( /^\$include\s+(\S+)\s*$/ ) {
			my $f=$1;
			if ($f!~/\// && $file=~/^(.+)\/.+$/) {
				$f=$1.'/'.$f;
			}
			return undef
				unless loadFile($f);
			next;
		}
		if (/^\[(\.?)(\S+)\]$/) {
			if ($1) {
				my $s=$2;
				$curgroup=~/([^.]+)/;
				$curgroup="$1.$s";
			} else {
				$curgroup=$2;
			}
			next;
		}
		if (/^([A-Z0-9_]+)\s*\=\s*(.*)[\#\s]*$/i) {
			my ($key,$value,$group)=($1,$2,$curgroup);
			$value=~s/^\"(.*)\"$/$key/;
			confSet($group,$key,$value);
		} else {
			fatal(22,$str,$line);
		}
	}
	close(CONF);
	return 1;
}

1;
