#
# Copyright (c) 2001-2002 Danil Pismenny <dapi@mail.ru>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package awe::Db;

use strict;
use DBI;
#use Apache::DBI;
use Error;
use awe::Conf;
use awe::Log;
use awe::Context;
use Exporter;
use Error qw(:try);

use vars qw(@ISA
	    @EXPORT
	    %CONFIG
	    $VERSION
	   );

@ISA = qw(Exporter);

( $VERSION ) = '$Revision: 0.2 $ ' =~ /\$Revision:\s+([^\s]+)/;

@EXPORT = qw(
	     dbSelect
	     dbInsert
	     dbUpdate
	     dbDelete

	     dbConnect
	     dbDisconnect

	     dbRollback
	     dbCommit

	     dbFetch
	     dbGenerateId

	     dbTransaction
	    );

%CONFIG=(
	 debug     => {sql => 1},
	 sql => {
		 fieldsName  => 'low',
		 transaction => 5,
		},
	 'sql.attr'=> {
		       RaiseError	  => 0,# The errors are thrown by the error functions
		       ShowErrorStatement => 0 # Is is no reasone, because "prepare_cached" don't show the statement.
		      },
	 messages => {
		      13 => "Can't connect to database",
		      28 => 'SQL: $1 ($4) "$3" for query "$2"',
		      29 => 'Call fetch until STH is not defined',
		      34 => 'No data to update or insert. $1',
		      36 => 'WARNING! You want to $1 whole table',
		      54 => "The '-' logic can't be applied for a hashref. It must be an arrayref",
		     }
	);

awe::Conf::addDefaultConfig(\%CONFIG);

@awe::Error::Db::ISA = qw(awe::Error);


sub dbSelect {
  my ($table,$fields,$where,$extra)=@_;
  my @bind;
  my $w = prepareData($where,'and',\@bind,1);
  logQuery(join(',',@bind)) if $table=~/group/;
  $w="WHERE $w" if $w;
  $fields=join(',',@$fields) if ref($fields)=~/ARRAY/;
  $fields='*' unless $fields;
  my $query = "SELECT $fields FROM $table $w";
  $query="$query $extra" if $extra;
  logQuery($query,@bind);
  my $sth = getDbh()->prepare_cached($query)
    || error(28,'prepare select',$query,getDbh()->err,getDbh()->errstr);
  my $rv  = $sth->execute(@bind)
    || error(28,'execute select',$query,getDbh()->err,getDbh()->errstr);
  return $sth;
}

sub dbUpdate {
  my ($table,$data,$pwhere)=@_;
  my @sbind;
  my @wbind;
  my $set   = prepareData($data,',',\@sbind);
  my $where = prepareData($pwhere,'and',\@wbind,1);
  error(36,'update') unless $where;
  $where="WHERE $where" if $where;
  my $query="UPDATE $table SET $set $where";
  error(34,$query)
    unless $set;
  logQuery($query,@sbind,@wbind);
  my $res=getDbh()->do($query,undef,map {"$_"} @sbind,map {"$_"} @wbind)
    || error(28,'do update',$query,getDbh()->err,getDbh()->errstr);
  return $res;
}

sub dbInsert {
  my ($table,$data)=@_;
  error(34)
    unless %$data;
  my @bind;
  my $values  = prepareData($data,',',\@bind,2);
  my $query   = "INSERT INTO $table (".join(',',keys %$data).") values ($values)";
  logQuery($query,@bind);
  my $sth = getDbh()->prepare_cached($query)
    || error(28,'prepare insert',$query,getDbh()->err,getDbh()->errstr);
  my $rv  = $sth->execute(@bind)
    || error(28,'execute insert',$query,getDbh()->err,getDbh()->errstr);
  return $rv;
}

sub dbDelete {
  my ($table,$where)=@_;
  my @bind;
  $where = prepareData($where,'and',\@bind,1);
  error(36,'delete')
    unless $where;
  $where="WHERE $where" if $where;
  my $query="DELETE FROM $table $where";
  logQuery($query,@bind);
  return getDbh()->do($query,undef,@bind)
    || error(28,'do delete',$query,getDbh()->err,getDbh()->errstr);
}


sub error  {  awe::Log::fatal('awe::Error::Db',@_);}

#sub dbh    { return $DBH;       } sub setDbh { return $DBH=shift; }

sub getDbh    { return context('dbh');          }
sub setDbh    { return setContext('dbh',shift); }

