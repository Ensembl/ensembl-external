#
# BioPerl module for DASAdaptor
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::DASAdaptor - Object representing an
instance of a DAS DB connection

=head1 SYNOPSIS

    $db Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
        -url   => 'http://servlet.sanger.ac.uk:8080/das',
        -dsn   => 'ensembl100',
        );

    @features  = $db->get_Features('X45667.00001');

    

=head1 DESCRIPTION

This object represents a DAS database that is implemented somehow (you
shouldn\'t care much as long as you can get the object). From the
object you can pull out other objects by their stable identifier.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;

use vars qw(@ISA);
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);

# Object preamble

use Bio::EnsEMBL::ExternalData::BaseAdaptor;
use Bio::DasLite;

@ISA = qw(Bio::EnsEMBL::ExternalData::BaseAdaptor);

use vars qw( $DEFAULT_PROTOCOL %VALID_PROTOCOLS );

BEGIN{
  $DEFAULT_PROTOCOL = 'http';
  %VALID_PROTOCOLS = map{ $_, 1 } qw( http https );
}

#----------------------------------------------------------------------
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub new {
    my($pkg, @args) = @_;

    my $self = bless {}, $pkg;

    my ( $url,
	 $dsn,
	 $ensdb,
	 $timeout,
	 $proxy_url,
	 $protocol,
	 $domain,
	 $name,
	 $type,
	 $authority,
	 $label,
	 $labelflag,
	 $caption,
	 $color,
	 $linktext,
	 $linkurl,
	 $strand,
	 $depth,
	 $group,
	 $stylesheet,
	 $score,
	 $conftype,
	 $active,
	 $description,
	 $types,
	 $on,
	 $enable,
	 $help,
	 $mapping, 
	 $fasta ) = &rearrange([qw( URL
					   DSN
					   ENSDB
					   TIMEOUT
					   PROXY_URL
					   PROTOCOL
					   DOMAIN
					   NAME
					   TYPE
					   AUTHORITY
					   LABEL
					   LABELFLAG
					   CAPTION
					   COLOR
					   LINKTEXT
					   LINKURL
					   STRAND
					   DEPTH
					   GROUP
					   STYLESHEET
				           SCORE
					   CONFTYPE
					   ACTIVE
					   DESCRIPTION
					   TYPES
					   ON
					   ENABLE
					   HELP
					   MAPPING
					   FASTA)],@args);

#    warn("NEW DAS LITE:" .join('*', @args));

#    $url      && $self->url( $url );
#    $protocol && $self->protocol( $protocol );
#    $domain   && $self->domain( $domain );

    my $source_url = $self->url($url);

    $source_url =~ m|\w+://\w+| || 
      (    warn(join('*',@args))  && throw("Invalid URL $url!"));

    $timeout ||= 30;
    $self->_db_handle( Bio::DasLite->new({dsn => $source_url, caching=>0, timeout=> $timeout}) );
#    $dsn       && $self->dsn( $dsn );
    $proxy_url && $self->proxy( $proxy_url );
    $types     && $self->types($types);
    $ensdb     && $self->ensembldb($ensdb);

    # Display meta-data (i.e. not used for DAS query itself) follows
    $name       && $self->name( $name );
    $type       && $self->type( $type );
    $authority  && $self->authority( $authority );
    $label      && $self->label( $label );
    $labelflag  && $self->labelflag( $labelflag );
    $caption    && $self->caption( $caption );
    $color      && $self->color( $color );
    $linktext   && $self->linktext( $linktext );
    $linkurl    && $self->linkurl($linkurl );
    $strand     && $self->strand( $strand );
    $self->depth( $depth ) if (defined($depth));

    $group      && $self->group( $group );
    $stylesheet && $self->stylesheet( $stylesheet );
    $score && $self->score( $score );
    $conftype   && $self->conftype( $conftype );
    $active     && $self->active( $active );
    $description     && $self->description( $description );
    $help        && $self->help( $help );
    # These are parsed to arrayrefs
    $on        && $self->on( $on );
    $mapping        && $self->mapping( $mapping );
    $enable        && $self->enable( $enable );
    $fasta     && $self->fasta( $fasta );

    return $self; # success - we hope!
}

