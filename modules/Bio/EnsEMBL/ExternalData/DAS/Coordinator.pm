=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Coordinator

=head1 SYNOPSIS

  # Instantiate with a list of Bio::EnsEMBL::ExternalData::DAS::Source objects:
  my $c = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(-sources => $list);
  
  # Fetch by slice
  my $struct = $c->fetch_Features( $slice );
  
  for my $logic_name ( keys %{ $struct } ) {
  
    my $errors     = $struct->{$logic_name}{'errors'    }; # string array
    
    # Bio::EnsEMBL::ExternalData::DAS::? objects:
    my $source     = $struct->{$logic_name}{'source'    }; # Source
    my $features   = $struct->{$logic_name}{'features'  }; # Feature array
    my $stylesheet = $struct->{$logic_name}{'stylesheet'}; # Stylesheet
    
    printf "%s: %d errors, %d features\n",
           $source->title,
           scalar @{ $errors   },
           scalar @{ $features };
  }
  
  # Fetch by gene
  my $struct = $c->fetch_Features( $gene );
  
  # Fetch by protein
  my $struct = $c->fetch_Features( $translation );
  
  # Feature ID filtering
  my $struct = $c->fetch_Features( $slice, feature => 'xyz1234' );
  
  # Type ID and Group ID filtering
  my $struct = $c->fetch_Features( $slice, group => 'xyz', type => 'foo' );

=head1 DESCRIPTION

Given a set of DAS::Source objects and a target object such as a Slice or
Translation, will simultaneously perform all DAS requests and map the features
onto the target object.

=cut
package Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use strict;
use warnings;

use POSIX qw(ceil);
use Bio::EnsEMBL::Mapper;
use Bio::Das::Lite;

use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::GenomicMapper;
use Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper;
use Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper;
use Bio::EnsEMBL::ExternalData::DAS::Feature;
use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;
use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw info warning);

our %ORI_NUMERIC = (
   1    =>  1,
  '+'   =>  1,
  -1    => -1,
  '-'   => -1,
);

