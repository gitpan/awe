package awe::Conf;
use Apache::Request;
use Exporter;
use awe::Context;
use awe::Log;
use strict;
use base qw(Exporter);
use vars qw(
	    @EXPORT
	    @ISA
	    %DEFAULT_CONFIG
	    %CONFIG
	   );

@ISA    = qw(Exporter);
@EXPORT = qw(
	     conf
	     confGroup
	     confGroupFull
	     confH
	     confA
						 
	     confObject
	     confObjectA
	     confObjectH

	    );

%CONFIG=(
	 subsystem => {shared => 0},
	 'templateType.default' => {type => 'tt2'},
	 reload    => {
		       config =>1,
		      },
	 language  => {
		       # Если ненайден никакой, исползуется этот
		       default => 'en',
											 
		       # Список и порядок, в каком языки проверяются.
		       # Порядок используется только в случае get
		       # и исползуется первый попавшийся
											 
		       list => 'en ru',
											 
		       # Порядок и способ добычи информации о языке
		       # *  param(lang) - значит из CGI параметра lang
		       #                  (используется этот-же параметр, в случае не указания его)
		       # *  uri         - выборка из пути, например articles/en/. Поиск согласно регекспу.
		       #                  В случае articles/ru/en/ выберется en и путь будет articles/ru/,
		       #                  что очевидно вызовет ошибку.
		       # *  header      - брать из заголовка (NOT RELEASED)
		       get  => 'param uri',
		       # Эта выборка языка используется в контроллере и производиться не будет,
		       # если get или list пусты. Поиск языкового подкоталога осуществляется
		       # до поиска объекта, хотя не факт, что это правильно.
		       # Язык устанавливается в контекстную переменную language
		      },
	 messages   => {
			#	Fatal errors
			1  => 'Passed parameter is not hash',
			2  => 'Error loading config file with name $1',
			3  => 'Config file is not exists or has no permissions to read',
			4  => 'Error loading config file $1 for subsystem $subsystem',
			5  => 'Error open config file $2 for sybsystem $1',
			6  => 'Error parsing hash parameter',
			7  => 'This subsystem ($1) is not defined',
			8  => 'Object "$1" is not defined',
			9  => 'No such action "$1" in object $2',
			10 => '!!! Unknown error executing action $1 in object $2',
			11 => 'Template "$1" is not found',
			12 => 'No methods to show template type $1',
			14 => 'Subsystem name is not defined',
			16 => 'Error init table $1',
			17 => 'Error table($1)->$2',
			18 => 'Template is not defined',
			19 => 'Template file is not exists "$1"',
			20 => 'Config file is not defined',
			21 => 'Subsystem definer is not defined',
			22 => 'bad config param "$1" (line: $2)',
			23 => '',
			24 => 'No url to redirect "$1"',
			25 => 'Redirect to current url failed, redirect to home url',
			26 => 'Can`t connect to database',
			27 => 'Unknown db.fieldsName parameters value',
			#												28 => '',
			#												29 => '',
			#												30 => '',
			#												31 => '',
			#												32 => '',
			33 => 'No action is specified',
			#												34 => '',
			35 => 'Error table "$1" attribute "$2" definition',
			#												36 => '',
			#												37 => '',
			38 => 'Element &lt;text&gt; is not found for text/plain output',
			39 => 'Object name error',
			40 => "WARNING! Can't create session user",
			#												41 => '',
			#												42 => '',
			#												43 => '',
			44 => 'Template type is not defined',
			45 => 'Error initializing module ($module)',
			46 => 'Context is not defined',
			47 => 'context() must have one parameter only',
			48 => 'Сессионный пользователь зашел не через куки',
			49 => 'Template execution error: "$1"',
			#												50 => '',
			51 => 'Неизвестный источник данных "$2($3)" для поля "$1" (должно быть param(*), user(*) или data(*))',
			52 => 'Неизвестный способ поиска языка',
			53 => 'Can not parse the $1 config parameter: "$1"',
			54 => 'Template $1 is not defined',

			# 60 - awe::Auth
			60 => 'Permission type is not defined: $1',
			61 => 'Unknown type of permission: $1',
			62 => 'Unknown name of system permission: $1',

			# Notice and debug messages
			101 => 'Loading config file $1',
			102 => 'Register subsystem $1',
			103 => '$subsystem: $object->$action($1)',
			104 => 'Create session user',
			105 => 'Login "$1" failed, reason is $2',
			106 => '',
			107 => 'Login "$1"',
			108 => 'delete session user',
			109 => 'can`t delete session user',
			110 => 'Reload "$1"',
		       },
	);

