# EnsEMBL Sanger SNP adaptor 
#
# Copyright EnsEMBL
#
# Author: Steve Searle
# 

=head1 NAME

Bio::EnsEMBL::ExternalData::SangerSNP::SangerSNPAdaptor

=head1 SYNOPSIS

A SNP adaptor which sits over the Sanger SNP database.  Provides a means of 
getting SNPs out of the Sanger SNP database as 
Bio::EnsEMBL::ExternalData::Variation objects. 

=head1 CONTACT

Post questions to the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk> 

=head1 APPENDIX

=cut

use strict;

package Bio::EnsEMBL::ExternalData::SangerSNP::SangerSNPAdaptor;

use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::SNP;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::External::ExternalFeatureAdaptor );


sub fetch_all_by_chr_start_end {
  my ($self,$chr,$start,$end) = @_;

  my $assembly = $self->ensembl_db->assembly_type;
  
  (my $assembly_name = $assembly) =~ s/[0-9]*$//;
  (my $assembly_version = $assembly) =~ s/[A-Z,a-z]*([0-9]*)$/$1/;

  my $query = qq {
SELECT DISTINCT MAPPED_SNP.ID_SNP,  
          (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) AS snppos,
          (MAPPED_SNP.IS_REVCOMP * SEQ_SEQ_MAP.CONTIG_ORIENTATION) AS snpstrand,
           SNP_SUMMARY.ALLELES,
           SNP_SUMMARY.DEFAULT_NAME
FROM     DATABASE_DICT,
         CHROM_SEQ,
         SEQ_SEQ_MAP,
         MAPPED_SNP,
         SNP_SUMMARY
WHERE     DATABASE_DICT.DATABASE_NAME = '$assembly_name'
    AND   DATABASE_DICT.DATABASE_VERSION = '$assembly_version'
    AND   CHROM_SEQ.DATABASE_SOURCE = DATABASE_DICT.ID_DICT
    AND   CHROM_SEQ.IS_CURRENT = 1
    AND   CHROM_SEQ.DATABASE_SEQNAME='$chr'
    AND   CHROM_SEQ.ID_CHROMSEQ = SEQ_SEQ_MAP.ID_CHROMSEQ
    AND   MAPPED_SNP.ID_SEQUENCE =SEQ_SEQ_MAP.SUB_SEQUENCE
    AND   SNP_SUMMARY.ID_SNP = MAPPED_SNP.ID_SNP
    AND   MAPPED_SNP.IS_REVCOMP IS NOT NULL
    AND   (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) BETWEEN $start AND $end
ORDER BY MAPPED_SNP.ID_SNP, SNPPOS
  };
#    AND   (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) <= $end

#Used to have this in query
#    AND   snp_name.snp_name_type = 1
#Put back in until snp_name table fixed
    # SNP_SEQUENCE.DATABASE_SEQNNAME,
           #SNPNAMETYPEDICT.ID_DICT,
    #AND   SNPNAMETYPEDICT.ID_DICT = SNP_NAME.SNP_NAME_TYPE
    #ORDER BY SNP_NAME.ID_SNP, SNPNAMETYPEDICT.ID_DICT, snppos
    #AND   (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) <= $end
#    SELECT distinct

# Tweaked query
#  my $query = qq {
#    SELECT 
#           CHROM_SEQ.DATABASE_SEQNAME,
#           SNP_NAME.SNP_NAME,
#           SNP_NAME.ID_SNP,
#           SNPNAMETYPEDICT.DESCRIPTION,
#           (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) as snppos,
#           MAPPED_SNP.IS_REVCOMP,
#           SEQ_SEQ_MAP.CONTIG_ORIENTATION,
#           SNP_VARIATION.VAR_STRING
#    FROM CHROM_SEQ,
#         SEQ_SEQ_MAP,
#         SNP_SEQUENCE,
#         MAPPED_SNP,
#         SNP_NAME,
#         SNP_VARIATION,
#         SNPNAMETYPEDICT,
#         DATABASE_DICT
#    WHERE CHROM_SEQ.DATABASE_SEQNAME='$chr'
#    AND   CHROM_SEQ.ID_CHROMSEQ = SEQ_SEQ_MAP.ID_CHROMSEQ
#    AND   SNP_SEQUENCE.ID_SEQUENCE = SEQ_SEQ_MAP.SUB_SEQUENCE
#    AND   MAPPED_SNP.ID_SEQUENCE = SNP_SEQUENCE.ID_SEQUENCE
#    AND   SNP_NAME.ID_SNP = MAPPED_SNP.ID_SNP
#    AND   SNP_VARIATION.ID_SNP = SNP_NAME.ID_SNP
#    AND   SNPNAMETYPEDICT.ID_DICT = SNP_NAME.SNP_NAME_TYPE
#    AND   (MAPPED_SNP.POSITION + SEQ_SEQ_MAP.START_COORDINATE -1) BETWEEN $start AND $end
#    AND   SNP_NAME.SNP_NAME_TYPE = 1
#    AND   CHROM_SEQ.DATABASE_SOURCE = DATABASE_DICT.ID_DICT
#    AND   DATABASE_DICT.DATABASE_NAME = '$assembly_name'
#    AND   DATABASE_DICT.DATABASE_VERSION = $assembly_version
#    ORDER BY SNP_NAME.ID_SNP,snppos
#  };

  my $sth = $self->prepare($query);

  print $sth->{Statement} . "\n";
  $sth->execute;
  print "Query finished\n";

  my @snps;

# Naughty but should speed things up a bit
  my $cur_snp_id = -1;
  my $snp;
  my %ids;
  my $hashref;
  while ($hashref = $sth->fetchrow_hashref) {
    
    next if exists($ids{$hashref->{ID_SNP}});

    my %snp_hash;
    $snp_hash{_gsf_start} = $snp_hash{_gsf_end} = $hashref->{SNPPOS};
    $snp_hash{_snp_strand} = $snp_hash{_gsf_strand} = $hashref->{SNPSTRAND};

    if ($hashref->{SNPSTRAND} != 1 && $hashref->{SNPSTRAND} != -1) {
      print STDERR "Got non 1 or -1 strand\n";
    }
    $snp_hash{dbID} = $hashref->{ID_SNP};
    $snp_hash{_snpid} = $hashref->{DEFAULT_NAME};
    $snp_hash{_gsf_sub_array} = [];

    $snp = Bio::EnsEMBL::SNP->new_fast(\%snp_hash);


    $snp->alleles($hashref->{ALLELES});

    push @snps,$snp;
    $ids{$hashref->{ID_SNP}} = 1;
  }

  return \@snps;
}

