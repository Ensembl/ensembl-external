# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor
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

package Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor;
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
  }

  my @f = ();
  if($is_light){
    push @f, @{$self->fetch_Light_Variations_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_Variations_by_chr_start_end($slice)};
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

sub fetch_Light_Variations_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    my $q1 = qq(
        SELECT                                                                                                                                  
                mapped_snp.position + seq_seq_map.START_COORDINATE -1                                                                       
                                                as chr_start,                                                                                
                mapped_snp.id_snp               as internal_id,                                                                              
                seq_seq_map.contig_orientation  as chr_strand,                                                                               
                snp_name.snp_name               as id_refsnp,                                                                                
                'glovar'                        as source,                                                                                   
                'snp'                           as snpclass,                                                                                 
                svd.description                 as type,                                                                                     
                snp.is_private                  as private,                                                                                     
                snpf.allele_txt(snp.id_snp)     as alleles,                                                                                  
                scd.description                 as validated                                                                                 
        FROM    chrom_seq,                                                                                                                   
                seq_seq_map,                                                                                                                 
                snp_sequence,                                                                                                                
                mapped_snp,                                                                                                                  
                snp_name,                                                                                                                    
                snp,                                                                                                                         
                snpvartypedict svd,                                                                                                          
                snp_confirmation_dict scd,                                                                                                   
                database_dict                                                                                                                
        WHERE   chrom_seq.DATABASE_SEQNAME= '$slice_chr'                                                                                             
        AND     chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ                                                                              
        AND     snp_sequence.ID_SEQUENCE = seq_seq_map.SUB_SEQUENCE                                                                          
        AND     mapped_snp.ID_SEQUENCE = snp_sequence.ID_SEQUENCE                                                                            
        AND     snp_name.id_snp = mapped_snp.id_snp                                                                                          
        AND     snp.id_snp = snp_name.id_snp                                                                                                 
        AND     snp.var_type = svd.id_dict                                                                                                   
        AND     snp.is_confirmed = scd.id_dict                                                                                               
        AND     snp_name.snp_name_type = 1                                                                                                   
        AND     chrom_seq.DATABASE_SOURCE = database_dict.ID_DICT                                                                            
        AND     database_dict.DATABASE_NAME = '$ass_name'                                                                                         
        AND     database_dict.DATABASE_VERSION = '$ass_version'                                                                                        
        AND     (mapped_snp.position + seq_seq_map.START_COORDINATE -1) 
        BETWEEN                                                              
                '$slice_start' AND '$slice_end'                                                                                                              
        ORDER BY 
                chr_start                                                                                                                   
    );

      my $q2 = qq(SELECT ms.id_sts,
               (ms.start_coordinate + ssm.start_coordinate -1) as start_coord,
               (ms.end_coordinate + ssm.start_coordinate -1) as end_coord,
               ss.sts_name,
               ss.id_sts as sts_id,
               length(ss.sense_oligoprimer) as sen_len,
               length(ss.antisense_oligoprimer) as anti_len,
               ss.pass_status,
               ms.is_revcomp as ori
        FROM   chrom_seq cs,
               database_dict dd,
               seq_seq_map ssm,
               mapped_sts ms,
               sts_summary ss
        WHERE  cs.database_seqname = '$slice_chr'
        AND    dd.id_dict = cs.database_source
        AND    dd.database_name = '$ass_name'
        AND    dd.database_version = '$ass_version'
        AND    ssm.id_chromseq = cs.id_chromseq
        AND    ms.id_sequence = ssm.sub_sequence
        AND    ss.id_sts = ms.id_sts
        AND    (ms.start_coordinate + ssm.start_coordinate) 
        BETWEEN 
                '$slice_start' 
        AND 
                '$slice_end'
        ORDER BY 
                end_coord
        
        );
    
    my @vars = ();
    my $sth;

    eval {
        $sth = $self->prepare($q1);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Variations_by_chr_start_end()!\n$@");
        return([]);
    }

    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        if ($rowhash->{'PRIVATE'}){
            #print Dumper($rowhash);
            next;
        }
        #print STDERR Dumper($rowhash);
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $rowhash->{'ID_REFSNP'},
                'dbID'          =>    $rowhash->{'INTERNAL_ID'},
                '_gsf_start'    =>    $rowhash->{'CHR_START'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'CHR_START'} - $slice_start + 1,
                '_snp_strand'   =>    $rowhash->{'CHR_STRAND'},
                '_gsf_score'    =>    -1,
                '_type'         =>    '_',
                '_validated'    =>    $rowhash->{'VALIDATED'},
                'alleles'       =>    $rowhash->{'ALLELES'},
                '_snpclass'     =>    $rowhash->{'SNPCLASS'},
                '_source_tag'   =>    $rowhash->{'SOURCE'},
            });

        my $link = Bio::Annotation::DBLink->new();
        $link->database("dbSNP");
        $link->primary_id($rowhash->{'ID_REFSNP'});
        $var->add_DBLink($link);
        #print STDERR Dumper($var);
        push (@vars,$var); 
    }
    
    return(\@vars);

    ############# for STSs  ###############
    eval {
        $sth = $self->prepare($q2);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Variations_by_chr_start_end()!\n$@");
        return([]);
    }

    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        #print STDERR Dumper($rowhash);
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $rowhash->{'STS_NAME'},
                'dbID'          =>    $rowhash->{'STS_NAME'},
                '_gsf_start'    =>    $rowhash->{'START_COORD'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'END_COORD'} - $slice_start + 1,
                '_snp_strand'   =>    -1,
                '_gsf_score'    =>    -1,
                '_type'         =>    '_',
                '_validated'    =>    $rowhash->{'VALIDATED'},
                'alleles'       =>    $rowhash->{'ALLELES'},
                '_source_tag'   =>    $rowhash->{'SOURCE'},
            });

        my $link = Bio::Annotation::DBLink->new();
        $link->database("dbSNP");
        $link->primary_id($rowhash->{'ID_REFSNP'});
        $var->add_DBLink($link);
        #print STDERR Dumper($var);
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

    my @vars = ();
    return(\@vars);
}                                       

sub fetch_Variation_by_id  {
    my ($self, $id) = @_;
    return(1);
}


sub track_name {
    my ($self) = @_;    
    return("GlovarSNP");
}


1;