#----------------------------------------------------------------------

=head2 ensembldb

 Title   : ensembldb
 Usage   : $obj->ensembldb($ensdb)
 Function: store an Ensembl database handle
 Returns : 
 Args    : none


=cut

sub ensembldb {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_ensembldb'} = $value;
    }
    return $self->{'_ensembldb'};
}

#----------------------------------------------------------------------

=head2 proxy

  Arg [1]   : scalar web proxy (optional)
  Function  : getter/setter for web proxy. Thin wrapper for Bio::DAS method
  Returntype: 
  Exceptions: scalar web proxy (optional)
  Caller    : 
  Example   : $proxy_copy = $das_adapt->proxy($name)

=cut

sub proxy {
   my $self = shift;
   return $self->_db_handle->http_proxy(@_);
}



#----------------------------------------------------------------------

=head2 url

 Title   : url
 Usage   : $obj->url("http://www.there.co.uk/das")
 Function: store a DAS data source URL
 Returns : 
 Args    : 


=cut

sub url{
  my $self = shift;
  if( @_ ){
    my $url = shift;

    if ($url =~ m!(\w+)://(.+/das)/(.+)!) {
	my ($protocol, $domain, $dsn) = ($1, $2, $3);
#	warn(join('*', "URL:$url",$protocol, $domain, $dsn));
	$protocol ||= $DEFAULT_PROTOCOL;

	$self->{_protocol} = $protocol;
	
	$self->{_dsn}= $dsn;
	$self->{_domain}= "$protocol://$domain";
	$self->{_url}= join('/', "$protocol:/", $domain, $dsn);
    } elsif ($url =~ m!(\w+)://(.+/das)(/)?!) {
	my ($protocol, $domain) = ($1, $2);
#	warn(join('*', "URL 2:$url",$protocol, $domain));
	$protocol ||= $DEFAULT_PROTOCOL;

	$self->{_protocol} = $protocol;
	$self->{_domain}= "$protocol://$domain";
	$self->{_url}= join('/', "$protocol:/", $domain);
    } else{
      throw("Invalid URL $url!" );
    }
  }

  return( $self->{_url});
}


#----------------------------------------------------------------------

=head2 protocol

  Arg [1]   : scalar protocol (optional)
  Function  : Getter/setter for protocol meta data
  Returntype: scalar protocol
  Exceptions: 
  Caller    : 
  Example   : $protocol_copy = $das_adapt->protocol($protocol)

=cut

sub protocol{
  my $key = '_protocol';
  my $self = shift;
  if( @_ ){
    my $protocol = shift;
    $protocol =~ s|://||;
    $protocol = lc( $protocol );
    $VALID_PROTOCOLS{$protocol} ||
      throw( "Protocol $protocol is not recognised" );
    $self->{$key} = $protocol;
  }
  return $self->{$key} || $DEFAULT_PROTOCOL;
}

#----------------------------------------------------------------------

=head2 domain

  Arg [1]   : scalar domain (optional)
  Function  : Getter/setter for domain meta data
  Returntype: scalar domain
  Exceptions: 
  Caller    : 
  Example   : $domain_copy = $das_adapt->domain($domain)

=cut

sub domain{
   my $self = shift;
#   if( @_ ){ $self->{'_domain'} = shift }
   return $self->{'_domain'};
}

#----------------------------------------------------------------------

=head2 types

 Title   : types
 Usage   : $obj->types([ 'type', 'type', .... ])
 Function: select types to return...
 Returns : 
 Args    : none


=cut

sub types {
    my ($self,$value) = @_;
    if( defined $value ) {
        $self->{'_types'} = $value;
    }
    return $self->{'_types'};
}


