# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor
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

package Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use vars qw(@ISA);
use strict;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::SNP;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::External::ExternalFeatureAdaptor);


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

  my $vars;
  if($is_light){
    return $vars = $self->fetch_Light_Variations_by_chr_start_end($slice);
  } else {
    return $vars = $self->fetch_Variations_by_chr_start_end($slice);
  }  
}


=head2 fetch_Light_Variations_by_chr_start_end

 Title   : fetch_Light_Variations_by_chr_start_end
 Usage   : $db->fetch_Light_Variations_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_Variations_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $assembly     = $slice->assembly_type();
    
    my ($ass_name,$ass_version) = $slice->assembly_type() =~ /([A-Za-z]+)(\d+)/; # NCBI33 -> NCBI,33

    my $q = qq(SELECT distinct
           (mapped_snp.position + seq_seq_map.START_COORDINATE -1) as snppos,
           snp_name.snp_name as snp_name,
           snp.is_confirmed as confirmed,
           snp.is_private as private
    FROM chrom_seq,
         seq_seq_map,
         snp_sequence,
         mapped_snp,
         snp_name,
         snp,
         database_dict
    WHERE chrom_seq.DATABASE_SEQNAME='$slice_chr'
    AND chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
    AND snp_sequence.ID_SEQUENCE = seq_seq_map.SUB_SEQUENCE
    AND mapped_snp.ID_SEQUENCE = snp_sequence.ID_SEQUENCE
    AND snp_name.id_snp = mapped_snp.id_snp
    AND snp.id_snp = snp_name.id_snp
    AND snp_name.snp_name_type = 1
    AND chrom_seq.DATABASE_SOURCE = database_dict.ID_DICT
    AND database_dict.DATABASE_NAME = '$ass_name'
    AND database_dict.DATABASE_VERSION = '$ass_version'
    AND (mapped_snp.position + seq_seq_map.START_COORDINATE -1) BETWEEN '$slice_start' AND '$slice_end'
    ORDER BY SNPPOS
    );
    
    my $sth = $self->prepare($q);
    $sth->execute();

    my @vars = ();
    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        if ($rowhash->{'PRIVATE'}){
            print Dumper($rowhash);
        }
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                'dbID'          =>    $rowhash->{'SNP_NAME'},
                '_gsf_start'    =>    $rowhash->{'SNPPOS'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'SNPPOS'} - $slice_start + 1,
                '_snp_strand'   =>    -1,
            });

        push (@vars,$var); 
        
    }
    
    return(\@vars);
}                                       

=head2 fetch_Variations_by_chr_start_end

 Title   : fetch_Variations_by_chr_start_end
 Usage   : $db->fetch_Variations_by_chr_start_end($slice);
 Function: find full variations by chromosomal location.
 Example :
 Returns : a list ref SNP objects.
 Args    : slice

=cut

sub fetch_Variations_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $assembly     = $slice->assembly_type();
    
    my ($ass_name,$ass_version) = $slice->assembly_type() =~ /([A-Za-z]+)(\d+)/; # NCBI33 -> NCBI,33

    my $q = qq(SELECT distinct
           (mapped_snp.position + seq_seq_map.START_COORDINATE -1) as snppos,
           mapped_snp.id_snp as snp_id,
           snp_name.snp_name as snp_name,
           snp.is_confirmed as status,
           snp.is_private as private,
           snpvartypedict.description as description,
           snpnametypedict.description as nametype,
           snp_variation.var_string as variation,
           allele_frequency.frequency as frequency
    FROM chrom_seq,
         seq_seq_map,
         snp_sequence,
         mapped_snp,
         snp_name,
         snp,
         snpvartypedict,
         snpnametypedict,
         snp_variation,
         allele_frequency,
         database_dict
    WHERE chrom_seq.DATABASE_SEQNAME='$slice_chr'
    AND chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
    AND snp_sequence.ID_SEQUENCE = seq_seq_map.SUB_SEQUENCE
    AND mapped_snp.ID_SEQUENCE = snp_sequence.ID_SEQUENCE
    AND snp_name.id_snp = mapped_snp.id_snp
    AND snp.id_snp = snp_name.id_snp
    AND snp.id_snp = snp_variation.id_snp
    AND snp_name.snp_name_type = 1
    AND snp_variation.id_var = allele_frequency.id_var
    AND snp.var_type = snpvartypedict.ID_DICT
    AND snp_name.snp_name_type = snpnametypedict.ID_DICT
    AND chrom_seq.DATABASE_SOURCE = database_dict.ID_DICT
    AND database_dict.DATABASE_NAME = '$ass_name'
    AND database_dict.DATABASE_VERSION = '$ass_version'
    AND (mapped_snp.position + seq_seq_map.START_COORDINATE -1) BETWEEN '$slice_start' AND '$slice_end'
    ORDER BY SNPPOS
    );
    
    my $sth = $self->prepare($q);
    $sth->execute();

    my @vars = ();
    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        if ($rowhash->{'PRIVATE'}){
            print Dumper($rowhash);
        }
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                'dbID'          =>    $rowhash->{'SNP_NAME'},
                '_gsf_start'    =>    $rowhash->{'SNPPOS'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'SNPPOS'} - $slice_start + 1,
                '_snp_strand'   =>    -1,
            });

        push (@vars,$var); 
        
    }
    
    return(\@vars);
}                                       
sub fetch_Variation_by_id  {
    my ($self, $id) = @_;

    return(1);
}


sub track_name {
    my ($self) = @_;
    
    return("Glovar");
    
}


1;
