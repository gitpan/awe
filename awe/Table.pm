package awe::Table;
use strict;
use awe::Log;
use awe::Conf;
use awe::Db;
use awe::Data;

use XML::LibXML;

use strict;
use Exporter;
use vars qw(@ISA
						@EXPORT
						%TABLES
					 );

@ISA = qw(Exporter);

@EXPORT = qw(
						 table
						);


sub init {
	%TABLES=();
}

sub deinit {
	%TABLES=();
}

sub table {
	my $name=shift;
	return $TABLES{$name} ? $TABLES{$name} : $TABLES{$name}=awe::Table->new($name);
}

sub DESTROY {
	my $self=shift;
	$self->finish();
}

sub new {
  my $class	= shift;
  my $name = shift || conf('objects',
													 context('object'),
													 'table') || fatal(15,context('object'));
  my $self	= {name  => $name,
							 table => conf("tables.$name.table") || lc("table_$name"),
							 default => confH("tables.$name.default") || {},
							 attr  => confA("tables.$name.attr") || [],
							 id    => conf("tables.$name.id") || undef,
							};
	
	return bless $self, $class;
}

sub name { return $_[0]->{name}; }

sub load {
	my ($self,$param)=@_;
	fatal(31)
			unless $param;
	$param={$self->{id}=>$param}
		if !ref($param);

	return $self->select($param) ? $self->getOne() : undef;
}

sub clear {
	my $self=shift;
	$self->finish();
	$self->{list}=undef;
}

sub list {
	my ($self,$param)=@_;
	return $self->select($param) ? $self->getList() : undef;
}

sub listDOM {
	my ($self,$param)=@_;
	return $self->select($param) ? $self->getListDOM($param) : undef;
}

sub modify {
	my ($self,$data,$where)=@_;
	unless ($where) {
		my $hr=$self->get();
		fatal(32)
				unless $hr && defined $hr->{$self->{id}};
		$where={$self->{id}=>$hr->{$self->{id}}};
	}
	$self->prepare($data);
	return UPDATE($self->{table},$data,$where);
}

sub create {
	my ($self,$data)=@_;
	$data->{$self->{id}}=generateID($self->{table})
		if $self->{id} && not exists $data->{$self->{id}};
	$self->prepare($data);
	$self->clear();
	my $res=INSERT($self->{table},$data);
	return undef
		unless $res;
	$self->{list}=[];	
	return $self->{list}->[0]=$data;
}

sub delete {
	my ($self,$where)=@_;
	unless ($where) {
		my $hr=$self->get();
		fatal(32)
				unless $hr && defined $hr->{$self->{id}};
		$where={$self->{id}=>$hr->{$self->{id}}};
	}
	return DELETE($self->{table},$where);
}



sub prepare {
	my ($self,$data)=@_;
	foreach (keys %{$self->{default}}) {
		$data->{$_}=$self->{default}->{$_}
			unless $data->{$_}=~/./;
	}
}
		
		
sub select {
	my $self=shift;
	$self->{sth}=SELECT($self->{table},@_) || fatal(30);
	$self->{list}=[];
	return 1;
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
	return undef
		unless $hr;
	return $key ? $hr->[0]->{$key} : $hr->[0];
}

sub getList {
	my $self=shift;
	my $count=shift;
	if ($self->{sth}) {
		my $c=0;
		while (my $f=fetch($self->{sth})) {
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

sub getListDOM {
	my $self=shift;
	my $param=shift;
	
	my $root=XML::LibXML::Element->new('list');
	$root->setAttribute('table',$self->name());
	foreach (grep(/^[A-Z]/i,keys %$param)) {
		$root->setAttribute($_,
												$param->{$_});
	}
	my $r=0;
	if ($self->{sth}) {
		foreach (@{$self->{list}}) {
			appendRowToDOM($root,
										 $_,
										 $self->{id},
										 $r++);
		}
		while (my $f=fetch($self->{sth})) {
			push @{$self->{list}},$f;
			appendRowToDOM($root,
										 $self->filter($f),
										 $self->{id},
										 $r++);
			
		}
		$self->{sth}=undef;
	} else {
		foreach (@{$self->getList()}) {
			appendRowToDOM($root,
										 $_,
										 $self->{id},
										 $r++);
		}
	}
	return $root;
}

sub appendRowToDOM {
	my ($root,$rec,$pk,$r)=@_;
	my $row=XML::LibXML::Element->new('row');
	$row->setAttribute('num',$r);
	$row->setAttribute($pk,$rec->{$pk})
		if $pk;
	my $c=0;
	foreach (keys %$rec) {
		my $column=XML::LibXML::Element->new($_);
		$column->setAttribute('field',$c++);
		my $text=XML::LibXML::Text->new($_);
		$text->setData(encodeToUTF8('koi8-r',$rec->{$_}));
		$column->appendChild($text);
		$row->appendChild($column);
	}
	$root->appendChild($row);
}


1;
