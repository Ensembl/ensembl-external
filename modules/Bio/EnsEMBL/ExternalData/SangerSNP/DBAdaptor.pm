#$Id$
#
# BioPerl module for Bio::EnsEMBL::ExternalData::SangerSNP::DBAdaptor
#
# Cared for by Steve Searle <searle@sanger.ac.uk
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::SangerSNP::DBAdaptor - Class for the Sanger SNP
database providing external features for EnsEMBL

=head1 SYNOPSIS

e "Bio::EnsEMBL::Extern
    $snpdb = Bio::EnsEMBL::ExternalData::SangerSNP::DBAdaptor->new( -dbname => 'snp'
							  -user => 'root'
							  );


=head1 DESCRIPTION

This object is an abstraction over the Sanger SNP database.  Adaptors can
be obtained for the database to allow for the storage or retrival of objects
stored within the database.



=head1 AUTHOR - Steve Searle

  Email searle@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::ExternalData::SangerSNP::DBAdaptor;

#use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::ExternalData::SangerSNP::DBConnection;

use strict;
use vars qw(@ISA);

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::EnsEMBL::ExternalData::SangerSNP::DBConnection);



#use the DBConnection superclass constructor


=head2 get_SNPAdaptor

  Function  : Retrieves a SNPAdaptor from this database
  Returntype: Bio::EnsEMBL::ExternalData::SangerSNP::SNPAdaptor
  Exceptions: none
  Caller    : 

=cut

sub get_SNPAdaptor {
  my $self = shift;

  return $self->_get_adaptor("Bio::EnsEMBL::ExternalData::SangerSNP::SNPAdaptor");
}


1;
