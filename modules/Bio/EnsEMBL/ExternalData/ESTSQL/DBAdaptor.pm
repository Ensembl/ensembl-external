
#
# BioPerl module for Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME


=head1 SYNOPSIS

   

=head1 DESCRIPTION

This is a DBAdaptor for the EST database.  The EST database only contains
two tables - an analysis table and a dna_feature_table of DnaDnaAlignFeatures.
This database is not standalone because the the features which are pulled out
make reference the contigs and the assembly so that they can be
converted to the assembly cooridinate system.  These calls are therefore 
forwarded to the core database adaptor which may be attached to this adaptor.

This may be cleaned up a bit with the advent of a database registry object.

=head1 FEEDBACK

=head2 Mailing Lists

=head1 AUTHOR

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor;

use Bio::EnsEMBL::DBSQL::DBConnection;
use DBI;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::DBSQL::DBConnection);

#new inherited from Bio::EnsEMBL::DBConnection


sub get_DnaAlignFeatureAdaptor {
  my $self = shift;

  return $self->_get_adaptor("Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor");
}

sub get_AnalysisAdaptor {
  my $self = shift;

  return $self->_get_adaptor("Bio::EnsEMBL::DBSQL::AnalysisAdaptor");
}


#
# Forward requests for the RawContigAdaptor to the core database
#
sub get_RawContigAdaptor {
  my $self = shift;

  my $core = $self->get_db_adaptor('core');;

  unless(defined $core) {
    $self->throw("No core database is attached to the ESTDatabase.  The EST "
		 . "database does not contain any contig information\n");
  }

  #if the core database is available use its raw contigs
  return $core->get_RawContigAdaptor();
}


1;











