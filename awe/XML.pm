package awe::XML;
use strict;
use Exporter;
use XML::LibXSLT;
use XML::LibXML;
use awe::Log;
use awe::Conf;

use Storable;

use vars qw(@ISA
						@EXPORT

						$parser_xml
						$parser_xslt
						%XSLT_CACHE
						%XML_CACHE
					 );





@ISA = qw(Exporter);

@EXPORT = qw(
						 parserXML
						 parserXSLT

						 createElement
						 
						 hashToDOM
						 
						 newDOM
						 xmlFile
						 htmlFile
						 xsltFile
						);

sub BEGIN {
	%XML_CACHE=();
	%XSLT_CACHE=();

	$parser_xml            = undef;
	$parser_xslt           = undef;
}


sub xmlCache {
	my ($file,$data)=@_;
	if ($data) {
		awe::Log::info(111,$file);
		return $XML_CACHE{$file}=$data;
		return $data;
	} else {
		return $XML_CACHE{$file};
	}
}

sub xsltCache {
	my ($file,$data)=@_;
	if ($data) {
		awe::Log::info(113,$file);
		return $XSLT_CACHE{$file}=$data;
	} else {
		return $XSLT_CACHE{$file};
	}
}



sub xmlFile    {
	my $file=shift;
	my $data=xmlCache($file);
	if (awe::Conf::conf('reload.xml')
			|| !$data) {
		my $mtime=(stat($file))[9];
		awe::Log::fatal(41,$file)
				unless $mtime;
		$data=xmlCache($file,{object=>parserXML()->parse_file($file),
													mtime=>$mtime})
			if !$data || $mtime!=$data->{mtime};
	}
	return $data->{object};
}

sub htmlFile    {
	my $file=shift;
	my $data=xmlCache($file);
	if (awe::Conf::conf('reload.html')
			|| !$data) {
		my $mtime=(stat($file))[9];
		awe::Log::fatal(43,$file)
				unless $mtime;
		$data=xmlCache($file,{object=>parserXML()->parse_html_file($file),
													mtime=>$mtime})
			if !$data || $mtime!=$data->{mtime};
	}
	return $data->{object};
}

sub xsltFile    {
	my $file=shift;
	my $data=xsltCache($file);
	if (awe::Conf::conf('reload.xslt')
			|| !$data) {
		my $mtime=(stat($file))[9];
		awe::Log::fatal(42,$file)
				unless $mtime;
		$data=xsltCache($file,{object=>parserXSLT()->parse_stylesheet(xmlFile($file)),
													 mtime=>$mtime})
			if !$data || $mtime!=$data->{mtime};
	}
	return $data->{object};
}


sub parserXML  { return $parser_xml ? $parser_xml : $parser_xml=XML::LibXML->new(); }
sub parserXSLT { return $parser_xslt ? $parser_xslt : $parser_xslt=XML::LibXSLT->new(); }

sub newDOM    {
	return XML::LibXML::Document->new('1.0',awe::Conf::conf('xml.encode'));
}

sub createElement {
	my ($name,$ref)=@_;
	my $element=XML::LibXML::Element->new($name);
	foreach (keys %$ref) {
		if ($_ eq '@text') {
			my $text=XML::LibXML::Text->new($name);
			$text->setData(encodeToUTF8(awe::Conf::conf('xml.encode'),$ref->{$_}));
			$element->appendChild($text);
		} else {
			$element->setAttribute($_,encodeToUTF8(awe::Conf::conf('xml.encode'),$ref->{$_}));			
		}
	}
	return $element;
}

sub hashToDOM {
	my ($root,$hr,$options)=@_;
	$options={} unless $options;
	
	#
	# options:
	#
	# list_elements - для каждого элемента массива создается 'element'
	#                 и которого есть параметер number - его порядковый
	#                 номер (индекс)
	# clone         - Если встречается Element о колнируется, а не вставляется
	#
	
	if (ref($hr)=~/HASH/ || ($hr=~/HASH/ && ref($hr)) ) {
		foreach (keys %$hr) {
			my $e=XML::LibXML::Element->new($_);
			hashToDOM($e,$hr->{$_},$options);
			$root->appendChild($e);
		}
	} elsif (ref($hr)=~/ARRAY/) {
		my $i=0;
		foreach (@$hr) {
			if ($options->{list_elements}) {
				my $e=XML::LibXML::Element->new('element');
				$e->setAttribute('number',$i++);
				hashToDOM($e,$_,$options);
				$root->appendChild($e);
			} else {
				hashToDOM($root,$_,$options);
			}
		}
	} elsif (ref($hr) eq 'XML::LibXML::Element') {
		my $clone=$options->{clone};# || $hr->getParentNode(); hasToDOM часто вызывается самим собой с созданным элементом
		$root->appendChild($clone ? $hr->cloneNode(1) : $hr);
	} elsif (ref($hr) eq 'XML::LibXML::Document') {
		hashToDOM($root,$hr->documentElement()->cloneNode(1),$options);
	} else {
		my $text=XML::LibXML::Text->new($root->getName());
		$text->setData(encodeToUTF8(awe::Conf::conf('xml.encode'),$hr));
		$root->appendChild($text);
	}
}

sub initOutput {
	my ($dom,$sys,$root);
	$dom =newDOM();
	$root=XML::LibXML::Element->new('root');
	$sys =XML::LibXML::Element->new('sys');
	$root->appendChild($sys);
	$dom->setDocumentElement($root);
	return ($dom,$sys);
}


1;
