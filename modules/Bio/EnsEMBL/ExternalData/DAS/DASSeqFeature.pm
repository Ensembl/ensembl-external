#
# BioPerl module for Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature - DAS specific sequence feature.

=head1 SYNOPSIS

    my $feat = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature(
						-seqname => 'pog',
					    -start   => 100,
					    -end     => 220,
					    -strand  => -1,
					    -frame   => 1,
					    -source_tag  => 'tblastn_vert',
					    -primary_tag => 'similarity',
					    -analysis => $analysis
						-das_dsn => 'foo',
						-das_name => 'bla',
						-das_id => 'blick',
					    );


=head1 DESCRIPTION

This is an extension of the ensembl Bio::EnsEMBL::SeqFeature.  Extra
methods are to store details of the DAS source used to create this data.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
	       		
use vars qw(@ISA $ENSEMBL_EXT_LOADED $ENSEMBL_EXT_USED );
use strict;


use Bio::EnsEMBL::SeqFeature;
use Bio::Root::RootI;

@ISA = qw( Bio::EnsEMBL::SeqFeature  Bio::Root::RootI);

sub das_dsn {
   my ($self,$arg) = @_;

   if( $arg) {
      $self->{'_das_dsn'} = $arg;
 
   }

    return $self->{'_das_dsn'};

}


sub das_name {
   my ($self,$arg) = @_;

   if( $arg) {
      $self->{'_das_name'} = $arg;
 
   }

    return $self->{'_das_name'};

}

sub das_id {
   my ($self,$arg) = @_;

   if( $arg) {
      $self->{'_das_id'} = $arg;
 
   }

    return $self->{'_das_id'};

}

1;
