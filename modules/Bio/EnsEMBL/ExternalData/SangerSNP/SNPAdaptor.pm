# EnsEMBL Sanger SNP adaptor 
#
# Copyright EnsEMBL
#
# Author: Steve Searle
# 

=head1 NAME

Bio::EnsEMBL::ExternalData::SangerSNP::SNPAdaptor

=head1 SYNOPSIS

A SNP adaptor which sits over the Sanger SNP database.  Provides a means of 
getting SNPs out of the Sanger SNP database as 
Bio::EnsEMBL::ExternalData::Variation objects. 

=head1 CONTACT

Post questions to the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk> 

=head1 APPENDIX

=cut

use strict;

package Bio::EnsEMBL::ExternalData::SangerSNP::SNPAdaptor;

use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::SNP;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::External::ExternalFeatureAdaptor );


sub fetch_all_by_chr_start_end {
  my ($self,$chr,$start,$end) = @_;

  my $assembly = $self->dbc->assembly_type;
  
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

sub _objFromHashref {
  my ($self,$info) = @_;
  
  my $acc_version = '';
  my $acc = $info->{acc};
  my $ver = $info->{version};
  $acc_version .= uc $acc if $acc;
  $acc_version .= ".$ver" if $ver;
  
  my $snp = new Bio::EnsEMBL::ExternalData::Variation;
  
  $snp->acc($info->{acc});
  $snp->version($info->{version});
  $snp->seqname($acc_version);
  $snp->start($info->{start});
  $snp->end($info->{end});
  $snp->strand($info->{strand});
  $snp->source_tag('dbSNP');
  #$snp->status($info->{confirmed});
  $snp->alleles($info->{observed});
  $snp->upStreamSeq($info->{seq5});
  $snp->dnStreamSeq($info->{seq3});
  $snp->score($info->{mapweight}); 
  #$snp->het($info->{het});
  #$snp->hetse($info->{hetse});
  $snp->snpid($info->{id});
  $snp->snpclass($info->{snpclass});

  #DBLink
  my $link = new Bio::Annotation::DBLink;
  $link->database('dbSNP');
  $link->primary_id($info->{id});
  
  #add dbXref to Variation
  $snp->add_DBLink($link);
  
  return $snp;
}
  

1;