sub coordinate_systems {
  return ("ASSEMBLY");
}

  
=head2 get_consequences

  Arg[1]      : Bio::EnsEMBL::Variation::Variation object
  Example     : $glovar_adaptor->get_consequences($var);
  Description : Adds a TranscriptVariation object to the variation
  Return type : none
  Exceptions  : none
  Caller      : $self

=cut

sub get_consequences {
    my ($self, $varfeat) = @_;
    my $q = qq(
        SELECT
                ptd.description         as pos_type,
                sgc_dict.description    as consequence,
                cs.name                 as transcript_stable_id,
                sgc.transcript_position as cdna_start
        FROM    
                coding_sequence cs,
                snp_gene_consequence sgc
        LEFT JOIN
                position_type_dict ptd on sgc.position_description = ptd.id_dict
        LEFT JOIN
                sgc_dict on sgc.consequence = sgc_dict.id_dict
        WHERE   sgc.id_snp = ?
        AND     sgc.id_codingseq = cs.id_codingseq
        AND     cs.design_entry = ?
    );
    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute($varfeat->dbID, $self->consequence_exp);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return;
    }

    while (my $row = $sth->fetchrow_hashref) {
        print "Consequence for " . $varfeat->snpid . " " . $row->{'POS_TYPE'} . " " . $row->{'CONSEQUENCE'} . "\n";
        # add consequence
#        my $consequence_type = $CONSEQUENCE_TYPE_MAP{$row->{'POS_TYPE'}." ".$row->{'CONSEQUENCE'}};
#        $varfeat->add_consequence_type($consequence_type);
#
#        # add TranscriptVariation object
#        my $trans = Bio::EnsEMBL::Transcript->new(
#            -STABLE_ID => $row->{'TRANSCRIPT_STABLE_ID'},
#        );
#        my $tvar = Bio::EnsEMBL::Variation::TranscriptVariation->new_fast({
#            transcript          => $trans,
#            cdna_start          => $row->{'CDNA_START'},
#            cdna_end            => $row->{'CDNA_START'},
#            consequence_type    => $consequence_type,
#        });
#        $varfeat->add_TranscriptVariation($tvar);
    }
}

=head2 consequence_exp

  Arg[1]      : (optional) consequence experiment id
  Example     : $glovar_adaptor->consequence_ext(2046);
  Description : getter/setter for the consequence experiment
                (coding_sequence.design_entry in the glovar db)
  Return type : String - consequence experiment id
  Exceptions  : none
  Caller      : general

=cut

sub consequence_exp {
    my ($self, $exp) = @_;
    if ($exp) {
        $self->{'consequence_exp'} = $exp;
    }
    return $self->{'consequence_exp'};
}


1;
