# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor
# 
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

GlovarAdaptor - DESCRIPTION of Object

  This object represents the Glovar database.

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle');

my $glovar_adaptor = $glodb->get_GlovarAdaptor;

$var_listref  = $glovar_adaptor->fetch_all_by_Slice($slice);  # grab the lot!


=head1 DESCRIPTION

This module is an entry point into a glovar database,

Objects can only be read from the database, not written. (They are
loaded using a separate system).

=head1 CONTACT

 Tony Cox <avc@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor;
use vars qw(@ISA);
use strict;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::SNP;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;

@ISA = qw(Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor);


=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' variations should be obtained
  Example    : svars = @{$glovar_adaptor->fetch_all_by_Slice($slice)};
  Description: Retrieves a list of variations on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::Variation objects
  Exceptions : none
  Caller     : Bio::EnsEMBL::Slice::get_all_Glovar_variations

=cut

sub fetch_all_by_Slice {
  my ($self, $slice, $is_light) = @_;

  unless($slice->assembly_name() && $slice->assembly_version()){
      warn("Cannot determine assembly name and version from Slice in GlovarAdaptor!\n");
      return([]);
  } else {
    my $assembly = $slice->assembly_name() . $slice->assembly_version();
    my $type = $self->track_name();
    warn("Fetching $type features on assembly $assembly\n");
  }

  my @f = ();
  if($is_light){
    push @f, @{$self->fetch_Light_Trace_Alignments_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_Trace_Alignments_by_chr_start_end($slice)};
  } 
  return(\@f); 
}


=head2 fetch_Light_Variations_by_chr_start_end

 Title   : fetch_Light_Variations_by_chr_start_end
 Usage   : $db->fetch_Light_Variations_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_Trace_Alignments_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    my $q = qq(
        SELECT   
        DISTINCT 
                (mapped_seq.contig_match_start + seq_seq_map.start_coordinate -1) 
                                                    as start_coord,
                (mapped_seq.contig_match_end   + seq_seq_map.start_coordinate -1) 
                                                    as end_coord,
                mapped_seq.snp_rea_id_read          as read_id,
                snp_read.readname                   as readname,
                mapped_seq.is_revcomp               as orientation
        FROM    chrom_seq,
                seq_seq_map,
                snp_sequence,
                mapped_seq,
                snp_read,
                database_dict
        WHERE   chrom_seq.database_seqname      = '$slice_chr'
        AND     chrom_seq.id_chromseq           = seq_seq_map.id_chromseq
        AND     seq_seq_map.sub_sequence        = snp_sequence.id_sequence
        AND     mapped_seq.id_sequence          = snp_sequence.id_sequence
        AND     mapped_seq.snp_rea_id_read      = snp_read.id_read
        AND     chrom_seq.database_source       = database_dict.id_dict
        AND     database_dict.database_version  = '$ass_version'
        AND     database_dict.database_name     = '$ass_name'
        AND     
                (
                (mapped_seq.contig_match_start + seq_seq_map.start_coordinate -1) 
        BETWEEN 
                '$slice_start' AND '$slice_end' 
        OR 
                (mapped_seq.contig_match_end   + seq_seq_map.start_coordinate -1) 
        BETWEEN 
                '$slice_start' AND '$slice_end'
                )
        ORDER BY 
                start_coord

    );

    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Trace_Alignments_by_chr_start_end()!\n$@");
        return([]);
    }

    my @traces = ();
    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        #print STDERR Dumper($rowhash);
        my $trace = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $rowhash->{'READNAME'},
                '_gsf_start'    =>    $rowhash->{'START_COORD'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'END_COORD'} - $slice_start + 1,
                '_snp_strand'   =>    $rowhash->{'ORIENTATION'},
                '_gsf_score'    =>    -1,
                '_type'         =>    '_',
                 '_source_tag'  =>    $rowhash->{'SOURCE'},
                'source_tag'   =>    "Glovar",
            });
            
         my $link = Bio::Annotation::DBLink->new();
         $link->database("Glovar");
         $link->primary_id($rowhash->{'READNAME'});
         $trace->add_DBLink($link);
        #print STDERR Dumper($trace);

        push (@traces,$trace); 
    }
    return(\@traces);
}                                       



sub fetch_Trace_Alignment_by_id  {
    my ($self, $id) = @_;
    return(1);
}


sub track_name {
    my ($self) = @_;    
    return("GlovarTrace");
}


1;