sub logQuery {
  log_notice('[SQL]',@_)
    if conf('debug.sql');
}

sub dbTransaction (&) {
  my $code=shift;
  my $max = conf('sql.transaction');
  my $e;
  logQuery('transaction','START');
  foreach (1..$max) {
    try	{
      $e = undef;
      $code->();
    }	catch awe::Error::Db with {
      $e = shift;
      dbRollback();
    };
    last unless $e;
  }
  if ($e) {
    logQuery('transaction','UNSUCESSFUL');
    throw $e;
  } else {
    logQuery('transaction','SUCESSFUL');
    dbCommit();
  }
}

sub dbCommit {
  logQuery('commit',	getDbh()->commit());
}

sub dbRollback {
  logQuery('rollback',	getDbh()->rollback());
}

sub dbGenerateId {
  my $table=shift;
  my $query=conf('sql.generator');
  $query=~s/\?/$table/;
  my $sth = getDbh()->prepare_cached($query)
    || error(28,'prepare generator',$query,getDbh()->err,getDbh()->errstr);
  my $rv  = $sth->execute()
    || error(28,'execute generator',$query,getDbh()->err,getDbh()->errstr);
  my $res=dbFetch($sth);
  $sth->finish();
  return (each %$res)[1]+0;
}

sub dbFetch {
  my $sth=shift;
  my $fn=conf('sql.fieldsName');
  error(29)
    unless $sth;
  return $sth->fetchrow_hashref($fn eq 'low' ? 'NAME_lc' : $fn eq 'up' ? 'NAME_uc' : 'NAME');
}



sub prepareData {
  my ($data,$logic,$bind,$type)=@_;
  my $str;
  if ($logic eq '-') {
    push @$bind,ref($data) ? @$data : $data;
  } else {
    if (ref($data)=~/ARRAY/) {
      foreach (@$data) {
	my $add='';
	if (ref($_)) {
	  $add.=prepareData($_,$logic,$bind);
	} else {
	  $add=$_;
	}
	$str.=$str ? " $logic $add " : $add if $add;
      }
    } elsif (ref($data)=~/HASH/) {
      foreach (keys %$data) {
	my $add='';
	if (ref($data->{$_}) || $_ eq '-') {
	  $add = prepareData($data->{$_},$_,$bind,1);
	} else {
	  $add= $type==2 ? '?' : "$_=?";
	  push @$bind,$data->{$_}; # ??? Can't do || ''
	}
	$str.=$str ? " $logic $add " : $add if $add;
      }
    } elsif ($data) {
      $str=$data;
    }
  }
  return $type==1 && $str ? "($str)" : $str;
}

sub dbConnect {
  my $ds=conf('sql.datasource');
  my $attr=confGroup('sql.attr');
  logQuery('connect attr',join(',',map {"$_=>$attr->{$_}"} keys %$attr));
  error(13,$ds)
    unless setDbh(DBI->connect($ds,
			       conf('sql.user'),
			       conf('sql.password'),
			       $attr
			      ));
}

sub dbDisconnect {
  my $dbh=getDbh();
  if ($dbh) {
    #		awe::Log::lastError() ? dbRollback() :	dbCommit();
    logQuery('disconnect');
    
    #
    # The is the method to suppredd the rollback executed in the Apache::DBI, otherwise
    # it writes the not fatal error to the STDERR
    #
    # This method MUST NOT BE USED under common DBI (not Apache::DBI);
    #
    
    $dbh->{AutoCommit}=1;	
    $dbh->disconnect();
    $dbh->{AutoCommit}=0;
    setDbh(undef);
  }
}


1;

__END__


=head1 NAME

awe::Db - Accurate database interface

=head1 SYNOPSIS

  use awe::Db;

  my $table='accounts';

  my $data ={date =>'now',
	     summa=>123};

  $rv = dbInsert($table, $data);

  $rv = dbUpdate($table, $data, {date=>'02/03/02'});

  dbTransaction {
    $sth = dbSelect($table, '*', $where);
    $row = dbFetch($sth);
    $row = modifieFields($row);
    dbUpdate($table, $row, $where);
  };


=head1 DESCRIPTION
	

This module allows you to work with default framework's database in
simple manier. It provides useful, but low-level interface. I
recommend to use C<awe::Table> instead. You can look into this module
for more examples of using awe::Db also.

The module uses C<Error> for throw errors.

=head2 Notation and Conventions

