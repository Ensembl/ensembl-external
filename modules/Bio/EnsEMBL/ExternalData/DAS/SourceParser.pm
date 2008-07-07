=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::SourceParser

=head1 SYNOPSIS

  my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(-xml => $xml);
  
  OR:
  
  my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
    -server  => $filename || 'http://www.dasregistry/das1',
    -timeout => 5, # default
    -proxy   => 'http://proxy.company.com',
  );
  
  my $sources = $parser->fetch_Sources( -taxid => 9606 );
  for my $source (@{ $sources }) {
    printf "URL: %s, Description: %s, Coords: %s\n",
            $source->full_url,
            $source->description;,
            join '; ', @{ $source->coord_systems };
  }

=head1 DESCRIPTION

Parses XML produced by the 'sources' DAS command, creating object
representations of each source.

=head1 AUTHOR

Andy Jenkinson <aj@ebi.ac.uk>

=cut
package Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use strict;
use warnings;
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw($EXTRA_COORDS);

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::Source;

# Intended for occasions when assembly names don't match between DAS and Ensembl
# e.g. NCBIm37 -> NCBIM37
# TODO: get these from a config file of some sort?
our $ASSEMBLY_MAPPINGS = {
  'NCBI m34' => 'NCBIM34',
  'NCBI m35' => 'NCBIM35',
};

our $TYPE_MAPPINGS = {
  'NT_Contig'        => 'supercontig',
  'Gene_ID'          => 'gene',
  'Protein Sequence' => 'peptide',
};

=head1 METHODS

=head2 new

  Arg [..]   : List of named arguments:
               -XML       - XML string to parse for sources
               OR
               -LOCATION  - URL/file from which to obtain XML
               -PROXY     - Web proxy
               -TIMEOUT   - Timeout in seconds (default is 5)
  Example 1  : my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
                 -xml => '<SOURCES ....',
               );
  Example 2  : my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
                 -server  => 'http://www.dasregistry.org/das',
                 -proxy   => 'http://proxy.company.com',
                 -timeout => 10,
               );
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DAS::SourceParser
  Exceptions : If no XML or server is specified
  Caller     : general
  Status     : Stable
  
=cut
sub new {
  my $class = shift;
  my ($xml, $server, $proxy, $timeout) = rearrange([ 'XML', 'LOCATION', 'PROXY', 'TIMEOUT' ], @_);
  
  $timeout ||= 5;
  my $self = {
    '_xml'    => $xml,
  };
  bless $self, $class;
  
  if (!$xml) {
    if ($server) {
      $self->{'_xml'} = &_fetch_XML($server, $proxy, $timeout);
    } else {
      throw('No server or XML specified');
    }
  }
  
  return $self;
}

=head2 fetch_Sources

  Arg [..]   : List of named arguments:
               -TAXID     - The taxonomy ID of the desired species
               -NAME      - (optional) scalar/arrayref of source name filters
  Example:     $arr = $parser->fetch_Sources(
                                             -taxid => 9606,
                                             -name  => ['asd', 'atd', 'astd'],
                                            );
  Description: Fetches Source objects for a particular species. The first call
               to this method initiates lazy parsing of the XML, and the results
               are stored.
  Returntype : Arrayref of Bio::EnsEMBL::ExternalData::DAS::Source objects
  Exceptions : If no taxonomy ID is specified
  Caller     : general
  Status     : Stable
  
=cut
sub fetch_Sources {
  my $self = shift;
  my ($f_taxid, $f_name) = rearrange([ 'TAXID', 'NAME' ], @_);
  $f_taxid || throw('No taxonomy ID specified');
  
  # XML parsing is lazy
  if (!defined $self->{'_sources'}) {
    $self->{'_sources'} = &_parse_XML($self->{'_xml'});
  }
  
  my $sources = $self->{'_sources'}->{$f_taxid}
             || $self->{'_sources'}->{'__ALL__'};
  
  # optional name filter
  if ($f_name) {
    $f_name = join '|', @{$f_name} if (ref $f_name eq 'ARRAY');
    $sources = [ grep { $_->dsn =~ /$f_name/ } @{ $sources } ];
  }
  
  return $sources;
}

=head1 SUBROUTINES

=head2 _parse_XML

  Args [1]   : XML string to parse
  Example    : $hash = $parser->_parse_XML($xml);
  Description: Creates Source objects by parsing XML.
  Returntype : hashref of taxid => Bio::EnsEMBL::ExternalData::DAS::Source arrayref
  Exceptions : If no XML is specified
  Caller     : general
  Status     : Stable

