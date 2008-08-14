=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::SourceParser

=head1 SYNOPSIS

  my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
    -location => 'http://www.dasregistry.org/das',
    -timeout  => 5,
    -proxy    => 'http://proxy.company.com',
  );
  
  my $sources = $parser->fetch_Sources( -species => 'Homo_sapiens' );
  for my $source (@{ $sources }) {
    printf "URL: %s, Description: %s, Coords: %s\n",
            $source->full_url,
            $source->description,
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
use Bio::Das::Lite;

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
               -LOCATION  - URL from which to obtain sources XML. This is
                            usually a DAS registry or server URL, but could be a
                            local path to a directory containing an XML file
                            named "sources?".
               -PROXY     - Web proxy
               -TIMEOUT   - Timeout in seconds (default is 10)
  Example    : my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
                 -location => 'http://www.dasregistry.org/das',
                 -proxy    => 'http://proxy.company.com',
                 -timeout  => 10,
               );
  Example    : my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
                 -location => 'file:///registry', # parses "/registry/sources?"
                 -proxy    => 'http://proxy.company.com',
                 -timeout  => 10,
               );
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DAS::SourceParser
  Exceptions : If no XML or server is specified
  Caller     : general
  Status     : Stable
  
=cut
sub new {
  my $class = shift;
  my ($server, $proxy, $timeout) = rearrange(['LOCATION','PROXY','TIMEOUT'], @_);
  
  $timeout ||= 10;
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl');
  $das->http_proxy($proxy);
  $das->timeout($timeout);
  #$das->dsn($server);
  $das->dsn('http://das.sanger.ac.uk/das');
  
  my $self = {
    'daslite'    => $das,
  };
  bless $self, $class;
  
  return $self;
}

=head2 fetch_Sources

  Arg [..]   : List of named arguments:
               -SPECIES   - (required) The desired species
               -NAME      - (optional) scalar/arrayref of source name filters
  Example:     $arr = $parser->fetch_Sources(
                                             -species => 'Homo_sapiens',
                                             -name    => ['asd', 'atd', 'astd'],
                                            );
  Description: Fetches Source objects for a particular species. The first call
               to this method initiates lazy parsing of the XML, and the results
               are stored.
  Returntype : Arrayref of Bio::EnsEMBL::ExternalData::DAS::Source objects
  Exceptions : If no species is specified, or if there is an error
               contacting the DAS registry/server.
  Caller     : general
  Status     : Stable
  
=cut
sub fetch_Sources {
  my $self = shift;
  my ($f_species, $f_name) = rearrange([ 'SPECIES', 'NAME' ], @_);
  $f_species || throw('No species specified');
  
  # Actual parsing is lazy
  if (!defined $self->{'_sources'}) {
    $self->_parse_server();
  }
  
  my $sources = $self->{'_sources'}->{$f_species}
             || $self->{'_sources'}->{'__NONE__'}
             || [];
  
  # optional name filter
  if ($f_name) {
    $f_name = join '|', @{$f_name} if (ref $f_name eq 'ARRAY');
    $sources = [ grep { $_->dsn =~ /$f_name/ } @{ $sources } ];
  }
  
  return $sources;
}

