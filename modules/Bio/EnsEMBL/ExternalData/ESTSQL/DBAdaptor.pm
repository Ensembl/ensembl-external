
#
# BioPerl module for Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME


=head1 SYNOPSIS

   

=head1 DESCRIPTION



=head1 FEEDBACK

=head2 Mailing Lists

=head1 AUTHOR

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor;

use Bio::EnsEMBL::ExternalData::ESTSQL::EstAdaptor;
use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use Bio::Root::RootI;
use DBI;

use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::ExternalFeatureFactoryI);



sub new {
    my($class,@args) = @_;
    my $self;
    $self = {};
    bless $self, $class;
    
    my ($db,$host,$port,$driver,$user,$password) =
	$self->_rearrange([qw(DBNAME
			      HOST
			      PORT
			      DRIVER
			      USER
			      PASS
			      )],@args);
    
    $db   || $self->throw("Database object must have a database name");
    $user || $self->throw("Database object must have a user");
    
    if( ! $driver ) {
	$driver = 'mysql';
    }
    if( ! $host ) {
	$host = 'localhost';
    }

    if (! $port ) {
	$port = 3306;
    }
    
    my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
    my $dbh = DBI->connect("$dsn","$user",$password);
    
    $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
    
    $self->_db_handle($dbh);
    
    return $self; # success - we hope!
}


=head2 get_EstAdaptor

 Title   : get_EstAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut


sub get_EstAdaptor {
  my $self = shift;

  if( ! defined $self->{_EstAdaptor} ) {
    $self->{_EstAdaptor} = Bio::EnsEMBL::ExternalData::ESTSQL::EstAdaptor->new( $self );
  }
  return $self->{_EstAdaptor};
}

=head2 get_Ensembl_SeqFeatures_contig

 Title   : get_Ensembl_SeqFeatures_contig
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_contig{
   my ($self,@args) = @_;

   return $self->get_EstAdaptor->get_Ensembl_SeqFeatures_contig(@args);

}

=head2 get_Ensembl_SeqFeatures_clone

 Title   : get_Ensembl_SeqFeatures_clone (Abstract)
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_clone{
   my ($self,@args) = @_;
   
   return $self->get_EstAdaptor->get_Ensembl_SeqFeatures_clone(@args);

}

=head2 get_Ensembl_Genes_clone

 Title   : get_Ensembl_Genes_clone
 Function: returns Gene objects in clone coordinates from a gene id
 Returns : An array of Gene objects
 Args    : clone id

=cut

sub get_Ensembl_Genes_clone {
    my $self = @_;

    $self->throw("get_Ensembl_Genes_clone is not valid for the est database");
}

=head2 get_SeqFeature_by_id

 Title   : get_SeqFeature_by_id (Abstract)
 Usage   : 
 Function: Return SeqFeature object for any valid unique id  
 Example :
 Returns : 
 Args    : id as determined by the External Database


=cut

       
sub get_SeqFeature_by_id {
   my ($self,$id) = @_;

   return $self->get_EstAdaptor->get_SeqFeature_by_id($id);

}

sub prepare {
  my $self = shift;
  my $query = shift;

  return $self->_db_handle->prepare( $query );
}


sub _db_handle {
  my $self = shift;
  my $handle = shift;
  
  if( defined $handle ) {
    $self->{_db_handle} = $handle;
  }

  return $self->{_db_handle};
}

1;