# This variable determines the supported xref mapping paths.
# The first level key is the xref coordinate system.
# The first level value is a hashref, containing:
#   'predicate':   a code block to filter xref's of the relevant type
#   'transformer': a code block to obtain the DAS segment ID
#
our %XREF_PEPTIDE_FILTERS = (
  'uniprot_peptide' => {
    'predicate'   => sub { $_[0]->dbname eq 'Uniprot/SPTREMBL' || $_[0]->dbname eq 'Uniprot/SWISSPROT' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'ipi_peptide' => {
    'predicate'   => sub { $_[0]->dbname eq 'IPI' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'entrez_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'EntrezGene' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'mgi_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'MGI' },
    'transformer' => sub { my $id = $_[0]->primary_id; $id =~ s/\://; $id; },
  },
);

our %XREF_GENE_FILTERS = (
  'hugo_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'HGNC' },
    'transformer' => sub { $_[0]->primary_id },
  },
);

our %NON_GENOMIC_COORDS = map { $_->name => $_ } (
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_gene' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'entrez_gene' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'mgi_gene', -species => 'Mus_musculus', -label => 'MGI Gene' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'hugo_gene', -species => 'Homo_sapiens', -label => 'HUGO Gene' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'uniprot_peptide', -label => 'UniProt Peptide' ),
  Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ipi_peptide', -label => 'IPI Peptide' ),
);

=head2 new

  Arg [..]   : List of named arguments:
               -SOURCES     - Arrayref of Bio::EnsEMBL::DAS::Source objects.
               -PROXY       - A URL to use as an HTTP proxy server
               -NOPROXY     - A list of domains/hosts to not use the proxy for
               -TIMEOUT     - The request timeout, in seconds
               -GENE_COORDS - Override the coordinate system representing genes
               -PROT_COORDS - Override the coordinate system representing proteins
  Description: Constructor
  Returntype : Bio::EnsEMBL::DAS::Coordinator
  Exceptions : none
  Caller     : 
  Status     : 

=cut
sub new {
  my $class = shift;
  
  my ($sources, $proxy, $no_proxy, $timeout, $gene_cs, $prot_cs)
    = rearrange(['SOURCES','PROXY', 'NOPROXY', 'TIMEOUT',
                 'GENE_COORDS', 'PROT_COORDS'], @_);
  
  $sources = [$sources] if ($sources && !ref $sources);
  
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl');
  $das->timeout($timeout);
  $das->caching(0);
  $das->http_proxy($proxy);
  
  # Bio::Das::Lite support for no_proxy added around September 2008
  if ($no_proxy) {
    if ($das->can('no_proxy')) {
      $das->no_proxy($no_proxy);
    } else {
      warning("Installed version of Bio::Das::Lite does not support use of 'no_proxy'");
    }
  }
  
  $gene_cs ||= $NON_GENOMIC_COORDS{'ensembl_gene'};
  $prot_cs ||= $NON_GENOMIC_COORDS{'ensembl_peptide'};
  
  my $self = {
    'sources' => $sources,
    'daslite' => $das,
    'gene_cs' => $gene_cs,
    'prot_cs' => $prot_cs,
    'objects' => {},
  };
  bless $self, $class;
  return $self;
}

=head2 fetch_Features

  Arg [1]    : Bio::EnsEMBL::Object $root_obj - the query object (e.g. Slice, Gene)
  Arg [2]    : (optional) hash of filters:
                  maxbins - the maximum available "rendering space" for features
                            NOTE this is only passed to the server, it is not
                                 guaranteed to be honoured
                  feature - the feature ID
                  type    - the type ID
                  group   - the group ID
  Description: Fetches DAS features  for a given Slice, Gene or Translation
  Example    : $hashref = $c->fetch_Features( $slice, type => 'mytype' );
  Returntype : A hash reference containing Bio::...::DAS::Feature and
               Bio::...::DAS::Stylesheet objects:
               {
                'http.../das' => {
                                  'source'     => $source_object,
                                  'errors'     => [
                                                   'No features',
                                                   'No relevant features',
                                                   'Error fetching...',
                                                  ],
                                  'stylesheet' => $style1,
                                  'features'   => [
                                                   $feat1,
                                                   $feat2,
                                                  ],
                                 }
               }
  Exceptions : Throws if the object is not supported
  Caller     : 
  Status     : 

=cut
sub fetch_Features {
  my ( $self, $target_obj ) = splice @_, 0, 2;
  my %filters = @_; # maxbins, feature, type, group
  
  # TODO: review this structure that is returned, would we prefer to split by
  # segment ID? We don't always know it before we parse the feature though (e.g.
  # when querying by feat ID). Also stylesheet errors aren't segment-specific
  
  my ( $target_cs, $target_segment, $slice, $gene, $prot );
  if ( $target_obj->isa('Bio::EnsEMBL::Gene') ) {
    $slice = $target_obj->slice;
    $gene = $target_obj;
    $target_cs = $slice->coord_system; # actually want features relative to the slice
    $target_segment = $target_obj->stable_id;
  } elsif ( $target_obj->isa('Bio::EnsEMBL::Slice') ) {
    $slice = $target_obj;
    $target_cs = $target_obj->coord_system;
    $target_segment = sprintf '%s:%s,%s', $target_obj->seq_region_name, $target_obj->start, $target_obj->end;
  } elsif ( $target_obj->isa('Bio::EnsEMBL::Translation') ) {
    $prot = $target_obj;
    $target_cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide' );
    $target_segment = $target_obj->stable_id;
  } else {
    throw('Unsupported object type: '.$target_obj);
  }
  
  my %coords = ();
  my $final = {};
  
  #==========================================================#
  #      First sort the sources into coordinate systems      #
  #==========================================================#
  
  for my $source (@{ $self->{'sources'} }) {
    
    if (! scalar @{ $source->coord_systems } ) {
      warning($source->key.' has '.scalar @{ $source->coord_systems }.' coord systems');
      next;
    }
    
    $final->{ $source->logic_name } = { 'features'   => [],
                                        'errors'     => [],
                                        'stylesheet' => undef };
    
    # Query in all compatible coordinate systems
    # Note that 
    for my $source_cs (@{ $source->coord_systems }) {
      
      # Check the coordinate system is the correct species (if it has one)
      if (my $source_species = $source_cs->species) {
        $source_species eq $target_obj->adaptor->db->species || next;
      }
      
      # The coordinate system name doesn't need species in it because we have
      # just checked it is species-compatible - we treat them the same from now
      #Êon. That is, Ensembl,Gene_ID == Ensembl,Gene_ID,Homo sapiens.
      my $cs_name = $source_cs->name . ' ' . $source_cs->version;
      
      # Sort sources by coordinate system
      if ( !$coords{$cs_name} ) {
        # Do a lot of funky stuff to get the query segments, and build up
        # mappers at the same time
        my $segments = $self->_get_Segments( $source_cs, $target_cs,
                                             $slice, $gene, $prot);
        
        $coords{ $cs_name } = { 'sources'      => {},
                                'coord_system' => $source_cs,
                                'segments'     => $segments   };
      }
      
      $coords{ $cs_name }{'sources'}{$source->full_url} = $source;
    }
  }
  
  #==========================================================#
  #   Parallelise the requests for each coordinate system    #
  #==========================================================#
  
  my $daslite = $self->{'daslite'};
  
  # Split the requests that will be performed by coordinate system, i.e. parallelise
  # requests for segments that are from the same coordinate system
  while (my ($coord_name, $coord_data) = each %coords) {
    my $segments = $coord_data->{'segments'};
    
    # Either the mapping isn't supported, or nothing maps to the region we're
    # interested in.
    if (!scalar @{ $segments }) {
      info("No segments found for $coord_name");
      next;
    }
    
    info("Querying with @{$segments} for $coord_name");
    $daslite->dsn( [keys %{ $coord_data->{'sources'} }] );
    
    my $response;
    my $statuses;
    
    #==========================================================#
    #             Get features for all DAS sources             #
    #==========================================================#
    
    ########
    # If we are looking for a specific feature, try quering the server(s) for
    # it specifically first
    #
    if ( $filters{feature} ) {
      $response = $daslite->features( { 'feature_id' => $filters{feature} } ); # returns a hashref
      $statuses = $daslite->statuscodes();
      
      # Find out if it worked (has to work for EVERY source)
      while (my ($url, $features) = each %{ $response }) {
        my $status = $statuses->{$url};
        if ($status !~ m/^200/) {
          undef $response;
          last;
        } elsif (!defined $features || ref $features ne 'ARRAY' || !scalar @{ $features }) {
          undef $response;
          last;
        }
      }
    }
    
    ########
    # If this didn't work, or we are running a normal query, use the segments
    #
    if ( !$response ) {
      # Build a query array for each segment, with the optional filter
      # parameters. Note that not all DAS servers implement these filters. If
      # they do, great, but we still have to filter on the client side later.
      my @features_query = map {
        {
         'segment'    => $_,
         'type'       => $filters{type},
         'group_id'   => $filters{group},
         'maxbins'    => $filters{maxbins},
        }
      } @{ $segments };
      
      $response = $daslite->features( \@features_query ); # returns a hashref
      $statuses = $daslite->statuscodes();
    }
    
    #========================================================#
    #               Check and map the features               #
    #========================================================#
    my @sources_with_data = ();
    
    while (my ($url, $features) = each %{ $response }) {
      info("*** $url ***");
      my $status = $statuses->{$url};
      
      # Parse the segment from the URL
      # Should be one URL for each source/query combination
      $url =~ s|/features\?.*$||;
      my $source = $coord_data->{'sources'}{$url};
      
      $final->{$source->logic_name}{'source'} = $source;
      
      # TODO: is this error handling OK?
      # DAS source generated an error
      if ($status !~ m/^200/) {
        push @{ $final->{$source->logic_name}{'errors'} }, "Error fetching features - $status";
      }
      # DAS source has no features in the region of interest
      elsif (!defined $features || ref $features ne 'ARRAY' || !scalar @{ $features }) {
        push @{ $final->{$source->logic_name}{'errors'} }, 'No features';
      }
      # We got "something" at least...
      else {
        
        ########
        # Convert into the query coordinate system if applicable
        #
        $features = $self->map_Features($features,
                                        $coord_data->{'coord_system'},
                                        $target_cs,
                                        $slice,
                                        %filters);
        
        # We got something useful
        if (scalar @{ $features }) {
          push @{ $final->{$source->logic_name}{'features'} }, @{ $features };
          push @sources_with_data, $source->full_url; # for retrieving stylesheets
        }
        # Either we couldn't map the features, or nothing matched the filters
        else {
          push @{ $final->{$source->logic_name}{'errors'} }, 'No relevant features';
        }
        
      }
      
    }
    
    #==========================================================#
    #         Get stylesheets for the sources with data        #
    #==========================================================#
    
    $daslite->dsn( @sources_with_data );
    $response = $daslite->stylesheet();
    $statuses = $daslite->statuscodes();
    
    while (my ($url, $styledata) = each %{ $response }) {
      
      my $status = $statuses->{$url};
      $url =~ s|/stylesheet\?$||;
      my $source = $coord_data->{'sources'}{$url};
      
      # DAS source generated an error
      if ( $status !~ m/^200/ ) {
        push @{ $final->{$source->logic_name}{'errors'} }, "Error fetching stylesheet - $status";
      }
      # DAS source has no stylesheet
      elsif (!defined $styledata || ref $styledata ne 'ARRAY' || !scalar @{ $styledata }) {
        # This code intentionally blank
      }
      # We have stylesheet data
      else {
        $final->{$source->logic_name}{'stylesheet'} = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new( $styledata->[0] );
      }
    }
    
  }
  
  return $final;
}

# Returns: new arrayref with features
sub map_Features {
  my ( $self, $features, $source_cs, $to_cs, $slice ) = splice @_, 0, 5;
  my %filters = @_; # feature, type, group
  
  # TODO: implement maxbins filter??
  my $filter_f = $filters{feature};
  my $filter_t = $filters{type};
  my $filter_g = $filters{group};
  # If filtering we're more likely to have a small region, so it's better to
  # make 4 tests when filtering and 1 when not than always make 3 tests.
  # The big question is, is it better to test each filter is enabled than to
  # just preprocess in an extra iteration? I suspect the former.
  my $nofilter = !$filter_f && !$filter_t && !$filter_g;
  
  # Code block to build a feature object from raw hash
  my $build_Feature = sub {
    my $f = shift;
    $f = Bio::EnsEMBL::ExternalData::DAS::Feature->new( $f );
    # Where target coordsys is genomic, make a slice-relative feature
    # TODO: I THINK THIS IS BREAKING THE FEATURES, AS NOT ALL INFO IS COPIED.
    #       NEED TO READDRESS HOW THIS IS DONE. NOTE THAT DAS FEATURES ARRIVE
    #       IN SEQ_REGION_SLICE COORDS BUT NEED TO END UP RELATIVE TO SLICE.
    if ($slice && 0) {
      $f->slice($slice->seq_region_Slice);
      $f = $f->transfer($slice);
    }
    return $f;
  };
  
  # Code block to apply optional filters
  my $filter_Feature = sub {
    my $f = shift;
    # Test type first, because this is the more likely filter for large regions
    # where efficiency matters most
    if ( $filter_t ) {
      $f->{'type_id'} eq $filter_t || return 0;
    }
    if ( $filter_f ) {
      $f->{'feature_id'} eq $filter_f || return 0;
    }
    if ( $filter_g ) {
      return 0 unless grep { $_->{'group_id'} eq $filter_g } @{ $f->{'group'}||[] };
    }
    return 1;
  };
  
  # As part of the feature parsing we need to do some converting and filtering.
  # We could do this in a separate loop before doing any mapping, but this adds
  # an extra iteration step which inefficient (especially for large numbers of
  # features). So we duplicate a bit of code.
  if ( $source_cs->equals( $to_cs ) ) {
    my @new_features = ();
      
    for my $f ( @{ $features } ) {
      
      if ( $nofilter || &$filter_Feature( $f ) ) {
        $f->{'strand'} = $ORI_NUMERIC{$f->{'orientation'} || '+'} || 1; # Convert to Ensembl-style (numeric) strand
        push @new_features, &$build_Feature( $f ); # Build object
      }
      
    }
    
    return \@new_features;
  }
  
  # May need multiple mapping steps to reach the target coordinate system
  # This loop works by undefining $source_cs, the redefining it when we know
  # which coordinate system the mapper is mapping to
  while ( $source_cs && !$source_cs->equals($to_cs) ) {
    
    info('Beginning mapping from '.$source_cs->name);
    
    my @this_features = @{ $features };
    my $mappers = $self->{'mappers'}{$source_cs->name}{$source_cs->version||''};
    $features  = [];
    $source_cs = undef;
    
    my $positional_mapping_errors = 0;
    
    # Map the current set of features to the next coordinate system
    for my $f ( @this_features ) {
      
      $nofilter || &$filter_Feature( $f ) || next;
      
      my $strand = $f->{'strand'};
      if (!defined $strand) {
        $strand = $f->{'strand'} = $ORI_NUMERIC{$f->{'orientation'} || '+'} || 1;
      }
      
      # It doesn't matter what coordinate system non-positional features come
      # from, they are always included and don't need mapping
      if ($f->{'start'} == 0 && $f->{'end'} == 0) {
        push @{ $features }, $f;
        next;
      }
      
      my $segid  = $f->{'segment_id'};
      
      # Get new coordinates for this feature
      my $mapper = $mappers->{$segid};
      if (!$mapper) {
        $positional_mapping_errors++;
        next;
      }
      $source_cs = $mapper->{'to_cs'} || throw('Mapper maps to unknown coordinate system');
      my @coords = $mapper->map_coordinates($segid,
                                            $f->{'start'},
                                            $f->{'end'},
                                            $strand,
                                            'from');
      
      # Create new features from the mapped coordinates
      for my $c ( @coords ) {
        $c->isa('Bio::EnsEMBL::Mapper::Coordinate') || next;
        my %new = %{ $f };
        $new{'segment_id'} = $c->id;
        $new{'start'     } = $c->start;
        $new{'end'       } = $c->end;
        $new{'strand'    } = $c->strand;
        
        # If this is the final step, convert to Ensembl Feature
        if ( $source_cs->equals( $to_cs ) ) {
          push @{ $features }, &$build_Feature( \%new );
        }
        else {
          push @{ $features }, \%new;
        }
      }
      
    }
    
    if ($positional_mapping_errors) {
      warning("$positional_mapping_errors positional features could not be mapped");
    }
  }
  
  return $features;
}

# Supports mappings:
#   location-based to location-based
#   location-based to protein-based
#   protein-based to location-based
#   protein-based to protein-based
#   gene-based to location-based
#   gene-based to protein-based
#   xref-based to location-based
#   xref-based to protein-based
#   xref-based to gene-based
#
# Coordinate system definitions:
#   location-based  == chromosome|clone|contig|scaffold|supercontig
#   protein-based   == $self->{prot_cs} (ensembl_peptide)
#   gene-based      == $self->{gene_cs} (ensembl_gene)
#   xref-based      == uniprot_peptide|entrez_gene... (see %XREF_PEPTIDE_FILTERS)
sub _get_Segments {
  my $self = shift;
  my $from_cs = shift; # the "foreign" source coordinate system 
  my $to_cs = shift;   # the target coordsys that mapped objects will be converted to
  my ($slice, $gene, $prot) = @_;
  #warn sprintf "Getting mapper for %s -> %s", $from_cs->name, $to_cs->name;
  
  my %mappers = ();
  my @segments = ();
  
  # There are several different Mapper implementations in the API to convert
  # between various coordinate systems: AssemblyMapper, TranscriptMapper,
  # IdentityXref. For DAS, we often need to convert across the different realms
  # these mappers serve, such as chromosome:NCBI35 -> peptide which requires an
  # intermediary NCBI35 -> NCBI36 step. Unfortunately, the different mappers all
  # work in different ways and have different interfaces and limitations.
  #
  # For example, AssemblyMapper and TranscriptMapper use custom methods rather
  # than the standard API 'map_coordinates', IdentityXref uses custom
  # 'external_id' and 'ensembl_id' identifiers for the regions it is mapping
  # between, and all name the coordinate systems differently. These differences
  # mean the different mappers cannot be strung together, so this module uses
  # wrappers in order to achieve this.
  
  # Mapping to slice-relative coordinates
  if ( $to_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/ ) {
    
    $slice || throw('Trying to convert to slice coordinates, but no Slice provided');
    $slice->coord_system->equals($to_cs) || throw('Provided slice is not in target coordinate system');
    
    # Mapping from a slice-based coordinate system
    if ( $from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/ ) {
      
      # No mapping needed
      if ( $from_cs->equals( $to_cs ) ) {
        push @segments, sprintf '%s:%s,%s', $slice->seq_region_name, $slice->start, $slice->end;
      }
      
      else {
        # Wrapper for AssemblyMapper:
        my $mapper = Bio::EnsEMBL::ExternalData::DAS::GenomicMapper->new(
          'from', 'to', $from_cs, $to_cs,
          $slice->adaptor->db->get_AssemblyMapperAdaptor->fetch_by_CoordSystems($from_cs, $to_cs)
        );
        
        # Map backwards to get the query segments
        my @coords = $mapper->map_coordinates($slice->seq_region_name,
                                              $slice->start,
                                              $slice->end,
                                              $slice->strand,
                                              'to');
        for my $c ( @coords ) {
          $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$c->id} ||= $mapper;
          push @segments, sprintf '%s:%s,%s', $c->id, $c->start, $c->end;
        }
      }
    }
    
    # Mapping from ensembl_gene to slice
    elsif ( $from_cs->equals( $self->{'gene_cs'} ) ) {
      for my $g ( defined $gene ? ($gene) : @{ $slice->get_all_Genes }) {
        # Genes are already definitely relative to the target slice, so don't need to do any assembly mapping
        my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to', $from_cs, $to_cs);
        #warn "ADDING ".$g->stable_id." ".$g->strand;
        $mapper->add_map_coordinates(
          $g->stable_id,           1,                    $g->length, $g->seq_region_strand,
          $slice->seq_region_name, $g->seq_region_start, $g->seq_region_end
        );
        $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$g->stable_id} = $mapper;
        push @segments, $g->stable_id;
      }
    }
    
    # Mapping from ensembl_peptide to slice
    elsif ( $from_cs->equals( $self->{'prot_cs'} ) ) {
      for my $tran (@{ $slice->get_all_Transcripts }) {
        my $p = $tran->translation || next;
        $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$p->stable_id} ||= Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper->new('from', 'to', $from_cs, $to_cs, $tran);
        push @segments, $p->stable_id;
      }
    }
    
    # Mapping from translation-mapped xref to slice
    elsif ( my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name} ) {
      # Mapping path is xref -> ensembl_peptide -> slice
      my $mid_cs = $self->{'prot_cs'};
      for my $tran (@{ $slice->get_all_Transcripts }) {
        my $p = $tran->translation || next;
        # first stage mapper: xref to translation
        push @segments, @{ $self->_get_Segments($from_cs, $mid_cs, undef, undef, $p) };
      }
      # If the first stage actually produced mappings, we'll need to map from
      # peptide to slice
      if ($self->{'mappers'}{$from_cs->name}{$from_cs->version}) {
        # second stage mapper: gene or translation to transcript's slice
        $self->_get_Segments($mid_cs, $to_cs, $slice, undef, undef);
      }
    }
    
    # Mapping from gene-mapped xref to slice
    elsif ( $callback = $XREF_GENE_FILTERS{$from_cs->name} ) {
      for my $g ( defined $gene ? ($gene) : @{ $slice->get_all_Genes }) {
        for my $xref (grep { $callback->{'predicate'}($_) } @{ $g->get_all_DBEntries() }) {
          my $segid = $callback->{'transformer'}( $xref );
          push @segments, $segid;
        }
        # Gene-based xrefs don't have alignments and so don't generate mappings.
        # It is enough to simply collate the segment ID's; only non-positional
        # features will mapped.
      }
    }
    
    else {
      warning(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  } # end mapping to slice/gene
  
  # Mapping to peptide-relative coordinates
  elsif ( $to_cs->equals( $self->{'prot_cs'} ) ) {
    
    $prot || throw('Trying to convert to peptide coordinates, but no Translation provided');
    
    # Mapping from protein to protein (the same)
    if ( $from_cs->equals( $to_cs ) ) {
      # no mapper needed
      push @segments, $prot->stable_id;
    }
    
    # Mapping from slice. Note that from_cs isnt necessarily the same as the transcript's coord_system
    elsif ( $from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/ ) {
      my $ta    = $prot->adaptor->db->get_TranscriptAdaptor();
      my $sa    = $prot->adaptor->db->get_SliceAdaptor();
      my $tran  = $ta->fetch_by_translation_stable_id($prot->stable_id);
      my $slice = $sa->fetch_by_transcript_stable_id($tran->stable_id);
      $tran = $tran->transfer($slice);
      # second stage mapper: transcript's slice to protein
      my $mapper = Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper->new('from', 'to', $from_cs, $to_cs, $tran);
      
      $self->{'mappers'}{$slice->coord_system->name}{$slice->coord_system->version||''}{$slice->seq_region_name} = $mapper;
      # first stage mapper: from_cs to transcript's slice
      push @segments, @{ $self->_get_Segments($from_cs, $tran->slice->coord_system, $slice) };
    }
    
    # Mapping from gene on a slice with the same coordinate system
    elsif ( $from_cs->equals( $self->{'gene_cs'} ) ) {
      my $ga    = $prot->adaptor->db->get_GeneAdaptor();
      my $sa    = $prot->adaptor->db->get_SliceAdaptor();
      my $g     = $ga->fetch_by_translation_stable_id($prot->stable_id);
      my $slice = $sa->fetch_by_gene_stable_id($g->stable_id);
      # Second stage mapper: slice to peptide
      $self->_get_Segments($slice->coord_system, $to_cs, undef, undef, $prot);
      # First stage mapper: gene to slice
      push @segments, @{ $self->_get_Segments($from_cs, $slice->coord_system, $slice, $g, undef) };
    }
    
    # Mapping from xref to peptide
    elsif ( my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name} ) {
      for my $xref (grep { $callback->{'predicate'}($_) } @{ $prot->get_all_DBEntries() }) {
        my $segid = $callback->{'transformer'}( $xref );
        push @segments, $segid;
        # If xref has a cigar alignment, use it to build mappings to the
        # Ensembl translation (assume they all align to the translation).
        # If not, we still query with the segment because non-positional
        # features don't need a mapper.
        if ($xref->can('get_mapper')) {
          my $mapper = Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper->new('from', 'to', $from_cs, $to_cs, $xref, $prot);
          $mapper->external_id($segid);
          $mapper->ensembl_id($prot->stable_id);
          $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$segid} = $mapper;
        }
      }
    }
    
    # Mapping from gene-mapped xref to peptide
    elsif ( $callback = $XREF_GENE_FILTERS{$from_cs->name} ) {
      my $ga    = $prot->adaptor->db->get_GeneAdaptor();
      my $g     = $ga->fetch_by_translation_stable_id($prot->stable_id);
      for my $xref (grep { $callback->{'predicate'}($_) } @{ $g->get_all_DBEntries() }) {
        my $segid = $callback->{'transformer'}( $xref );
        push @segments, $segid;
        # Gene-based xrefs don't have alignments and so don't generate mappings.
        # It is enough to simply collate the segment ID's; only non-positional
        # features will mapped.
      }
    }
    
    else {
      warning(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  }
  
  else {
    warning(sprintf 'Mapping to %s is not supported', $to_cs->name);
  }
  
  return \@segments;
}

1;