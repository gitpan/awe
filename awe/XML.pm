package awe::XML;
use strict;
use Exporter;
use XML::LibXSLT;
use XML::LibXML;
use awe::Log;
use awe::Context;
use awe::Conf;

use Storable;
use base qw(Exporter);

use vars qw(
	    @EXPORT

	    $parser_xml
	    $parser_xslt
	    %XSLT_CACHE
	    %XML_CACHE

	    %CONFIG
	   );


@EXPORT = qw(
	     parserXML
	     parserXSLT

	     createElement
	     createTextElement

	     hashToDOM

	     DOMToArray
	     DOMToHash

	     getText

	     newDOM

	     xmlFile
	     htmlFile
	     xsltFile

	     documentToText

	     xsltProcess

	     xmlCache
	     xsltCache
	    );

%CONFIG=(xml       => {encode =>'koi8-r'},
	 reload    => {html   =>1,
		       xml    =>1,
		       xslt   =>1},
	 messages   => {
			#	Fatal errors
			201 => 'XML document ($1) is not found',
			202 => 'XSLT stylesheet ($1) is not found',
			203 => 'HTML document ($1) is not found',
			204 => '"$1" template type must be xslt',
			205 => 'Load XML file "$1"',
			205 => 'Load XSLT file "$1"',

		       }

	);

awe::Conf::addDefaultConfig(\%CONFIG);


sub BEGIN {
  %XML_CACHE=();
  %XSLT_CACHE=();

  $parser_xml            = undef;
  $parser_xslt           = undef;
}


sub xmlCache {
  my ($file,$data)=@_;
  if ($data) {
    #		awe::Log::info(205,$file);
    return $XML_CACHE{$file}=$data;
    return $data;
  } else {
    return $XML_CACHE{$file};
  }
}

sub xsltCache {
  my ($file,$data)=@_;
  if ($data) {
    #		awe::Log::info(206,$file);
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
    awe::Log::fatal(201,$file)
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
    awe::Log::fatal(203,$file)
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
    awe::Log::fatal(202,$file)
	unless $mtime;
    $data=xsltCache($file,{object=>parserXSLT()->parse_stylesheet(xmlFile($file)),
			   mtime=>$mtime})
      if !$data || $mtime!=$data->{mtime};
  }
  return $data->{object};
}

sub xsltProcess {
  my ($xml,$template,$params)=@_;
  $params={} unless $params;
  $xml = xmlFile($xml)
    unless ref($xml);

  unless (ref($template)) {
    my $name = $template;
    $template = awe::Conf::conf('templates',context('object'),$name) || fatal(11,$name);
    $template=~s/^([A-Z0-9_]+):\s*//i;
    fatal(204,$name) if $1 && $1 ne 'xslt';
  }

  #	notice("input:",$xml->toString(),"\n\n");
  if (ref($template)=~/XML/) {
    $xml = $template->transform($xml,%$params);
  } else {
    foreach (ref($template)=~/ARRAY/ ? @$template : split(/\s+/,$template)) {
      my $stylesheet = xsltFile(/^\?/ ? $_ : awe::View::getTemplateDir({type=>'xslt'}).$_);
      $xml        = $stylesheet->transform($xml,%$params);
      #			notice("output:",$xml->toString(),"\n\n");
    }
  }
  return $xml;
}

sub getText {
  my ($element,$path)=@_;
  my $node=$element->find("$path/text()")->get_node(0);
  return $node ? $node->toString() : undef;
}

sub parserXML  { return $parser_xml ? $parser_xml : $parser_xml=XML::LibXML->new(); }
sub parserXSLT { return $parser_xslt ? $parser_xslt : $parser_xslt=XML::LibXSLT->new(); }

sub newDOM    {
  my $name = shift;
  my $dom = XML::LibXML::Document->new('1.0',awe::Conf::conf('xml.encode'));
  return $dom unless $name;
  my $root = createElement($name, @_);
  $dom -> setDocumentElement($root);
  return ($dom,$root);
}

sub createElement {
  my ($name,$data,$params)=@_;
  my $element=XML::LibXML::Element->new($name);
  hashToDOM($element,$data) if $data;
  if ($params) {
    foreach (keys %$params) {
      $element->
	setAttribute($_,
		     encodeToUTF8(awe::Conf::conf('xml.encode'),$params->{$_})
		    );
    }
  }
  return $element;
}

sub documentToText {
  my $document = shift;
  my $root= $document->
    documentElement();
  my $str;
  foreach ($root->
	   findnodes('/'.$root->getName().'/node()')) {
    $str.=$_->toString();
  }
  return \$str;
}

