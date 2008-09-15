=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Coordinator

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

our @NON_GENOMIC_COORDS = (
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
               -SOURCES  - Arrayref of Bio::EnsEMBL::DAS::Source objects.
               -PROXY    - A URL to use as an HTTP proxy server
               -NOPROXY  - A list of domains/hosts to not use the proxy for
               -TIMEOUT  - The desired timeout, in seconds
  Description: Constructor
  Returntype : Bio::EnsEMBL::DAS::Coordinator
  Exceptions : none
  Caller     : 
  Status     : 

=cut
sub new {
  my $class = shift;
  
  my ($sources, $proxy, $no_proxy, $timeout)
    = rearrange(['SOURCES','PROXY', 'NOPROXY', 'TIMEOUT'], @_);
  
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
  
  my $self = {
    'sources' => $sources,
    'daslite' => $das,
    'objects' => {},
  };
  bless $self, $class;
  return $self;
}

=head2 fetch_features

  Arg [1]    : Bio::EnsEMBL::Object $root_obj - the query object (e.g. Slice, Gene)
  Arg [2]    : (optional) maxbins - typically the maximum available "rendering space"
  Arg [3]    : (optional) type ID
  Arg [4]    : (optional) feature ID
  Arg [5]    : (optional) group ID
  Description: Constructor, taking as an argument an arrayref of DAS sources.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Coordinator
  Exceptions : Throws if the object is not supported
  Caller     : 
  Status     : 

=cut
sub fetch_Features {
  my ($self, $target_obj, $maxbins, $filter_type, $filter_feature, $filter_group) = @_;
  
  my ($target_cs, $target_segment, $slice, $gene, $prot);
  if ($target_obj->isa('Bio::EnsEMBL::Gene')) {
    $slice = $target_obj->slice;
    $gene = $target_obj;
    $target_cs = $slice->coord_system; # actually want features relative to the slice
    $target_segment = $target_obj->stable_id;
  } elsif ($target_obj->isa('Bio::EnsEMBL::Slice')) {
    $slice = $target_obj;
    $target_cs = $target_obj->coord_system;
    $target_segment = sprintf '%s:%s,%s', $target_obj->seq_region_name, $target_obj->start, $target_obj->end;
  } elsif ($target_obj->isa('Bio::EnsEMBL::Translation')) {
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
    }
    
    for my $source_cs (@{ $source->coord_systems }) {
      
      if (my $source_species = $source_cs->species) {
        $source_species eq $target_obj->adaptor->db->species || next;
      }
      
      # Sort sources by coordinate system
      if (!$coords{$source_cs->name}) {
        $coords{$source_cs->name} = {
          'sources'      => {},
          'coord_system' => $source_cs,
        };
        
        # Do a lot of funky stuff to get the query segments, and build up
        # mappers at the same time
        my $segments = $self->_get_Segments($source_cs, $target_cs, $slice, $gene, $prot);
        $coords{$source_cs->name}->{'segments'} = $segments;
      }
      $coords{$source_cs->name}{'sources'}{$source->full_url} = $source;
    }
  }
  
  #==========================================================#
  # Now perform parallel requests for each coordinate system #
  #==========================================================#
  
  my @sources_with_data = ();
  my $daslite = $self->{'daslite'};
  
  # Split the requests that will be performed by coordinate system, i.e. parallelise
  # requests for segments that are from the same coordinate system
  while (my ($coord_name, $coord_data) = each %coords) {
    my $segments = $coord_data->{'segments'};
    
    if (!scalar @{ $segments }) {
      # TODO: this needs to be indicated in the results as an error/info message
      info("No segments found for $coord_name");
      next;
    }
    
    # TODO: use callbacks to build features?
    
    info("Querying with @{$segments} for $coord_name");
    $daslite->dsn( [keys %{ $coord_data->{'sources'} }] );
    
    # Now build a query array for each segment, with the optional filter
    # parameters. Note that it is not mandatory for DAS servers to implement
    # these filters. If they do, great, but we still have to filter on the
    # client side.
    my @features_query = map {
      {
       'segment'    => $_,
       'type'       => $filter_type,
       'feature_id' => $filter_feature,
       'group_id'   => $filter_group,
       'maxbins'    => $maxbins,
      }
    } @{ $segments };
    
    my $response = $daslite->features(\@features_query); # returns a hashref
    my $statuses = $daslite->statuscodes();
    
    # Final structure will look like:
    # {
    #  'http.../das' => {
    #                    'source'     => $source_object,
    #                    'stylesheet' => $style_hash,
    #                    'features'   => {
    #                                     'segment1' => [
    #                                                    $feat1, # Bio::EnsEMBL::ExternalData::DAS::Feature
    #                                                    $feat2,
    #                                                   ],
    #                                     'segment2' => [
    #                                                    $feat3,
    #                                                    $feat4,
    #                                                   ],
    #                                    }
    #                   }
    # }
    
    #========================================================#
    #          Process a set of features per source          #
    #========================================================#
    
    while (my ($url, $features) = each %{ $response }) {
      info("*** $url ***");
      my $status = $statuses->{$url};
      
      # Parse the segment from the URL
      # TODO: check how daslite handles multiple segments!
      $url =~ s|/features\?segment=([^;]*).*$||;
      my $segment = $1;
      my $source = $coord_data->{'sources'}{$url};
      
      $final->{$url}{'source'} = $source;
      
      if ($status !~ m/^200/) {
        # TODO: proper error handling
        $final->{$url}{'features'}{$segment} = [ {
                                                  'type' => '__ERROR__',
                                                  'note' => "Error communicating with DAS server - $status",
                                                 } ];
        next;
      } elsif (!defined $features || ref $features ne 'ARRAY' || !scalar @{ $features }) {
        $final->{$url}{'features'}{$segment} = [ {
                                                  'type' => '__ERROR__',
                                                  'note' => 'No features'
                                                 } ];
        next;
      }
      
      ########
      # Apply client-side filters at this early stage...
      ########
      my @filtered_features = grep {
        #print Dumper($_);
        ( !$filter_type    || $_->{'type'      } eq $filter_type ) &&
        ( !$filter_feature || $_->{'feature_id'} eq $filter_feature ) &&
        ( !$filter_group   || grep { $_->{'group_id'} eq $filter_group } @{ $_->{'group'} } )
      } @{ $features };
      
      ########
      # Convert into the query coordinate system if applicable
      ########
      $features = $self->map_Features($features,
                                      $coord_data->{'coord_system'},
                                      $target_cs,
                                      $slice,
                                      $filter_type,
                                      $filter_feature,
                                      $filter_group);
      
      if (scalar @{ $features }) {
        $final->{$url}{'features'}{$segment} = $features;
        push @sources_with_data, $source->url; # for retrieving stylesheets
      } else {
        $final->{$url}{'features'}{$segment} = [ {
                                                  'type' => '__ERROR__',
                                                  'note' => "$segment features do not map to $target_segment",
                                                 } ];
      }
      
    }
    
  }
  
  #==========================================================#
  #         Get stylesheets for all sources with data        #
  #==========================================================#
  
  $daslite->dsn( @sources_with_data );
  my $response = $daslite->stylesheet();
  while (my ($url, $styledata) = each %{ $response }) {
    if ($styledata && ref $styledata eq 'ARRAY') {
      $url =~ s|/stylesheet\?$||;
      $final->{$url}{'stylesheet'} = $styledata;
    }
  }
  
  return $final;
}

