package awe::Log;
use Exporter;
use awe::Conf;
use awe::Data;
use Carp;
use strict;
use vars qw(@ISA
						@EXPORT
						$log_object
						@ERRORS_LOG
						$IS_ERROR_FATAL
					 );

@ISA = qw(Exporter);
@EXPORT = qw(fatal error debug notice warning info lastError getErrorLog);

$log_object='awe::Log::STDERR';

sub init {
	my $log=shift;
	$IS_ERROR_FATAL=0;
	@ERRORS_LOG=();
	return $awe::Log::log_object=$log;
}

sub deinit {
	@ERRORS_LOG=();
	$IS_ERROR_FATAL=0;
	$log_object='awe::Log::STDERR';
}

sub getErrorLog {
	return \@ERRORS_LOG;
}

sub isErrorFatal {
	return $IS_ERROR_FATAL;
}

sub lastError {
	return @ERRORS_LOG ? @ERRORS_LOG[@ERRORS_LOG] : undef ;
}

sub fatal {
	$IS_ERROR_FATAL=1;
	my $s=getErrorMessage(@_);
	push @ERRORS_LOG,$s;
	# И та выведется через croak
	$log_object->error($s);
	croak $s;
}

sub error {
	my $s=getErrorMessage(@_);
	push @ERRORS_LOG,$s;
	$log_object->error($s);
	return undef;
}

sub notice {
	$log_object->notice(getMessage(@_));
	return 0;
}
	
sub debug {
	$log_object->debug(getMessage(@_));
	return 0;
}

sub info {
	$log_object->info(getMessage(@_));
	return 0;
}

sub warning {
	$log_object->warn(getMessage(@_));
	return 0;
}

sub timemark {
	notice(@_,time());
	return 0;
}

sub getMessage {
	if ($_[0]=~/^\d+$/) {
		my $d=shift;
		my $str=conf('messages',$d);
		$str=~s/\$(\d+)/shift/eg;
		$str=~s/\$([A-Z]+)/awe::Data::context($1)/egi;
		$str.=' '.join(',',@_)
			if @_;
		return $str;
	} else {
		return join("\t",@_);		
	}
}

sub getErrorMessage {
	
	if ($_[0]=~/^\d+$/) {
		my $d=shift;
		return "(code: $d) ".getMessage($d,@_);
	} else {
		return getMessage(@_);		
	}
}


package awe::Log::STDERR;
use strict;
use awe::Log;

sub notice {
	my $self=shift;
	print STDERR awe::Log::getMessage(@_)."\n";
}
	
sub error {
	my $self=shift;
	print STDERR awe::Log::getErrorMessage(@_)."\n";
}

sub debug {
	my $self=shift;
	print STDERR awe::Log::getMessage(@_)."\n";
}

sub info {
	my $self=shift;
	print STDERR awe::Log::getMessage(@_)."\n";
}

sub warn {
	my $self=shift;
	print STDERR awe::Log::getMessage(@_)."\n";
}


=pod


=cut

1;
