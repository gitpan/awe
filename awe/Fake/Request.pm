package awe::Fake::Request;
use Apache::FakeRequest;
use Socket;
use Exporter;
use vars qw(@ISA
						@EXPORT);

@ISA=qw(Apache::FakeRequest);

sub log {
	my ($self)=@_;
	return $self;
}

sub print {
	my ($self)=shift;
#	print join(',',@_);
}

sub param {
	my ($self,$key)=@_;
	return $self->{params}->{$key};
}

sub dir_config {
	my ($self,$key)=@_;
	return $self->{dir_config}->{$key};
}

sub cookie {
	my $self=shift;
	return $self->{cookie};
}

sub local_addr {
	my $self=shift;
	my $iaddr = gethostbyname($self->server_hostname());
	my $port = getservbyname('http', 'tcp');
	my $sin=sockaddr_in($port, $iaddr);
	return $sin;
}

sub server_hostname { return 'dapi'; }

sub server {return shift;}
sub connection {return shift;}

sub pnotes {
	my ($self,$key,$value)=@_;
	return defined $value ? $self->{pnotes}->{$key}=$value : $self->{pnotes}->{$key};
}

sub custom_response {
	my ($self,$code,$text)=@_;
	print "custom_response: $code, $text\n";
}

sub notice {
	my $self=shift;
	print STDERR join(',',@_)."\n";
}
	
sub error {
	my $self=shift;
	print STDERR join(',',@_)."\n";
}

sub debug {
	my $self=shift;
	print STDERR join(',',@_)."\n";
}

sub info {
	my $self=shift;
	print STDERR join(',',@_)."\n";
}

sub warn {
	my $self=shift;
	print STDERR join(',',@_)."\n";

}


1;