sub createTextElement {
  my ($name,$text)=@_;
  my $element = XML::LibXML::Text->new($name);
  $element->setData(encodeToUTF8(awe::Conf::conf('xml.encode'),$text));
  return $element;
}

sub DOMToHash {
  my ($dom,$path,$options) = @_;
  $dom = $dom->documentElement()
    if $dom=~/::Document/;
  my %hash=(ATTR=>{});
  if ($path) {
    my $nodes = $dom->findnodes($path);
    return {} unless $nodes->size();
    return DOMToHash($nodes->get_node(0),'',$options);
  } else {
    foreach ($dom->getAttributes()) {
      $hash{ATTR}->{$_->getName()} = $_->value();
    }
    foreach ($dom->getChildnodes()) {
      if (ref($_)=~/::Text/) {
	$hash{$_->getName()} = $_->getData();
      } else {
	$hash{$_->getName()} = DOMToHash($_,'',$options);				
      }
    }
    return \%hash;		#{$dom->getName() => \%hash},
  }
}

sub DOMToArray {
  my ($dom,$path,$options) = @_;
  $dom = $dom->documentElement()
    if $dom=~/::Document/;
  my @a;
  foreach ($dom->findnodes($path)) {
    push @a,DOMToHash($_,'',$options);
  }
  return \@a;
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
      if (/^\@/) {
	my $value=$hr->{$_};
	if ($_ eq '@text') {
	  $root->appendChild(createTextElement($root->getName(),$value));
	} else {
	  s/^\@//;
	  $root->setAttribute($_,encodeToUTF8(awe::Conf::conf('xml.encode'),$value));
	}
      } else {
	my $e=createElement($_);
	hashToDOM($e,$hr->{$_},$options);
	$root->appendChild($e);
      }
    }
  } elsif (ref($hr)=~/ARRAY/) {
    my $i=0;
    foreach (@$hr) {
      if ($options->{list_elements}) {
	my $e=createElement('element');
	$e->setAttribute('number',$i++);
	hashToDOM($e,$_,$options);
	$root->appendChild($e);
      } else {
	hashToDOM($root,$_,$options);
      }
    }
  } elsif (ref($hr) eq 'XML::LibXML::Element') {
    my $clone=$options->{clone}; # || $hr->getParentNode(); hasToDOM часто вызывается самим собой с созданным элементом
    $root->appendChild($clone ? $hr->cloneNode(1) : $hr);
  } elsif (ref($hr) eq 'XML::LibXML::Document') {
    hashToDOM($root,$hr->documentElement()->cloneNode(1),$options);
  } else {
    $root->appendChild(createTextElement($root->getName(),$hr));
  }
}


package awe::View_xslt;
use strict;
use awe::XML;
use awe::Log;
use awe::Context;
use awe::Conf;
use awe::View;
use Apache::Constants qw(:common REDIRECT BAD_REQUEST OK);

sub show {
  my ($r,$template,$data)=@_;
	
  my ($dom,$root)=newDOM('root',{result =>$data,
				 context=>context()});
  $data=$dom;
	
  my $stylesheet;
  fatal(18)
    unless $template->{template};
  my %params=(lang=>"'".context('language')."'");
  foreach (split(/\s+/,$template->{template})) {
    $stylesheet=xsltFile(/^\?/ ? $_ : awe::View::getTemplateDir($template).conf("templates.".context('object').".DIR").$_);
    $data=$stylesheet->transform($data,%params);
    #		notice("output ($_)",$data->toString(),"\n\n");
  }

	
  $r->content_type($stylesheet->media_type());
  $r->send_http_header;
  return 1 if $r->prev || $r->header_only;
  $r->print($stylesheet->output_string($data));
}

package awe::TableDOM;
use strict;
use awe::Table;
use awe::XML;
use strict;
use base qw(Exporter awe::Table);

sub ListDOM {
  my ($self,$param)=@_;
  return $self->Select($param,$self->prepareOrder()) ? $self->getListDOM($param) : undef;
}


sub getListDOM {
  my $self=shift;
  my $param=shift;
	
  my $root=createElement('list',{table=>$self->name()});
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
    while (my $f=dbFetch($self->{sth})) {
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
  my $row=createElement('row',{num=>$r});
  $row->setAttribute($pk,$rec->{$pk})
    if $pk;
  my $c=0;
  foreach (keys %$rec) {
    my $column = createElement($_,{field=>$c++,
				   '@text'=>$rec->{$_}});
    $row->appendChild($column);
  }
  $root->appendChild($row);
}


1;