#----------------------------------------------------------------------

=head2 dsn

 Title   : dsn
 Usage   : $obj->dsn("source")
 Function: select a DAS data source
 Returns : 
 Args    : none


=cut

sub dsn {
    my ($self,$value) = @_;
#    if( $value){ $self->{'_dsn'} = $value }
    return $self->{'_dsn'};
}

#----------------------------------------------------------------------

=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function: 
 Example : 
 Returns : value of _db_handle
 Args    : newvalue (optional)


=cut

sub _db_handle{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_db_handle'} = $value;
    }
    return $self->{'_db_handle'};

}


#----------------------------------------------------------------------

=head2 _debug

 Title   : _debug
 Usage   : $obj->_debug($newval)
 Function: 
 Example : 
 Returns : value of _debug
 Args    : newvalue (optional)


=cut

sub _debug{
    my ($self,$value) = @_;
    if( defined $value) {
		$self->{'_debug'} = $value;
    }
    return $self->{'_debug'};
    
}


#----------------------------------------------------------------------

=head2 name

  Arg [1]   : scalar name (optional)
  Function  : Getter/setter for name meta data
  Returntype: scalar name
  Exceptions: 
  Caller    : 
  Example   : $name_copy = $das_adapt->name($name)

=cut

sub name{
   my $key = '_name';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 type

  Arg [1]   : scalar type (optional)
  Function  : Getter/setter for type meta data
  Returntype: scalar type
  Exceptions: 
  Caller    : 
  Example   : $type_copy = $das_adapt->type($type);

=cut

sub type{
   my $key = '_type';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 authority

  Arg [1]   : scalar authority (optional)
  Function  : Getter/setter for authority meta data
  Returntype: scalar authority
  Exceptions: 
  Caller    : 
  Example   : $authority_copy = $das_adapt->authority($authority);

=cut

sub authority{
   my $key = '_authority';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 label

  Arg [1]   : scalar label (optional)
  Function  : Getter/setter for label meta data
  Returntype: scalar label
  Exceptions: 
  Caller    : 
  Example   : $label_copy = $das_adapt->label($label);

=cut

sub label{
   my $key = '_label';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 labelflag

  Arg [1]   : scalar labelflag (optional)
  Function  : Getter/setter for labelflag meta data
  Returntype: scalar labelflag
  Exceptions: 
  Caller    : 
  Example   : $labelflag_copy = $das_adapt->labelflag($labelflag);

=cut

sub labelflag{
   my $key = '_labelflag';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 caption

  Arg [1]   : scalar caption (optional)
  Function  : Getter/setter for caption meta data
  Returntype: scalar caption
  Exceptions: 
  Caller    : 
  Example   : $caption_copy = $das_adapt->caption($caption);

=cut

sub caption{
   my $key = '_caption';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 color

  Arg [1]   : scalar color (optional)
  Function  : Getter/setter for color meta data
  Returntype: scalar color
  Exceptions: 
  Caller    : 
  Example   : $color_copy = $das_adapt->color($color);

=cut

sub color{
   my $key = '_color';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 linktext

  Arg [1]   : scalar linktext (optional)
  Function  : Getter/setter for linktext meta data
  Returntype: scalar linktext
  Exceptions: 
  Caller    : 
  Example   : $linktext_copy = $das_adapt->linktext($linktext);

=cut

sub linktext{
   my $key = '_linktext';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 linkurl

  Arg [1]   : scalar linkurl (optional)
  Function  : Getter/setter for linkurl meta data
  Returntype: scalar linkurl
  Exceptions: 
  Caller    : 
  Example   : $linkurl_copy = $das_adapt->linkurl($linkurl);

=cut

sub linkurl{
   my $key = '_linkurl';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 strand

  Arg [1]   : scalar strand (optional)
  Function  : Getter/setter for strand meta data
  Returntype: scalar strand
  Exceptions: 
  Caller    : 
  Example   : $strand_copy = $das_adapt->strand($strand);

=cut

sub strand{
   my $key = '_strand';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 depth

  Arg [1]   : scalar depth (optional)
  Function  : Getter/setter for depth meta data
  Returntype: scalar depth
  Exceptions: 
  Caller    : 
  Example   : $depth_copy = $das_adapt->depth($depth);

=cut

sub depth{
   my $key = '_depth';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 group

  Arg [1]   : scalar group (optional)
  Function  : Getter/setter for group meta data
  Returntype: scalar group
  Exceptions: 
  Caller    : 
  Example   : $group_copy = $das_adapt->group($group);

=cut

sub group{
   my $key = '_group';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 stylesheet

  Arg [1]   : scalar stylesheet (optional)
  Function  : Getter/setter for stylesheet meta data
  Returntype: scalar stylesheet
  Exceptions: 
  Caller    : 
  Example   : $stylesheet_copy = $das_adapt->stylesheet($stylesheet);

=cut

sub stylesheet{
   my $key = '_stylesheet';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}

sub score{
   my $key = '_score';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 conftype

  Arg [1]   : scalar conftype (optional)
  Function  : Getter/setter for conftype meta data
  Returntype: scalar conftype
  Exceptions: 
  Caller    : 
  Example   : $conftype_copy = $das_adapt->conftype($conftype);

=cut

sub conftype{
   my $key = '_conftype';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 active

  Arg [1]   : scalar active (optional)
  Function  : Getter/setter for active meta data
  Returntype: scalar active
  Exceptions: 
  Caller    : 
  Example   : $active_copy = $das_adapt->active($active);

=cut

sub active{
   my $key = '_active';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}

#----------------------------------------------------------------------

=head2 description

  Arg [1]   : scalar active (optional)
  Function  : Getter/setter for active meta data
  Returntype: scalar active
  Exceptions: 
  Caller    : 
  Example   : $active_copy = $das_adapt->description($description);

=cut

sub description{
   my $key = '_description';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}

#----------------------------------------------------------------------

=head2 on

  Arg [1]   : scalar on (optional)
  Function  : Getter/setter for on meta data
  Returntype: scalar on
  Exceptions: 
  Caller    : 
  Example   : $on_copy = $das_adapt->on($on);

=cut

sub on{
   my $key = '_on';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 mapping

  Arg [1]   : scalar on (optional)
  Function  : Getter/setter for mapping meta data
  Returntype: scalar mapping
  Exceptions: 
  Caller    : 
  Example   : $mapping_copy = $das_adapt->mapping($mapping);

=cut

sub mapping{
   my $key = '_mapping';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}

#----------------------------------------------------------------------

=head2 enable

  Arg [1]   : scalar enable (optional)
  Function  : Getter/setter for enable meta data
  Returntype: scalar enable
  Exceptions: 
  Caller    : 
  Example   : $on_copy = $das_adapt->enable($enable);

=cut

sub enable{
   my $key = '_enable';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}

#----------------------------------------------------------------------

=head2 dsn

 Title   : help
 Usage   : $obj->dsn("source")
 Function: select a DAS data source
 Returns : 
 Args    : none


=cut

sub help {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_help'} = $value;
    }
    return $self->{'_help'};
}

#----------------------------------------------------------------------

=head2 fasta

  Arg [1]   : scalar fasta (optional)
  Function  : Getter/setter for fasta meta data
  Returntype: scalar fasta
  Exceptions: 
  Caller    : 
  Example   : $fasta_copy = $das_adapt->fasta($fasta);

=cut

sub fasta{
   my $key = '_fasta';
   my $self = shift;
   if( @_ ){ $self->{$key} = shift }
   return $self->{$key};
}


#----------------------------------------------------------------------

=head2 DESTROY

 Title   : DESTROY
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub DESTROY {
   my ($obj) = @_;

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'} = undef;
   }
}



1;