The following conventions are used in this document:

  $where   Specifies C<WHERE> part of SQL statement
  $table   Table name
  $data    Data fields and values for C<UPDATE> or C<INSERT>
  $rv      General Return Value (typically an integer)
  $extra   Extra string added to end of SQL statement
  $fields  Fields to select
  $sth     Statement handle object

The detailed descriptions of the C<$where>, C<$extra>, C<$data> and
C<$fields> input parameters see bellow.

=head1 PROCEDURAL INTERFACE

The interface is not object-oriented.

=over 4

=head2 dbSelect ($table, $fields, $where, $extra)

It returns the statement handle object if there is no
errors. Otherwise it throws a error.

The C<$fields> input parameter can be a string or a reference to the
array of field's name you wan to be selected. In case it is the
arrayref it is transformed to the string joining by the comma. If it
is not specified, the C<*> symbol is inserted to the SQL statement. 

The C<$where> input parameter is used in the other functions and have
the same syntax. It can be just a string, an array reference or a hash
reference. It is processed recursively, if it is the reference.

In case the processed parameter is a array reference, it is joined
into a single string with elements separeted by the current I<logic>
operator. The default C<logic> operator is C<and>. If the processed
element is a hashref then it is processed as hashref.

In case the processed parameter is a hash reference, it is joined into
a single string with portions like this C<$key = ?>. Where C<$key> is
the key of hash pair and the question-mark is a placeholder for bind
values. The value of this hash pair is pushed to the array of bind
values. If the value of hash pair is a array reference then it is
processed as described above and the key name of this pair is used as
logic to join. The logic can be any string, but there is no reasone to
use other then C<and> or C<or>. If the logic is C<-> (minus sign) then
the value of this hash pair is pushed to the bind array as is.

The C<$extra> parameter is just a string that is added to the tail of
the resulted SQL statement. It is the place for the SQL operators like
C<order by>, C<group by> etc.

The examples:

The function:

  dbSelect('users','',"login_date >= '03/02/01'",'order by login');

executes the SQL statement:

  SELECT * FROM users WHERE (login_data >= '03/02/01') order by login;

Next function illustrates using of bind values:

  dbSelect('users','login_date',{login=>'vasya'});

generates and executes:

  SELECT login_date FROM users WHERE (login = ?);

and the bind array contains one element: C<'vasya'>;

This one illustrates the recursion:

  dbSelect('users','',{or =>{
                            name  => 'vasya',
                            login => 'petya',
                            },
                       and => [
                              "login_date >= '01/02/02'",
                              "login_date <= '01/10/02'"
                              ]
                       });

generates the SQL statement:

  SELECT * FROM users WHERE ((login_date >= '01/02/02'
  and login_date <= '01/10/02') and (login=? or name=?))

the bind array contains two elements: C<'vasya','petya'>;

The similar SQL statement can be generated by these function:

Reverse array and hash:

  dbSelect('users','',["login_date >= '01/02/02'",
                       "login_date <= '01/10/02'",
                       or =>{
                            name  => 'vasya',
                            login => 'petya',
                            }
                       ]);

  SELECT * FROM users WHERE (login_date >= '01/02/02'
  and login_date <= '01/10/02' and (login=? or name=?))

Directly use bind values:

  dbSelect('users','',["login_date >= '01/02/02'",
                       "login_date <= '01/10/02'",
                       "(name = ? or login = ?)",
                        {'-' =>{
                            name  => 'vasya',
                            login => 'petya',
                            }
                        }
                       ]);

The C<$where> parameter is processed by the C<prepareData>
function. Look at the its source code for more details or experiment
with it.

=head2 dbInsert ($table, $data)

It returns the general return value (returned by DBI's
execute()). Otherwise it throws a error. The C<$data> input parameters
work is similar to the C<$where> but it use C<,> (comma) as default
I<logic> parameter.

=head2 dbUpdate ($table, $data, $where)

It returns the general return value (returned by DBI's
execute()). Otherwise it throws a error. For syntax of the C<$where>
input parameter look at the C<dbSelect> function. The work of the
C<$data> input parameter is similar to the C<$where> but it uses C<,>
(comma) as default I<logic> parameter.

=head2 dbDelete ($table, $where)

It returns the general return value (returned by DBI's
do()). Otherwise it throws a error. For syntax of the C<$where> input
parameter look at the C<dbSelect> function.

=head2 dbConnect

Connects to the database specified by the C<sql.database> config and
using user name, password and attributes from the C<sql.login>,
C<sql.password> and C<sql.attr>. Then it sets the default database
handle. No input and returened parameters. It throws a error if it is
not connected to the database.

