# EnsEMBL Sanger SNP adaptor 
#
# Copyright EnsEMBL
#
# Author: Steve Searle
# 

=head1 NAME

Bio::EnsEMBL::ExternalData::SangerSNP::TranscriptVariationAdaptor

=head1 SYNOPSIS

A SNP adaptor which sits over the Sanger SNP database.  Provides a means of 
getting SNPs out of the Sanger SNP database as 
Bio::EnsEMBL::Variation::VariationFeature objects. 

=head1 CONTACT

Post questions to the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk> 

=head1 APPENDIX

=cut

use strict;

package Bio::EnsEMBL::ExternalData::SangerSNP::TranscriptVariationAdaptor;

use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::Variation::TranscriptVariation;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::External::ExternalFeatureAdaptor );


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

sub fetch_all_by_VariationFeatures {
  my ($self, @varfeat) = @_;

  print "NOT IMPLEMENTED\n";
    
}
#    my $q = qq(
#        SELECT
#                ptd.description         as pos_type,
#                sgc_dict.description    as consequence,
#                cs.name                 as transcript_stable_id,
#                sgc.transcript_position as cdna_start
#        FROM    
#                coding_sequence cs,
#                snp_gene_consequence sgc
#        LEFT JOIN
#                position_type_dict ptd on sgc.position_description = ptd.id_dict
#        LEFT JOIN
#                sgc_dict on sgc.consequence = sgc_dict.id_dict
#        WHERE   sgc.id_snp = ?
#        AND     sgc.id_codingseq = cs.id_codingseq
#        AND     cs.design_entry = ?
#    );
#    my $sth;
#    eval {
#        $sth = $self->prepare($q);
#        $sth->execute($varfeat->dbID, $self->consequence_exp);
#    }; 
#    if ($@){
#        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
#        return;
#    }
#
#    while (my $row = $sth->fetchrow_hashref) {
#        print "Consequence for " . $varfeat->variation_name . " " . $row->{'POS_TYPE'} . " " . $row->{'CONSEQUENCE'} . "\n";
#        # add consequence
##        my $consequence_type = $CONSEQUENCE_TYPE_MAP{$row->{'POS_TYPE'}." ".$row->{'CONSEQUENCE'}};
##        $varfeat->add_consequence_type($consequence_type);
##
##        # add TranscriptVariation object
##        my $trans = Bio::EnsEMBL::Transcript->new(
##            -STABLE_ID => $row->{'TRANSCRIPT_STABLE_ID'},
##        );
##        my $tvar = Bio::EnsEMBL::Variation::TranscriptVariation->new_fast({
##            transcript          => $trans,
##            cdna_start          => $row->{'CDNA_START'},
##            cdna_end            => $row->{'CDNA_START'},
##            consequence_type    => $consequence_type,
##        });
##        $varfeat->add_TranscriptVariation($tvar);
#    }
#}

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