# Returns: new arrayref with features
sub map_Features {
  my ($self, $features, $source_cs, $to_cs, $slice) = @_;
  my @new_features = ();
  
  # May need multiple mapping steps to reach the target coordinate system
  while ( $source_cs && !$source_cs->equals($to_cs) ) {
    
    info('Beginning mapping from '.$source_cs->name);
    
    my @this_features = @{ $features };
    my $mappers = $self->{'mappers'}{$source_cs->name}{$source_cs->version||''};
    $features  = [];
    $source_cs = undef;
    
    my $positional_mapping_errors = 0;
    
    # Map the current set of features to the next coordinate system
    for my $f ( @this_features ) {
      
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
        $new{'segment_id'} = $c->id,
        $new{'start'     } = $c->start,
        $new{'end'       } = $c->end,
        $new{'strand'    } = $c->strand,
        push @{ $features }, \%new;
      }
      
    }
    
    if ($positional_mapping_errors) {
      warning("$positional_mapping_errors positional features could not be mapped")
    }
  }
  
  # Now let's build us some feature objects!
  for my $f ( @{ $features } ) {
      use Data::Dumper;print Dumper($f);
    $f = Bio::EnsEMBL::ExternalData::DAS::Feature->new(
      -start    => $f->{'start'},
      -end      => $f->{'end'},
      -strand   => $f->{'strand'}, # should be 1 if to_cs is protein
      -type     => $f->{'type'},
      -score    => $f->{'score'},
      -notes    => $f->{'note'},
      -links    => $f->{'link'},
      -groups   => $f->{'group'},
    );
    # Where target coordsys is genomic, make a slice-relative feature
    # TODO: I THINK THIS IS BREAKING THE FEATURES, AS NOT ALL INFO IS COPIED
    #       NEED TO READDRESS HOW THIS IS DONE. NOTE THAT DAS FEATURES ARRIVE
    #       IN SEQ_REGION_SLICE COORDS BUT NEED TO END UP RELATIVE TO SLICE.
    if ($slice) {
      $f->slice($slice->seq_region_Slice);
      $f = $f->transfer($slice);
    }
    push @new_features, $f;
  }
  
  return \@new_features;
}