=head2 dbDisconnect

Disconnects form the database. It undefines the database handle. No
input or returned parameters. It does nothing if there is no
connection to the database.

=head2 dbRollback

Just executes the DBI's C<rollback>.

=head2 dbCommit

Just executes the DBI's C<commit>.

=head2 dbFetch ($sth)

Executes DBI's C<fetchrow_hashref> for the specified statement handle
with the parameter specfied by the C<sql.fieldsName> config parameter
and returns the value returned by DBI. As sad in L<DBI> you must fetch
all the data or call the C<finish> method for the unfinished statement
handle. There is no the analog of the C<finish> in the C<awe::Db>
module.

=head2 dbGenerateId ($table)

Executes the SQL statement to select the ID for the new record in the
specified table and returns fetched ID (just one numeric value). It
uses the C<sql.generator> config parameter to create the
statement. See L</"CONFIG PARAMETERS"> for information about the
syntax of this parameter and other details.

=head2 dbTransaction CODE

Evaluates the C<CODE>. If the C<awe::Db::Error> error was thrown then
it does rollback and the code is evaluated again. The number of
evaluations is specified in the C<sql.transaction> config
parameter. If there is finished evaluation that has no the
C<awe::Db::Error> error thrown then it does commit and exit. The
transaction doesn't catch not C<awe::Db::Error> errors.

=back

=head1 INTERNAL FUNCTIONS

These functions are not exported, but I think you would like to use
their in som situations.

=over 4

=item error ($code,..)

Throws C<awe::Error::Db> error. It just executes C<awe::Log::fatal>.

=item logQuery

It just executes log_notice('[SQL]',@_) if the debug log is allowed.

=item prepareData ($where,$separator,\@bind,$type);

$separator='and' or ','

$type = 0,1,2

=item getDbh

Returns database handle

=item setDbh

Sets database handle. This handle is set in the C<dbConnect> function.

=back


=head1 CONFIG PARAMETERS

There are some config parameters that are used by this module.

=over 4

=item sql.datasource

The data source with DBI syntax.

Eg. C<DBI:InterBase:dbname=/var/db/test>

=item sql.user

User name to connect to the database

=item sql.password

The password to connect to the database

=item sql.generator

The SQL statement that is used to generate the C<ID> key for the
table. The statemet's question-mark is replaced with the table
name. The example of this parameter for the InterBase SQL server is: 

  SELECT GEN_ID(?_seq,1) FROM table_gen

Of course, you must create special C<table_gen> before. Something like
this:

  CREATE TABLE table_gen (id INTEGER);
  INSERT INTO table_gen VALUES (1);

And you must create the generators (sequencor) for every tables you
want to use the generator for.

  CREATE GENERATOR users_seq;


=item debug.sql

Log the statements and other database operations for debug. Default
value is C<1> (yes)

=item sql.fieldsName

This attribute is used to specify which attribute name the
C<dbFetch()> method should use to get the field names for the hash
keys. Allowed values are C<low>, C<up> and C<none>.

=item sql.transaction

The number of tries in the transaction. The default value is C<5>.

=item sql.attr

The text hash of DBI's attributes are used by connection. Look to
L<DBI> for details. The default value is:

  C<RaiseError:0 ShowErrorStatement:0>


=back


=head1 EXAMPLES

Look for more examples at the C<awe::Table> module.


=head1 ERRORS

All thrown errors are based on the C<awe::Error::Db> abstract
exception class.

It is the list of possible errors and the functions that can throw
their:

=over 4

=item 13 => Can't connect to database

C<dbConnect()>

=item 28 => SQL: prepare/execute generator..

C<dbGenerateId()>

=item 28 => SQL: prepare/execute select..

C<dbSelect()>

=item 28 => SQL: do update..

C<dbUpdate()>

=item 28 => SQL: prepare/execute insert..

C<dbInsert()>

=item 28 => SQL: do delete ..

C<dbDelete()>

=item 29 => Call fetch until STH is not defined

C<dbFetch()>

=item 34 => No data to update or insert..

C<dbInsert()>, C<dbUpdate()>

=item 36 => WARNING! You want to update/delete whole table

C<dbUpdate()>, C<dbDelete()>


=back


=head1 SEE ALSO

awe(3), awe::Table(3), awe::Conf(3), DBI(3)

=head1 AUTHOR

Danil Pismenny <dapi@mail.ru>

=cut
