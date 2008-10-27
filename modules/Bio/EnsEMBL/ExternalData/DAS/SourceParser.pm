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
@EXPORT_OK = qw(%GENE_COORDS @GENE_COORDS %PROT_COORDS @PROT_COORDS);

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::Source;
use Bio::Das::Lite;

our @GENE_COORDS = (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_gene', -label => 'Ensembl Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'entrezgene_acc', -label => 'Entrez Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'hgnc',    -species => 'Homo_sapiens', -label => 'HUGO Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'mgi_acc', -species => 'Mus_musculus', -label => 'MGI Gene Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'mgi',     -species => 'Mus_musculus', -label => 'MGI Gene Symbol' ),
);
our @PROT_COORDS = (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide', -label => 'Ensembl Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'uniprot_peptide', -label => 'UniProt Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ipi_acc', -label => 'IPI Protein Accession' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ipi_id',  -label => 'IPI Protein ID' ),
);
our %GENE_COORDS = map { $_->name => $_ } @GENE_COORDS;
our %PROT_COORDS = map { $_->name => $_ } @PROT_COORDS;

# For compatibility with previous versions of Ensembl:
$PROT_COORDS{'uniprot/swissprot_acc'} = $PROT_COORDS{'uniprot_peptide'};
$PROT_COORDS{'uniprot/sptrembl'}      = $PROT_COORDS{'uniprot_peptide'};

# Intended for occasions when assembly names don't match between DAS and Ensembl
# TODO: get these from a config file of some sort?

our %AUTHORITY_MAPPINGS = (
  'NCBI m' => 'NCBIM',
);

our %TYPE_MAPPINGS = (
  'NT_Contig' => 'supercontig',
);

our %NON_GENOMIC_COORDS = (
  'Gene_ID'          => {
                         'Ensembl'    => $GENE_COORDS{'ensembl_gene'},
                         'HUGO_ID'    => $GENE_COORDS{'hgnc'},
                         'MGI'        => $GENE_COORDS{'mgi_acc'},
                         'MGI_Symbol' => $GENE_COORDS{'mgi'},
                         'Entrez'     => $GENE_COORDS{'entrezgene_acc'},
                        },
  'Protein Sequence' => {
                         'Ensembl'    => $PROT_COORDS{'ensembl_peptide'},
                         'UniProt'    => $PROT_COORDS{'uniprot_peptide'},
                         'IPI'        => $PROT_COORDS{'ipi_acc'},
                         'IPI_ID'     => $PROT_COORDS{'ipi_id'},
                        },
);

=head1 METHODS

=head2 new

  Arg [..]   : List of named arguments:
               -LOCATION  - A URL from which to obtain a list of sources XML.
                            This is usually a DAS registry or server URL, but
                            could be a local path to a directory containing an
                            XML file named "sources?" or "dsn?"
               -PROXY     - A URL to use as an HTTP proxy server
               -NOPROXY   - A list of domains/hosts not to use the proxy for
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
  Exceptions : If no location is specified
  Caller     : general
  Status     : Stable
  
=cut
sub new {
  my $class = shift;
  my ($server, $proxy, $no_proxy, $timeout)
    = rearrange(['LOCATION','PROXY','NOPROXY','TIMEOUT'], @_);
  
  $server  || throw('No DAS server specified');
  
  $timeout ||= 10;
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl');
  $das->dsn($server);
  $das->timeout($timeout);
  
  $das->http_proxy($proxy);
  if ($no_proxy) {
    if ($das->can('no_proxy')) {
      $das->no_proxy($no_proxy);
    } else {
      warning("Installed version of Bio::Das::Lite does not support use of 'no_proxy'");
    }
  }
  
  my $self = {
    'daslite' => $das,
  };
  bless $self, $class;
  
  return $self;
}

=head2 fetch_Sources

  Arg [..]   : List of named arguments:
               -SPECIES    - (optional) scalar or arrayref species name filter
               -NAME       - (optional) scalar or arrayref source name filter
               -LOGIC_NAME - (optional) scalar or arrayref logic_name filter
  Example:     $arr = $parser->fetch_Sources(
                                             -species => 'Homo_sapiens',
                                             -name    => ['asd', 'atd', 'astd'],
                                            );
  Description: Fetches DAS Source objects. The first call to this method
               initiates lazy parsing of the XML, and the results are stored.
               The different filter types supplied to this method are treated as
               a logical AND. Several filters of the same type are logical OR.
  Returntype : Arrayref of Bio::EnsEMBL::ExternalData::DAS::Source objects,
               sorted by label.
  Exceptions : If there is an error contacting the DAS registry/server.
  Caller     : general
  Status     : Stable
  