=cut
sub _parse_XML {
  my $xml  = shift;
  $xml    || throw('No XML to parse');
  
  my %sources = ();
  
  # Split by source
  for my $s_xml (split /<SOURCE\s/, $xml) {
    my ($av_xml) = $s_xml =~ m|(<VERSION.+</VERSION>)|s; # all the versions
    $av_xml || next;
    my ($title) = $s_xml =~ m|title="(.*?)"|;
    my ($homepage) = $s_xml =~ m|doc_href="(.*?)"|;
    my ($description) = $s_xml =~ m|description="(.*?)"|;
    my ($email) = $s_xml =~ m|<MAINTAINER email="(.*?)"|;
    
    # Split by version
    for my $v_xml (split m|</VERSION>|, $av_xml) {
      
      # Skip sources without support for features command
      if ($v_xml !~ m|type="das1:features"|) {
        next;
      }
      
      # Extract URL and DSN
      my ($url, $dsn) = $v_xml =~ m|query_uri="([^>]+/das1?)/([^>]+)/features"|;
      if (!$dsn || !$url) {
        warning("Unable to parse dsn and URL"); # Something went wrong!
        next;
      }
      
      info("Parsing $dsn");
      
      # Now parse the coordinate systems and map to Ensembl's
      my %coords = ( '__ALL__' => [] );
      ($v_xml) = $v_xml =~ m|(<COORDINATES.+</COORDINATES>)|s; # all the coordinates
      for my $c_xml (split m|</COORDINATES>|, $v_xml||q()) {
        
        # Extract coordinate details
        my ($auth)    = $c_xml =~ m|authority="(.*?)"|;
        my ($type)    = $c_xml =~ m|source="(.*?)"|;
        my ($taxid)   = $c_xml =~ m|taxid="(.*?)"|;   # optional
        my ($version) = $c_xml =~ m|version="(.*?)"|; # optional
        
        if (!$type || !$auth) {
          warning("Unable to parse authority and sequence type for $dsn");warn $c_xml ;# Something went wrong!
          next;
        }
        $type = $TYPE_MAPPINGS->{$type} || lc $type; # handle fringe cases
        
        # Wizardry to convert to Ensembl coord_system
        my $coord;
        if ($type =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
          # seq_region coordinate systems have ensembl equivalents
          $version ||= q();
          $version = $auth.$version;
          $version = $ASSEMBLY_MAPPINGS->{$version} || $version; # handle fringe cases
          $coord = "$type:$version";
        } else {
          # otherwise use a 'fake' coordinate system like 'ensembl_gene'
          $coord = lc $auth.q(_).$type;
        }
        
        if ($taxid) {
          $coords{$taxid} ||= [@{ $coords{'__ALL__'} }];
          push(@{ $coords{$taxid} }, $coord);
        } else {
          for (values %coords) {
            push(@{ $_ }, $coord);
          }
        }
      }
      
      if (!scalar keys %coords) {
        warning("$dsn has no coordinate systems");
      }
      
      # Create the actual sources, one per species plus one for all species
      while (my ($taxid, $coords) = each %coords) {
        @{ $coords }     ||  next;
        $sources{$taxid} ||= [];
        my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
          -label       => $title || $dsn,
          -url         => $url,
          -dsn         => $dsn,
          -maintainer  => $email,
          -homepage    => $homepage || $url,
          -description => $description,
          -coords      => $coords,
        );
        push(@{ $sources{$taxid} }, $source);
      }
    }
  }
  
  return \%sources;
}

# Server can be any server supporting the sources command (e.g. registry)
# Or can be a file
=head2 _fetch_XML

  Args [1]   : Location, either a filename or URL
  Args [2]   : (optional) proxy URL
  Args [3]   : (optional) timeout
  Example    : _fetch_XML($location, $proxy, $timeout);
  Description: Retrieves XML from a local (file) or remote (URL) source.
  Returntype : None
  Exceptions : If no server/file is specified
  Caller     : general
  Status     : Stable

=cut
sub _fetch_XML {
  my $server  = shift;
  my $proxy   = shift;
  my $timeout = shift;
  
  $server || throw('No server specified');
  
  # Can be a file, in which case we expect it to exist...
  if (-e $server) {
    info("Using local DAS registry XML file: $server");
    my $fh;
    open $fh, '<', $server;
    local $/ = undef;
    my $xml = <$fh>;
    close $fh;
    return $xml;
  }
  
  info("Using remote DAS registry URL: $server");
  require LWP::UserAgent;
  if ($server !~ m|/sources/?$|) {
    $server = $server =~ m|/$| ? $server.'sources' : $server.'/sources';
  }
  
  my $ua = LWP::UserAgent->new(
    -agent   => 'Ensembl',
    -timeout => $timeout,
  );
  $ua->proxy(['http','https'], $proxy) if $proxy;
  
  my $response = $ua->get($server);
  if ($response->is_success) {
    return $response->content;
  }
  
  warning("Unable to contact $server: ".$response->status_line);
  return undef;
}

1;