package awe::Object::Db;
use strict;
use awe::Table;
use awe::Db;
use awe::Conf;
use awe::Log;
use awe::Context;
use base qw(awe::Object::Base);

sub init {
	my $self=shift;
	return undef unless $self->SUPER::init();
	return fatal(13)
		unless dbConnect();
	return 1;
}

sub deinit {
	my $self=shift;
	$self->SUPER::deinit();
	dbDisconnect();
}

sub getFields {
	my ($self,$fields)=@_; # $fields - extended fields to override CGi params
	my $nf = confObjectH('fields',context('action'));
	foreach (keys %$nf) {
		unless (exists $fields->{$_}) {
			my $src=$nf->{$_};
			if ($src=~/^([A-Z]+)(\((.*)\))?$/i) {
				$fields->{$_}=$self->getFieldsValueBySrc($_,$1,$3);
			} else {
				fatal(51,$_,$src);				
			}
		}
	}
	return $fields;
}

sub getFieldsValueBySrc {
	my ($self,$name,$src,$value)=@_;
	if ($src eq 'param') {
		return param($value || $name);
	} elsif ($src eq 'data') {
		my ($data,$key)=split(',',$value);
		$key = $name unless $key;
		return $self->data($data)->{$key};
	} else {
		fatal(51,$name,$src,$value);				
	}
}

sub action_list {
	my $self=shift;
	return table()->List($self->getFields());
}

sub action_create {
	my $self=shift;
	return table()->Create($self->getFields());
}


1;