=head2 _parse_server

  Arg [..]   : none
  Example    : $parser->_parse_server();
  Description: Contacts the configured DAS server via the sources or dsn command
               and parses the results. Populates $self->{'_sources} as a hashref
               of DAS sources, organised by taxonomy ID:
               {
                Homo_sapiens => [ Bio::EnsEMBL::ExternalData::DAS::Source, .. ],
                __NONE__     => [ Bio::EnsEMBL::ExternalData::DAS::Source, .. ],
               }
  Returntype : none
  Exceptions : If there is an error contacting the DAS registry/server.
  Caller     : fetch_Sources
  Status     : Stable

=cut
sub _parse_server {
  my $self = shift;
  
  # NOTE: this method technically supports multiple servers/locations, but
  #       in practice we expect to only be parsing one at a time
  
  # Servers which don't respond to the "sources" command will be attempted via
  # the "dsn" command
  my @attempt_dsn = ();
  my $struct = $self->{'daslite'}->sources();
  
  # Iterate over each server
  while (my ($url, $set) = each %{ $struct }) {
    
    my $status = $self->{'daslite'}->statuscodes($url);
    $set = $set->[0]->{'source'} || [];
    
    # If we get data back from the sources command, parse it
    if ($status =~ /^200/ && scalar @{ $set }) {
      $self->_parse_sources_output($set);
    }
    # Otherwise try the dsn command (which gives poorer metadata)
    else {
      $url =~ s|/sources\??$||;
      push @attempt_dsn, $url;
    }
    
  }
  
  # Run the dsn command on the remaining servers (if any)
  if (scalar @attempt_dsn) {
    
    my $previous = $self->{'daslite'}->dsn;
    $self->{'daslite'}->dsn(\@attempt_dsn);
    $struct = $self->{'daslite'}->dsns();
    $self->{'daslite'}->dsn($previous);
    
    while (my ($url, $set) = each %{ $struct }) {
      
      my $status = $self->{'daslite'}->statuscodes($url);
      $url =~ s|/dsn\??$||;
      $set ||= [];
      
      # If we get data back from the sources command, parse it
      if ($status =~ /^200/ && scalar @{ $set }) {
        $self->_parse_dsn_output($url, $set);
      }
      # Otherwise try the dsn command (which gives poorer metadata)
      else {
        throw("Error contacting DAS server at $url: $status");
      }
    }
  }
  
}

=head2 _parse_sources_output

  Arg [1]    : The URL of the server
  Arg [2]    : Arrayref of sources, each being a hashref
  Example    : $parser->_parse_sources_output($server_url, $sources_set);
  Description: Parses the output of the sources command.
  Returntype : none
  Exceptions : none
  Caller     : _parse_server
  Status     : Stable

=cut
sub _parse_sources_output {
  my ($self, $server_url, $set) = @_;
  
  # Iterate over the <SOURCE> elements
  for my $source (@{ $set }) {
    
    my $title       = $source->{'source_title'};
    my $homepage    = $source->{'source_doc_href'};
    my $description = $source->{'source_description'};
    my $email       = $source->{'maintainer'}[0]{'maintainer_email'};
    
    # Iterate over the <VERSION> elements
    for my $version (@{ $source->{'version'} || [] }) {
      
      my ($url, $dsn);
      for my $cap (@{ $version->{'capability'} || [] }) {
        if ($cap->{'capability_type'} eq 'das1:features') {
          ($url, $dsn) = $cap->{capability_query_uri} =~ m|(.+/das1?)/(.+)/features|;
          last;
        }
      }
      $dsn || next; # this source doesn't support features command
      
      # Now parse the coordinate systems and map to Ensembl's
      # This is the tedious bit, as some things don't map easily
      my %coords = ( '__NONE__' => [] );
      for my $coord (@{ $version->{'coordinates'} || [] }) {
        
        # Extract coordinate details
        my $auth    = $coord->{'coordinates_authority'};
        my $type    = $coord->{'coordinates_source'};
        # Version and species are optional:
        my $version = $coord->{'coordinates_version'} || '';
        my $species = $coord->{'coordinates'};
        $species    =~ s/^$auth(_$version)?,$type,?//;
        $species    =~ s/ /_/g;
        
        if (!$type || !$auth) {
          warning("Unable to parse authority and sequence type for $dsn"); ;# Something went wrong!
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
         
        $species ||= '__NONE__';
        $coords{$species} ||= [];
        push(@{ $coords{$species} }, $coord);
      }
      
      if (!scalar keys %coords) {
        warning("$dsn has no coordinate systems");
      }
      
      # Create the actual sources, one per species plus one for all species
      while (my ($species, $coords) = each %coords) {
        my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
          -url           => $url,
          -dsn           => $dsn,
          -display_label => $title,
          -description   => $description,
          -maintainer    => $email,
          -homepage      => $homepage,
          -coords        => $species eq '__NONE__' ? $coords : [ @{ $coords{'__NONE__'} }, @{ $coords } ] ,
        );
        $self->{'_sources'}{$species} ||= [];
        push(@{ $self->{'_sources'}{$species} }, $source);
      } # end coord loop
      
    } # end version loop
    
  } # end source loop
  
  return undef;
}

=head2 _parse_dsn_output

  Arg [1]    : The URL of the server
  Arg [2]    : Arrayref of sources, each being a hashref
  Example    : $parser->_parse_dsn_output($server_url, $sources_set);
  Description: Parses the output of the dsn command.
  Returntype : none
  Exceptions : none
  Caller     : _parse_server
  Status     : Stable

=cut
sub _parse_dsn_output {
  my ($self, $server_url, $set) = @_;
  
  # Iterate over the <DSN> elements
  for my $source (@{ $set }) {
    
    $self->{'_sources'}{'__NONE__'} ||= [];
    my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
      -url           => $server_url,
      -dsn           => $source->{'source_id'},
      -display_label => $source->{'source'},
      -description   => $source->{'description'},
    );
    push(@{ $self->{'_sources'}{'__NONE__'} }, $source);
    
  }
  
  return undef;
  
}

1;