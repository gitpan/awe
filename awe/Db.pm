package awe::Db;
use Apache::DBI;
use strict;
use awe::Conf;
use awe::Log;
use awe::Data;
use DBI;
use Exporter;


use vars qw(@ISA
						@EXPORT
						$DBH
					 );

@ISA = qw(Exporter);

@EXPORT = qw(
						 SELECT
						 INSERT
						 UPDATE
						 DELETE
						 COMMIT
						 fetch
						 generateID
						);

$DBH=undef;


#sub hdl { return $DBH; }
sub logQuery {
	notice('[SQL]',@_)
		if conf('debug.sql');
}

sub init {
	$DBH=undef;
#	        $attr = {
#           ib_timestampformat => '%m-%d-%Y %H:%M',
#           ib_dateformat => '%m-%d-%Y',
#           ib_timeformat => '%H:%M',
#        };

	return 1;
}

sub deinit {
	if ($DBH) {
		awe::Log::lastError() ? ROLLBACK() :	COMMIT();
		$DBH->{AutoCommit}=1; #Подавить rollback в Apache::DBI;
		$DBH->disconnect();
	}
	#	$DBH->{Active}=0; 
	$DBH=undef;
}

sub COMMIT {
	logQuery('commit',	$DBH->commit());
}

sub ROLLBACK {
	logQuery('rollback',	$DBH->rollback());
}

sub generateID {
	my $table=shift;
	my $query=conf('sql.generator');
	$query=~s/\?/$table/;
	my $sth = $DBH->prepare_cached($query)
		|| fatal(28,'prepare generator',$query);
	my $rv  = $sth->execute()
		|| fatal(29,'execute generator',$query);
	my $res=fetch($sth);
	return (each %$res)[1]+0;
}

sub fetch {
	my $sth=shift;
	my $fn=conf('db','fieldsName');
	fatal(29)
			unless $sth;
	return $sth->fetchrow_hashref($fn eq 'low' ? 'NAME_lc' : $fn eq 'up' ? 'NAME_uc' : 'NAME');
}

sub SELECT {
	my ($table,$param)=@_;
	my @bind;
	my $where=prepareData($param,'and',\@bind,1);
	$where="where $where" if $where;
	my $query="select * from $table $where";
	logQuery($query,@bind);
	my $sth = $DBH->prepare_cached($query)
		|| fatal(28,'prepare select',$query);
	my $rv  = $sth->execute(@bind)
		|| fatal(28,'execute select',$query);
	return $sth;
}

sub UPDATE {
	my ($table,$pset,$pwhere)=@_;
	my @sbind;
	my @wbind;
	my $set   = prepareData($pset,',',\@sbind);
	my $where = prepareData($pwhere,'and',\@wbind,1);
	fatal(36,'update')
			unless $where;
	$where="where $where" if $where;
	my $query="update $table set $set $where";
	fatal(34,$query)
			unless $set;
	logQuery($query,@sbind,@wbind);
	return $DBH->do($query,undef,@sbind,@wbind)
		|| fatal(28,'do update',$query);
}

sub INSERT {
	my ($table,$data)=@_;
	fatal(34)
			unless %$data;
	my @bind;
	my $values  = prepareData($data,',',\@bind,2);
	my $query   = "insert into $table (".join(',',keys %$data).") values ($values)";
	logQuery($query,@bind);
	my $sth = $DBH->prepare_cached($query)
		|| fatal(28,'prepare insert',$query);
	my $rv  = $sth->execute(@bind)
		|| fatal(28,'execute insert',$query);
	return $rv;
}

sub DELETE {
	my ($table,$where)=@_;
	my @bind;
	$where = prepareData($where,'and',\@bind,1);
	fatal(36,'delete')
			unless $where;
	$where="where $where" if $where;
	my $query="delete from $table $where";
	logQuery($query,@bind);
	return $DBH->do($query,undef,@bind)
		|| fatal(28,'do delete',$query);
}




sub prepareData {
	my ($data,$logic,$bind,$type)=@_;
	my $str;
	if (ref($data)=~/ARRAY/) {
		foreach (@$data) {
			my $add='';
			if (ref($_)) {
				$add.=prepareData($_,$logic,$bind);
			} elsif ($_ eq '-') {
				push @$bind,$_;
			} else {
				$add=$_;
			}
			$str.=$str ? " $logic $add " : $add if $add;
		}
	} elsif (ref($data)=~/HASH/) {
		if ($logic eq '-') {
			push @$bind,@$data;
		} else {
			foreach (keys %$data) {
				my $add='';
				if (ref($data->{$_})) {
					$add=prepareData($data->{$_},$_,$bind);
				} else {
					$add= $type==2 ? '?' : "$_=?";
					push @$bind,$data->{$_};# ??? Нельзя делать || ''
				}
				$str.=$str ? " $logic $add " : $add if $add;
			}
		}
	} elsif ($data) {
		$str=$data;
	}
	return $type==1 && $str ? "($str)" : $str;
}

sub CONNECT {
	my $ds=conf('sql.datasource');
	my $attr=confGroup('sql.attr');
	notice('connect attr',join(',',%$attr));
	$DBH=undef;
	return 1
		unless $ds;
	return undef
		unless $DBH  =
			DBI->connect($ds,
									 conf('sql.user'),
									 conf('sql.password'),
									 $attr) || fatal(13);
}

1;
