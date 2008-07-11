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
use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::CodonMapper;
use Bio::Das::Lite;

use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw($EXTRA_COORDS);
use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw info);

our $ORI_NUMERIC = {
   1    =>  1,
  '+'   =>  1,
  -1    => -1,
  '-'   => -1,
   0    =>  0,
  '.'   =>  0,
};

our $ORI_SYMBOLIC = {
 '+'  => '+',
  1   => '+',
 '-'  => '-',
  -1  => '-',
  0   => undef,
};

=head2 new

TODO: update

  Arg [1]    : Arrayref of Bio::EnsEMBL::DAS::Source objects. It is
               imperative that all coordinate systems are valid for the
               relevant species.
  Description: Constructor, taking as an argument an arrayref of DAS sources.
  Returntype : Bio::EnsEMBL::DAS::Coordinator
  Exceptions : none
  Caller     : 
  Status     : Stable

=cut
sub new {
  my $class = shift;
  
  my ($sources, $proxy, $timeout) = rearrange(['SOURCES','PROXY', 'TIMEOUT'], @_);
  
  $sources = [$sources] if ($sources && !ref $sources);
  
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl');
  $das->http_proxy($proxy);
  $das->timeout($timeout);
  $das->caching(0);
  
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
  Description: Constructor, taking as an argument an arrayref of DAS sources.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Coordinator
  Exceptions : Throws if the object is not supported
  Caller     : 
  Status     : Stable

=cut
sub fetch_Features {
  my ($self, $target_obj) = @_;
  
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
    $target_cs = Bio::EnsEMBL::CoordSystem->new( -name => 'ensembl_peptide', -rank => 99 );
    $target_segment = $target_obj->stable_id;
  } else {
    throw('Unsupported object type: '.$target_obj);
  }
  
  my %coords = ();
  my $final = {};
  
  for my $source (@{ $self->{'sources'} }) {
#    warn $source->key.' has '.scalar @{ $source->coord_systems }.' coord systems';
    for my $source_cs (@{ $source->coord_systems }) {
      
      # Coord_systems can be objects or URI strings
      if (! ref $source_cs ) {
        my ($name, $version) = split ':', $source_cs;
        $source_cs = Bio::EnsEMBL::CoordSystem->new( -name => $name, $version => $version, -rank => 99 );
      }
      
      # Sort sources by coordinate system
      if (!$coords{$source_cs->name}) {
        $coords{$source_cs->name} = {
          'sources'  => {},
        };
        my ($mappers, $segments) = $self->_get_Mappers($source_cs, $target_cs, $slice, $gene, $prot);
        $coords{$source_cs->name}->{'mappers'}  = $mappers;
        $coords{$source_cs->name}->{'segments'} = $segments;
      }
      $coords{$source_cs->name}{'sources'}{$source->full_url} = $source;
    }
  }
  
  my @sources_with_data = ();
  
  # Split the requests that will be performed by coordinate system, i.e. parallelise
  # requests for segments that are from the same coordinate system
  while (my ($coord_name, $coord_data) = each %coords) {
    my $segments = $coord_data->{'segments'};
    
    if (!scalar @{ $segments }) {
      info("No segments found for $coord_name");
      next;
    }
    
    info("Querying with @{$segments} for $coord_name");
    # TODO: use callbacks to build features
    $self->{'daslite'}->dsn([keys %{ $coord_data->{'sources'} }]);
    my $response = $self->{'daslite'}->features($segments); # hashref
    my $statuses = $self->{'daslite'}->statuscodes();
    
    while (my ($url, $features) = each %{ $response }) {
      my $status = $statuses->{$url};
      $url =~ s|/features\?segment=(.*)$||;
      my $segment = $1;
      print "*** $segment $url ***\n";
      my $source = $coord_data->{'sources'}{$url};
      $final->{$url}{'source'} = $source;
      
      if ($status!~ m/^200/ || !defined $features) {
        # TODO: proper error handling
        $final->{$url}{'features'}{$segment} = [ {
                                                  'type' => '__ERROR__',
                                                  'note' => 'Error communicating with DAS server'.($statuses->{$url}?" - $statuses->{$url}":q()),
                                                 } ];
        next;
      } elsif (ref $features ne 'ARRAY' || !scalar @{ $features }) {
        $final->{$url}{'features'}{$segment} = [ {
                                                  'type' => '__ERROR__',
                                                  'note' => 'No features'
                                                 } ];
        next;
      }
      
      # Convert into the query coordinate system if applicable
      my $mappers = $coord_data->{'mappers'};
      $features = $self->map_Features($features, $slice, $prot, $mappers, $source);
      
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
    
    # Get stylesheet
    $response = $self->{'daslite'}->stylesheet();
    while (my ($url, $styledata) = each %{ $response }) {
      if ($styledata && ref $styledata eq 'ARRAY') {
        $url =~ s|/stylesheet\?$||;
        $final->{$url}{'stylesheet'} = $styledata;
      }
    }
    
  }
  
  #use Data::Dumper;print Dumper($final);
  return $final;
}

# Returns: new arrayref with features
sub map_Features {
  my ($self, $features, $slice, $prot, $mappers, $source) = @_;
  my @new_features = ();
  
  while (my $f = shift @{ $features }) {
    my $start = $f->{'start'};
    my $end   = $f->{'end'};
    my $segid = $f->{'segment_id'};
    
    if (!$segid) {
      warning($source->full_url.' returned a feature without a segment ID; skipping');
      next;
    }
    
    # if no orientation, assume + strand
    my $ori   = $ORI_NUMERIC->{$f->{'orientation'} || '+'};
    
    # Code block for building a new feature:
    my $last_seg; # A Coordinate resulting from a mapping
    my $add_seg = sub {
=head
      my $mapped = { %{ $f } }; # copy feature
      $mapped->{'segment_id'}  = $last_seg->id;
      $mapped->{'start'}       = $s;
      $mapped->{'end'}         = $e;
      $mapped->{'orientation'} = $ORI_SYMBOLIC->{$last_seg->strand} if ($last_seg->strand ne $ori);
=cut
      my $mapped;
      if ($slice) {
        $mapped = Bio::EnsEMBL::FeaturePair->new(
          -start    => $last_seg ? $last_seg->start  : $f->{'start'},
          -end      => $last_seg ? $last_seg->end    : $f->{'end'},
          -strand   => $last_seg ? $last_seg->strand : $ori,
          -slice    => $slice,
          -hseqname => $segid,
          -hstart   => $f->{'start'},
          -hend     => $f->{'end'},
          -hstrand  => $ori,
          -score    => $f->{'score'},
          -analysis => $source,
        );
      } else {
        $mapped = Bio::EnsEMBL::ProteinFeature->new(
          -start    => $last_seg ? $last_seg->start : $f->{'start'},
          -end      => $last_seg ? $last_seg->end   : $f->{'end'},
          -hseqname => $segid,
          -hstart   => $f->{'start'},
          -hend     => $f->{'end'},
          -score    => $f->{'score'},
          -analysis => $source,
        );
      }
      
      push @new_features, $mapped;
      #printf "Adding segment %s %s:%s-%s\n", $mapped->{'feature_id'}, $last_seg->id, $s, $e;
    };
    
    # Non-positional features require no mapping
    # Also assume those without a mapper require none
    if ($start && $end && (my $mapper = $mappers->{$segid})) {
      my @segs = $mapper->map_coordinates($segid, $start, $end, $ori, $mapper->from);
      for my $seg (sort{ $a->id cmp $b->id || $a->start <=> $b->start } grep {$_->isa('Bio::EnsEMBL::Mapper::Coordinate')} @segs) {
        # Check for contiguous segments. These are possible with gapped->ungapped mappings such as slice->protein.
        # We don't want to split these features, so we stitch the segments back together.
        if ($last_seg && $seg->id eq $last_seg->id && $seg->start == $last_seg->end+1) {
          $seg->start($last_seg->start);
        } elsif ($last_seg) {
          &$add_seg;
        }
        $last_seg = $seg;
      }
      if ($last_seg) {
        &$add_seg;
      }
    }
    else {
      &$add_seg;
    }

    
  }
  
  return \@new_features;
}

# Some mappers could be built using the database (AssemblyMapper).
# Just build them all dynamically in code.
# Supports mapping to:
#   location-based (chromosome|clone|contig|scaffold|supercontig)
#   protein-based  (ensembl_peptide)
# Supports mapping from:
#   location-based (chromosome|clone|contig|scaffold|supercontig)
#   protein-based  (ensembl_peptide)
#   gene-based     (ensembl_gene)
sub _get_Mappers {
  my $self = shift;
  my $from_cs = shift; # the "foreign" source coordinate system 
  my $to_cs = shift;   # the target coordsys that mapped objects will be converted to
  my ($slice, $gene, $prot) = @_;
  #warn sprintf "Getting mapper for %s -> %s", $from_cs->name, $to_cs->name;
  
  my %mappers = ();
  my @segments = ();
  
  # There are several different Mapper implementations in the API to convert
  # between various coordinate systems: AssemblyMapper, TranscriptMapper,
  # IdentityXref. But they all work in different ways and cannot be handled in
  # the same way. They also have other limitations, for example TranscriptMapper
  # cannot work with transcripts that span boundaries in old assemblies, because
  # it requires a transcript object and operates relative to its single slice.
  # For these reasons, we create one-step mappers for all conversions. This will
  # be faster than performing multiple conversions for large lists of features.
  
  # Mapping to slice-relative coordinates
  if ($to_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
    
    $slice || throw('Trying to convert to slice coordinates, but no Slice provided');
    $slice->coord_system->equals($to_cs) || throw('Provided slice is not in target coordinate system');
    
    # Mapping from a slice-based coordinate system
    if ($from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
      #my $mapper = $slice->adaptor->db->get_AssemblyMapperAdaptor->fetch_by_CoordSystems($from_cs, $to_cs)->mapper;
      #for my $fr_seg (@{ $mapper->map_coordinates($slice->seq_region_name, $slice->start, $slice->end, $slice->strand, $to_cs->name) }) {
      my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to');
      if ($from_cs->equals($to_cs)) {
        # DAS differs in its use of genome-based coordinates:
        # they are always relative to the entire seq_region rather than a slice
        #printf "Adding %s:%s,%s(%s) -> %s:%s,%s\n", $slice->seq_region_name, $slice->start, $slice->end, 1, $slice->seq_region_name, 1, $slice->length;
        $mapper->add_map_coordinates(
          $slice->seq_region_name, $slice->start, $slice->end,   1,
          $slice->seq_region_name, 1,             $slice->length
        );
        push @segments, sprintf '%s:%s,%s', $slice->seq_region_name, $slice->start, $slice->end;
        $mappers{$slice->seq_region_name} = $mapper;
      } else {
        for my $fr_seg (@{ $slice->project($from_cs->name, $from_cs->version) }) {
          # each mapping segment represents a section of a "from" object
          my $fr_ob = $fr_seg->to_Slice();
          #printf "Adding %s:%s,%s(%s) -> %s:%s,%s\n", $fr_ob->seq_region_name, $fr_ob->start, $fr_ob->end, $fr_ob->strand, $slice->seq_region_name, $fr_seg->from_start, $fr_seg->from_end;
          $mapper->add_map_coordinates(
            # the region of the "from" object:
            $fr_ob->seq_region_name, $fr_ob->start, $fr_ob->end, $fr_ob->strand,
            # looks confusing, but a "from" region comes from a "to" region:
            $slice->seq_region_name, $fr_seg->from_start, $fr_seg->from_end
          );
          push @segments, sprintf '%s:%s,%s', $fr_ob->seq_region_name, $fr_ob->start, $fr_ob->end;
          $mappers{$fr_ob->seq_region_name} = $mapper;
        }
      }
    }
    
    # Mapping from ensembl_gene to slice
    elsif ($from_cs->name eq 'ensembl_gene') {
      for my $g ( $gene ? ($gene) : @{ $slice->get_all_Genes }) {
        # Genes are already definitely relative to the target slice, so don't need to do any assembly mapping
        my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to');
        #warn "ADDING ".$gene->stable_id." ".$gene->strand*$gene->slice->strand." ->";
        $mapper->add_map_coordinates(
          $g->stable_id,           1,         $g->length, $g->strand,
          $slice->seq_region_name, $g->start, $g->end
        );
        $mappers{$g->stable_id} = $mapper;
        push @segments, $g->stable_id;
      }
    }
    
    # Mapping from ensembl_peptide to slice
    elsif ($from_cs->name eq 'ensembl_peptide') {
      for my $tran (@{ $slice->get_all_Transcripts }) {
        my $prot = $tran->translation || next;
        $mappers{$prot->stable_id} = &_get_Translation_Slice_Mapper($to_cs, $tran, $prot);
        push @segments, $prot->stable_id;
      }
    }
    
    # Mapping from uniprot
    elsif ($from_cs->name eq 'uniprot_peptide') {
      # Use uniprot xref cigar alignments
      for my $xref(@{ $prot->get_all_DBEntries('Uniprot/%') }) {
        $xref->dbname =~ m{uniprot/sptrembl|uniprot/swissprot}i || next;
        $mappers{$xref->primary_id} = &_get_Xref_Slice_Mapper($xref, $prot);
        push @segments, $xref->primary_id;
      }
    }
    
    else {
      throw(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  } # end mapping to slice/gene
  
  # Mapping to peptide-relative coordinates
  elsif ($to_cs->name eq 'ensembl_peptide') {
    
    $prot || throw('Trying to convert to peptide coordinates, but no Translation provided');
    
    # Mapping from slice with the same or different coordinate system
    if ($from_cs->name =~ m/^chromosome|clone|contig|scaffold|supercontig$/) {
      my $ta = $prot->adaptor->db->get_TranscriptAdaptor();
      my $tran = $ta->fetch_by_translation_stable_id($prot->stable_id);
      $mappers{$tran->seq_region_name} = &_get_Slice_Translation_Mapper($from_cs, $tran, $prot);
      push @segments, sprintf '%s:%s,%s', $tran->seq_region_name, $tran->slice->start + $tran->coding_region_start - 1, $tran->slice->start + $tran->coding_region_end - 1;
    }
    
    # Mapping from gene on a slice with the same or different coordinate system
    elsif ($from_cs->name eq 'ensembl_gene') {
      my $ta = $prot->adaptor->db->get_TranscriptAdaptor();
      my $tran = $ta->fetch_by_translation_stable_id($prot->stable_id);
      my $ga = $prot->adaptor->db->get_GeneAdaptor();
      my $gene = $ga->fetch_by_translation_stable_id($prot->stable_id);
      $mappers{$gene->stable_id} = &_get_Gene_Translation_Mapper($gene, $tran, $prot);
      push @segments, $gene->stable_id;
    }
    
    elsif ($from_cs->name eq 'ensembl_peptide') {
      # no mapper needed
      push @segments, $prot->stable_id;
    }
    
    # Mapping from uniprot
    elsif ($from_cs->name eq 'uniprot_peptide') {
      # Use uniprot xref cigar alignments
      for my $xref(@{ $prot->get_all_DBEntries('Uniprot/%') }) {
        $xref->dbname =~ m{uniprot/sptrembl|uniprot/swissprot}i || next;
        $mappers{$xref->primary_id} = &_get_Xref_Translation_Mapper($xref, $prot);
        push @segments, $xref->primary_id;
      }
    }
    
    else {
      throw(sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  }
  else {
    throw(sprintf 'Mapping to %s is not supported', $to_cs->name);
  }
  
  return (\%mappers, \@segments);
}

sub _get_Xref_Slice_Mapper {
  my ($xref, $prot) = @_;
  
  my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to');
  
=head NOT DONE YET
  my (@lens, @chars);
  # if there is no cigar line, nothing is going to be loaded
  if (my $cigar = $xref->cigar_line()) {
    my @pre_lens = split( '[DMI]', $cigar );
    @lens = map { if( ! $_ ) { 1 } else { $_ }} @pre_lens;
    @chars = grep { /[DMI]/ } split( //, $cigar );
  }
  my $translation_start = $xref->translation_start();
  my $query_start = $xref->query_start();

  for( my $i=0; $i<=$#lens; $i++ ) {
    my $length = $lens[$i];
    my $char = $chars[$i];
    if( $char eq "M" ) {
      $mapper->add_map_coordinates( $xref->primary_id, $query_start,
                                    $query_start + $length - 1, 1,
                                    $prot->stable_id, $translation_start,
                                    $translation_start + $length - 1);
      $query_start += $length;
      $translation_start += $length;

    } elsif( $char eq "D" ) {
      $translation_start += $length;
    } elsif( $char eq "I" ) {
      $query_start += $length;
    }
  }
=cut
  
  return $mapper;
}

sub _get_Xref_Translation_Mapper {
  my ($xref, $prot) = @_;
  return $xref->get_mapper;
  
  my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to');
  
  # Would have liked to use IdentityXref's mapper, but for some reason it uses
  # the strings 'external_id' and 'ensembl_id' instead of the actual sequence
  # identifiers. So have to re-implement...
  
  my (@lens, @chars);
  # if there is no cigar line, nothing is going to be loaded
  if (my $cigar = $xref->cigar_line()) {
    my @pre_lens = split( '[DMI]', $cigar );
    @lens = map { if( ! $_ ) { 1 } else { $_ }} @pre_lens;
    @chars = grep { /[DMI]/ } split( //, $cigar );
  }
  my $translation_start = $xref->translation_start();
  my $query_start = $xref->query_start();

  for( my $i=0; $i<=$#lens; $i++ ) {
    my $length = $lens[$i];
    my $char = $chars[$i];
    if( $char eq "M" ) {
      $mapper->add_map_coordinates( $xref->primary_id, $query_start,
                                    $query_start + $length - 1, 1,
                                    $prot->stable_id, $translation_start,
                                    $translation_start + $length - 1);
      $query_start += $length;
      $translation_start += $length;

    } elsif( $char eq "D" ) {
      $translation_start += $length;
    } elsif( $char eq "I" ) {
      $query_start += $length;
    }
  }
  
  return $mapper;
}

sub _get_Translation_Slice_Mapper {
  my ($slice_cs, $tran, $prot) = @_;
  $slice_cs->equals($tran->slice->coord_system) || throw('Mapping from peptide to slice coordinates is only supported where the target coordinates are the same as the provided Transcript');
  my $mapper = Bio::EnsEMBL::CodonMapper->new('from', 'from', 'to');
  
  # The first coding base of the CDNA
  my $tran_cdna_coding_start = $tran->cdna_coding_start;
  
  for my $exon (@{ $tran->get_all_Exons }) {
    
    my $cdna_start = $exon->cdna_coding_start($tran) || next;
    my $cdna_end   = $exon->cdna_coding_end  ($tran);
    
    my $slice_start = $exon->coding_region_start($tran);
    my $slice_end   = $exon->coding_region_end($tran);
    
    # Equivalent CDS region:
    my $cds_start  = $cdna_start - $tran_cdna_coding_start + 1;
    my $cds_end    = $cdna_end   - $tran_cdna_coding_start + 1;
    
    #printf "Adding %s:%s-%s(%s) -> %s:%s-%s\n", $prot->stable_id, $cds_start, $cds_end, $exon->strand, $exon->seq_region_name, $slice_start, $slice_end;
    
    $mapper->add_map_coordinates(
      $prot->stable_id,       $cds_start,   $cds_end,  $exon->strand,
      $exon->seq_region_name, $slice_start, $slice_end
    );
  }
  
  return $mapper;
}

sub _get_Slice_Translation_Mapper {
  my ($slice_cs, $tran, $prot) = @_;
  my $mapper = Bio::EnsEMBL::CodonMapper->new('to', 'from', 'to');
  
  # The first and last coding bases of the CDNA
  my $tran_cdna_coding_start = $tran->cdna_coding_start;
  my $tran_cdna_coding_end   = $tran->cdna_coding_end;
  my $cdna_start = undef;
  my $cdna_end   = 0;
  
  for my $exon (@{ $tran->get_all_Exons }) {
    
    #printf "Exon %s %s:%s-%s(%s)\n", $exon->stable_id, $exon->seq_region_name, $exon->seq_region_start, $exon->seq_region_end, $exon->strand;
    
    for my $seg (@{ $exon->project($slice_cs->name, $slice_cs->version) }) {
      
      # Update the cdna position:
      $cdna_start = $cdna_end + 1;
      $cdna_end   = $cdna_start + $seg->from_end - $seg->from_start;
      
      next if ($seg->isa('Bio::EnsEMBL::Mapper::Gap'));
      next if ($tran_cdna_coding_start > $cdna_end || $tran_cdna_coding_end < $cdna_start);
      
      my $slice = $seg->to_Slice();
      my $slice_start = $slice->start;
      my $slice_end   = $slice->end;
      #printf "Seg %s-%s -> %s:%s-%s(%s)\n", $seg->from_start, $seg->from_end, $slice->seq_region_name, $slice->start, $slice->end, $slice->strand;
      
      # We're only interested in the coding region:
      if ((my $overhang = $tran_cdna_coding_start - $cdna_start) > 0) {
        #print "start overhang of $overhang\n";
        $cdna_start  += $overhang;
        $slice->strand == 1 ? $slice_start += $overhang : $slice_end -= $overhang;
      }
      if ((my $overhang = $cdna_end - $tran_cdna_coding_end) > 0) {
        #print "end overhang of $overhang\n";
        $cdna_end  -= $overhang;
        $slice->strand == 1 ? $slice_end -= $overhang : $slice_start += $overhang;
      }
      
      # Equivalent CDS region:
      my $cds_start  = $cdna_start - $tran_cdna_coding_start + 1;
      my $cds_end    = $cdna_end   - $tran_cdna_coding_start + 1;
      
      #printf "Adding %s:%s-%s(%s) -> %s:%s-%s\n", $slice->seq_region_name, $slice_start, $slice_end, $slice->strand, $prot->stable_id, $cds_start, $cds_end;
      
      $mapper->add_map_coordinates(
        $slice->seq_region_name, $slice_start, $slice_end, $slice->strand,
        $prot->stable_id,        $cds_start,   $cds_end
      );
      
    }
  }
  return $mapper;
}

# get_Mapper only supports gene -> translation, but technically this method supports translation -> gene too
sub _get_Gene_Translation_Mapper {
  my ($gene, $tran, $prot) = @_;
  
  my $mapper = Bio::EnsEMBL::CodonMapper->new('to', 'from', 'to');
  
  #printf "%s : %s-%s (%s-%s)\n", $gene->stable_id, $gene->seq_region_start, $gene->seq_region_end, $cds_start;
  
  # The first and last coding bases of the CDNA
  my $tran_cdna_coding_start = $tran->cdna_coding_start;
  my $tran_cdna_coding_end   = $tran->cdna_coding_end;
  my $cdna_start = undef;
  my $cdna_end   = 0;
  
  for my $exon (@{ $tran->get_all_Exons }) {
    
    # Update the cdna position:
    $cdna_start = $cdna_end + 1;
    $cdna_end   = $cdna_start + $exon->end - $exon->start;
    
    next if ($tran_cdna_coding_start > $cdna_end || $tran_cdna_coding_end < $cdna_start);
    
    my $gene_start = $exon->strand == 1 ? $exon->seq_region_start - $gene->seq_region_start + 1
                                        : $gene->seq_region_end   - $exon->seq_region_end + 1;
    my $gene_end   = $exon->strand == 1 ? $exon->seq_region_end   - $gene->seq_region_start + 1
                                        : $gene->seq_region_end   - $exon->seq_region_start + 1;
    #printf "Seg %s-%s -> %s:%s-%s(%s)\n", $seg->from_start, $seg->from_end, $slice->seq_region_name, $slice->start, $slice->end, $slice->strand;
    
    # We're only interested in the coding region:
    if ((my $overhang = $tran_cdna_coding_start - $cdna_start) > 0) {
      #print "start overhang of $overhang\n";
      $cdna_start += $overhang;
      $gene_start += $overhang;
    }
    if ((my $overhang = $cdna_end - $tran_cdna_coding_end) > 0) {
      #print "end overhang of $overhang\n";
      $cdna_end -= $overhang;
      $gene_end -= $overhang;
    }
    
    # Equivalent CDS region:
    my $cds_start  = $cdna_start - $tran_cdna_coding_start + 1;
    my $cds_end    = $cdna_end   - $tran_cdna_coding_start + 1;
    
    #printf "%s : %s-%s gene(%s-%s) cdna(%s-%s) cds(%s-%s)\n", $exon->stable_id, $exon->start, $exon->end, $gene_start, $gene_end, $cdna_start, $cdna_end, $cds_start, $cds_end;
    
    $mapper->add_map_coordinates(
      $gene->stable_id, $gene_start, $gene_end, 1, # genes and proteins are always in the same orientation
      $prot->stable_id, $cds_start,  $cds_end
    );
    
  }
  return $mapper;
}

1;