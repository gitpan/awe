package awe::Table;
use strict;
use awe::Log;
use awe::Conf;
use awe::Db;
use awe::Context;

use strict;
use base qw(Exporter);
use vars qw(@EXPORT %CONFIG);

@EXPORT = qw(table);

%CONFIG=(
	 messages => {
		      15 => 'Table for this $1 object is not found',
		      30 => 'Error call db::select',
		      31 => 'Call table->load without parameter',
		      32 => 'No WHERE and no preselected row for update. table->update',
		     }
	);

awe::Conf::addDefaultConfig(\%CONFIG);

@awe::Error::Table::ISA = qw(awe::Error);
sub error  {	awe::Log::fatal('awe::Error::Table',@_); }


sub table {
  my $name = shift;
  my $tables = context('tables');
  $tables = setContext('tables',{}) unless $tables;
  return $tables->{$name} ? $tables->{$name} : $tables->{$name}=awe::Table->new($name);
}

sub DESTROY {
  my $self=shift;
  $self->finish();
}

sub new {
  my $class	= shift;
  my $name = shift || context('table') ||
    conf('objects',context('object'),'table')	||
      error(15,context('object'));

  my $self	= {name    => $name,
		   table   => conf("tables.$name.table") || lc($name),
		   default => confH("tables.$name.default") || {},
		   order   => conf("tables.$name.order") || '',
		   attr    => confA("tables.$name.attr") || [],
		   id      => conf("tables.$name.id") || undef,
		  };
  return bless $self, $class;
}

sub name { return $_[0]->{name}; }

sub tableName { return $_[0]->{table}; }

sub Load {
  my ($self,$param)=@_;
  error(31)
    unless defined $param;
  $param={$self->{id}=>$param}
    if !ref($param);
  return $self->Select($param,$self->prepareOrder()) ? $self->getOne() : undef;
}

sub clear {
  my $self=shift;
  $self->finish();
  $self->{list}=undef;
}

sub List {
  my ($self,$param)=@_;
  return $self->Select($param,$self->prepareOrder()) ? $self->getList() : undef;
}

sub Modify {
  my ($self,$data,$where)=@_;
  unless ($where) {
    my $hr=$self->get();
    error(32)
      unless $hr && defined $hr->{$self->{id}};
    $where={$self->{id}=>$hr->{$self->{id}}};
  }
  $self->prepare($data);
  return dbUpdate($self->{table},$data,$where);
}

sub Create {
  my ($self,$data)=@_;
  $data->{$self->{id}}=dbGenerateId($self->{table})
    if $self->{id} && not exists $data->{$self->{id}};
  $self->prepare($data);
  $self->clear();
  my $res=dbInsert($self->{table},$data);
  return undef
    unless $res;
  $self->{list}=[];	
  return $self->{list}->[0]=$data;
}

sub Delete {
  my ($self,$where)=@_;
  unless ($where) {
    my $hr=$self->get();
    error(32)
      unless $hr && defined $hr->{$self->{id}};
    $where={$self->{id}=>$hr->{$self->{id}}};
  }
  return dbDelete($self->{table},$where);
}

sub prepareOrder {
  my $self=shift;
  return "order by $self->{order}" if $self->{order};
}


sub prepare {
  my ($self,$data)=@_;
  foreach (keys %{$self->{default}}) {
    $data->{$_}=$self->{default}->{$_}
      unless $data->{$_}=~/./;
  }
  return $data;
}
		
		
sub Select {
  my $self=shift;
  $self->{sth}=dbSelect($self->{table},'*',@_) || error(30);
  $self->{list}=[];
  return 1;
}

sub SelectAll {
  my ($self,$data)=@_;
  $self->Select($data,$self->prepareOrder());
  return $self->getList();
}

sub SelectOne {
  my ($self,$data)=@_;
  $self->Select($data);
  return $self->getOne();
}

sub count {
  my $self=shift;
  return length(@{$self->getList()});
}

sub getOne {
  my $self=shift;
  my $hr=$self->get();
  $self->finish();
  return $hr;
}

sub get {
  my ($self,$key)=@_;
  my $hr=$self->getList(1);
  return undef  unless $hr;
  return $key ? $hr->[0]->{$key} : $hr->[0];
}

sub getList {
  my $self=shift;
  my $count=shift;
  if ($self->{sth}) {
    my $c=0;
    while (my $f=dbFetch($self->{sth})) {
      push @{$self->{list}},$self->filter($f);
      last if $count && $c++>=$count;
    }
    $self->finish()
      unless $count;
    $self->{sth}=undef;
  }
	
  return $self->{list};
}

sub filter {
  my $self=shift;
  my $hr=shift;
  return $hr;
}

sub finish {
  my $self=shift;
  return $self->{sth} ? $self->{sth}->finish() : undef;
}

1;