sub _convert_coord_system {
  my ($self, $cs) = @_;
  if ($cs->isa('Bio::EnsEMBL::ExternalData::DAS::CoordSystem')) {
    return $cs;
  } elsif ($cs->isa('Bio::EnsEMBL::CoordSystem')) {
    return Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
      -name    => $cs->name,
      -version => $cs->version,
      -species => $cs->adaptor->db->species,
    );
  } else {
    throw('Argument is not a CoordSystem but a '.ref $cs);
  }
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
#   protein-based   == ensembl_peptide
#   gene-based      == ensembl_gene
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
  if ($to_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
    
    $slice || throw('Trying to convert to slice coordinates, but no Slice provided');
    $slice->coord_system->equals($to_cs) || throw('Provided slice is not in target coordinate system');
    
    # Mapping from a slice-based coordinate system
    if ($from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
      
      # No mapping needed
      if ($from_cs->equals($to_cs)) {
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
    elsif ($from_cs->name eq 'ensembl_gene') {
      for my $g ( defined $gene ? ($gene) : @{ $slice->get_all_Genes }) {
        # Genes are already definitely relative to the target slice, so don't need to do any assembly mapping
        my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to', $from_cs, $to_cs);
        #warn "ADDING ".$g->stable_id." ".$g->strand;
        $mapper->add_map_coordinates(
          $g->stable_id,           1,                    $g->length, $g->seq_region_strand,
          $slice->seq_region_name, $g->seq_region_start, $g->seq_region_end
        );
        $self->{'mappers'}{'ensembl_gene'}{''}{$g->stable_id} = $mapper;
        push @segments, $g->stable_id;
      }
    }
    
    # Mapping from ensembl_peptide to slice
    elsif ($from_cs->name eq 'ensembl_peptide') {
      for my $tran (@{ $slice->get_all_Transcripts }) {
        my $p = $tran->translation || next;
        $self->{'mappers'}{'ensembl_peptide'}{''}{$p->stable_id} ||= Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper->new('from', 'to', $from_cs, $to_cs, $tran);
        push @segments, $p->stable_id;
      }
    }
    
    # Mapping from translation-mapped xref to slice
    elsif (my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name}) {
      # Mapping path is xref -> ensembl_peptide -> slice
      my $mid_cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide' );
      for my $tran (@{ $slice->get_all_Transcripts }) {
        my $p = $tran->translation || next;
        # first stage mapper: xref to translation
        push @segments, @{ $self->_get_Segments($from_cs, $mid_cs, undef, undef, $p) };
      }
      # If the first stage actually produced mappings, we'll need to map from
      # peptide to slice
      if ($self->{'mappers'}{$from_cs->name}) {
        # second stage mapper: gene or translation to transcript's slice
        $self->_get_Segments($mid_cs, $to_cs, $slice, undef, undef);
      }
    }
    
    # Mapping from gene-mapped xref to slice
    elsif ($callback = $XREF_GENE_FILTERS{$from_cs->name}) {
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
      throw(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  } # end mapping to slice/gene
  
  # Mapping to peptide-relative coordinates
  elsif ($to_cs->name eq 'ensembl_peptide') {
    
    $prot || throw('Trying to convert to peptide coordinates, but no Translation provided');
    
    if ($from_cs->name eq 'ensembl_peptide') {
      # no mapper needed
      push @segments, $prot->stable_id;
    }
    
    # Mapping from slice. Note that from_cs isnt necessarily the same as the transcript's coord_system
    elsif ($from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
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
    elsif ($from_cs->name eq 'ensembl_gene') {
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
    elsif (my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name}) {
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
          $self->{'mappers'}{$from_cs->name}{''}{$segid} = $mapper;
        }
      }
    }
    
    # Mapping from gene-mapped xref to peptide
    elsif ($callback = $XREF_GENE_FILTERS{$from_cs->name}) {
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
      throw(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  }
  
  else {
    throw(sprintf 'Mapping to %s is not supported', $to_cs->name);
  }
  
  return \@segments;
}

1;