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
use Bio::EnsEMBL::Utils::Eprof qw( eprof_start eprof_end);
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::External::ExternalFeatureAdaptor );


sub fetch_all_by_chr_start_end {
  my ($self,$chr,$start,$end) = @_;

  #my $assembly = $self->assembly_type;

  my $assembly_name = 'NCBI';
  my $assembly_version = 31;

  my $query = qq {
    SELECT distinct
           chrom_seq.DATABASE_SEQNAME,
           snp_sequence.DATABASE_SEQNNAME,
           snp_name.SNP_NAME,
           (mapped_snp.position + seq_seq_map.START_COORDINATE -1) as snppos
    FROM chrom_seq,
         seq_seq_map,
         snp_sequence,
         mapped_snp,
         snp_name,
         database_dict
    WHERE chrom_seq.DATABASE_SEQNAME='$chr'
    AND   chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
    AND   snp_sequence.ID_SEQUENCE = seq_seq_map.SUB_SEQUENCE
    AND   mapped_snp.ID_SEQUENCE =snp_sequence.ID_SEQUENCE
    AND   snp_name.id_snp = mapped_snp.id_snp
    AND   snp_name.snp_name_type = 1
    AND   (mapped_snp.position + seq_seq_map.START_COORDINATE -1) >= $start 
    AND   (mapped_snp.position + seq_seq_map.START_COORDINATE -1) <= $end
    AND   chrom_seq.DATABASE_SOURCE = database_dict.ID_DICT
    AND   database_dict.DATABASE_NAME = '$assembly_name'
    AND   database_dict.DATABASE_VERSION = $assembly_version
    ORDER BY SNPPOS
  };

  my $sth = $self->prepare($query);

  $sth->execute;

  my @snps;
  while (my $hashref = $sth->fetchrow_hashref) {
    my $snp = new Bio::EnsEMBL::ExternalData::Variation(-start => $hashref->{SNPPOS},
                                                        -end   => $hashref->{SNPPOS},
                                                        -snpid => $hashref->{SNP_NAME},
                                                       );
                
    push @snps,$snp;
    
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