=cut
sub fetch_Sources {
  my $self = shift;
  my ($f_species, $f_name, $f_logic) = rearrange([ 'SPECIES', 'NAME', 'LOGIC_NAME' ], @_);
  
  # Actual parsing is lazy
  if (!defined $self->{'_sources'}) {
    $self->_parse_server();
  }
  
  my @sources = values %{ $self->{'_sources'} || {} };
  
  my @f_species = !defined $f_species ? ()
                : ref $f_species ? @{ $f_species } : ( $f_species );
  my @f_name    = !defined $f_name ? ()
                : ref $f_name ? @{ $f_name } : ( $f_name );
  my @f_logic   = !defined $f_logic ? ()
                : ref $f_logic ? @{ $f_logic } : ( $f_logic );
  
  # optional species filter
  if ( scalar @f_species ) {
    info('Filtering by species');
    @sources = grep { my $source = $_; grep { $source->matches_species( $_ ) } @f_species } @sources;
  }
  
  # optional name filter
  if ( scalar @f_name ) {
    info('Filtering by name');
    @sources = grep { my $source = $_; grep { $source->matches_name( $_ ) } @f_name  } @sources;
  }
  
  # optional logic name filter
  if ( scalar @f_logic ) {
    info('Filtering by logic_name');
    @sources = grep { my $source = $_; grep { $source->logic_name eq $_ } @f_logic  } @sources;
  }
  
  return [sort { lc $a->label cmp lc $b->label } @sources];
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
  my @success = ();
  my $struct = $self->{'daslite'}->sources();
  
  # Iterate over each server
  while (my ($url, $set) = each %{ $struct }) {
    
    my $status = $self->{'daslite'}->statuscodes($url);
    $set = $set->[0]->{'source'} || [];
    
    # If we get data back from the sources command, parse it
    if ($status =~ /^200/ && scalar @{ $set }) {
      $self->_parse_sources_output($url, $set);
      $url =~ s|/sources\??$||;
      push @success, $url;
    }
    
  }
  
  my @previous = @{ $self->{'daslite'}->dsn || [] };
  my @failed = grep { my $url = $_; !grep { $_ eq $url } @success } @previous;
  
  # Run the dsn command on the remaining servers (if any)
  if (scalar @failed) {
    
    $self->{'daslite'}->dsn(\@failed);
    $struct = $self->{'daslite'}->dsns();
    $self->{'daslite'}->dsn(\@previous);
    
    while (my ($url, $set) = each %{ $struct }) {
      
      my $status = $self->{'daslite'}->statuscodes($url);
      $url =~ s|/dsn\??$||;
      $set ||= [];
      
      # If we get data back from the sources command, parse it
      if ($status !~ /^200/) {
        throw("Error contacting DAS server '$url' : $status");
      } elsif (scalar @{ $set }) {
        $self->_parse_dsn_output($url, $set);
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
      
      my $version_uri = $version->{'version_uri'};
      
      # Now parse the coordinate systems and map to Ensembl's
      # This is the tedious bit, as some things don't map easily
      my @coords = ( );
      for my $coord (@{ $version->{'coordinates'} || [] }) {
        
        # Extract coordinate details
        my $auth    = $coord->{'coordinates_authority'};
        my $type    = $coord->{'coordinates_source'};
        # Version and species are optional:
        my $version = $coord->{'coordinates_version'} || '';
        #my $taxid   = $coord->{'coordinates_taxid'}   || '';
        my $species = $coord->{'coordinates'}; # element CDATA
        $species    =~ s/^$auth(_$version)?,$type,?//;
        $species    =~ s/ /_/g;
        
        if (!$type || !$auth) {
          warning("Unable to parse authority and sequence type for $dsn ; skipping"); # Something went wrong!
          next;
        }
        
        if ( my $coord = $self->_parse_coord_system( $type, $auth, $version, $species ) ) {
          push @coords, $coord;
        }
      }
      
      if (!scalar @coords) {
        info("$dsn has no supported coordinate systems; skipping");
        next;
      }
      
      # Create the actual source
      my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
        -logic_name    => $version_uri,
        -url           => $url,
        -dsn           => $dsn,
        -label         => $title,
        -description   => $description,
        -maintainer    => $email,
        -homepage      => $homepage,
        -coords        => \@coords,
      );
      
      $self->{'_sources'}{$source->full_url} ||= $source;
      
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
    
    my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
      -url           => $server_url,
      -dsn           => $source->{'source_id'},
      -label         => $source->{'source'},
      -description   => $source->{'description'},
    );
    
    $self->{'_sources'}{$source->full_url} ||= $source;
  }
  
  return undef;
  
}

sub _parse_coord_system {
  my ( $self, $type, $auth, $version, $species ) = @_;
  
  $type = $TYPE_MAPPINGS{$type}      || $type; # handle fringe cases
  $auth = $AUTHORITY_MAPPINGS{$auth} || $auth; # handle fringe cases
  
  # Wizardry to convert to Ensembl coord_system
  if ($type =~ m/^chromosome|clone|contig|scaffold|supercontig$/i) {
    # seq_region coordinate systems have ensembl equivalents
    if ( !$species ) {
      warning("Genomic coordinate system has no species: $type $auth$version");
      return;
    }
    my $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
      -name    => lc $type,
      -version => $auth.$version,
      -species => $species
    );
    return $cs;
  }
  
  # otherwise use a 'fake' coordinate system like 'ensembl_gene'
  my $cs = $NON_GENOMIC_COORDS{$type}{$auth};
  if ( !$cs ) {
    info("Coordinate system not supported: $auth $type");
    return;
  }
  if ( $cs->species ne $species ) {
    $cs = $cs->new( -name    => $cs->name,
                    -version => $cs->version,
                    -species => $species,
                    -label   => $cs->label );
  }
  
  return $cs;
}

1;