awe::Conf::addDefaultConfig(\%CONFIG);

sub defaultConfig {
  return \%DEFAULT_CONFIG;
}

sub addDefaultConfig {
  my $hr=shift;
  foreach my $key (keys %$hr) {
    map {$DEFAULT_CONFIG{$key}->{$_}=$hr->{$key}->{$_}} keys %{$hr->{$key}};
  }
}

sub getMessage {
  my $code=shift;
  my $str=conf('messages',$code);
  $str=~s/\$(\d+)/shift/eg;
  $str=~s/\$([A-Z]+)/awe::Context::context($1)/egi;
  $str.=' '.join(',',@_)
    if @_;
  return $str;
}


sub conf {
  my ($group,$key)=join('.',@_)=~/^(\S+)\.(\S+)$/;
  if (awe::Context::subsystem('config')) {
    return awe::Context::subsystem('config')->{$group}->{$key};
  } else {
    return $DEFAULT_CONFIG{$group}->{$key};
  }
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


sub confObject {        return conf('objects',context('object'),@_);}
sub confObjectA {       return confA('objects',context('object'),@_);}
sub confObjectH {       return confH('objects',context('object'),@_);}

sub confGroupFull {
  my $group=shift;
  my %g=%{awe::Context::subsystem('config')->{$group} || {}};
  foreach my $sg (grep(/^$group\..+/,keys %{awe::Context::subsystem('config')})) {
    my $k=awe::Context::subsystem('config')->{$sg};
    my $ng=$sg;
    $ng=~s/^$group\.//;
    foreach (keys %$k) {
      $g{"$ng.$_"}=$k->{$_};
    }
  }
	
  return \%g;
}


sub confGroup {
  my $group=join('.',@_);
  return awe::Context::subsystem('config')->{$group};
}

sub confSet {
  my ($data,$group,$key,$value)=@_;
  $data->{$group}={}
    unless $data->{$group};
  if ($key=~s/\+$//) {
    if ($data->{$group}->{$key}) {
      $data->{$group}->{$key}.=" $value";
    } else {
      $data->{$group}->{$key}=$value;
    }
  } else {
    $data->{$group}->{$key}=$value;
  }
}

sub loadConfig {
  my $force=shift;
  my $file=awe::Context::subsystem('config_file');
  if ($force
      || !awe::Context::subsystem('config')
      || !awe::Context::subsystem('config_time')
      || conf('reload.config')
     ) {
    my $mtime=(stat("$file"))[9];
    awe::Log::fatal(3,$file)
	unless $mtime;
    if ($force || $mtime!=awe::Context::subsystem('config_time')) {
      my %CONFIG=%DEFAULT_CONFIG;
      awe::Log::fatal(4,$file)
	  unless loadFile($file,\%CONFIG);
      awe::Context::setSubsystem('config',\%CONFIG);
      awe::Context::setSubsystem('config_time',$mtime);
    }
  }
  return 1;
}


sub loadFile  {
  my ($file,$data)=@_;
  #	awe::Log::info(110,$file);	
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
	unless loadFile($f,$data);
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
    if (/^([A-Z0-9_:-]+\+?)\s*\=\s*(.*)[\#\s]*$/i) {
      my ($key,$value,$group)=($1,$2,$curgroup);
      # $value=~s/^\"(.*)\"$/$key/; !?!? - было так
      $value=~s/^\"(.*)\"$/$1/;
      confSet($data,$group,$key,$value);
    } else {
      fatal(22,$str,$line);
    }
  }
  close(CONF);
  return 1;
}

1;
