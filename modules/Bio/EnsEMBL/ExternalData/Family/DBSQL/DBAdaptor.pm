
=head1 NAME - Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::DBSQL::ExternalData::Family::DBAdaptor->new(
								    -user   => 'myusername',
								    -dbname => 'familydb',
								    -host   => 'myhost',
								   );

    $family_adaptor  = $db->get_FamilyAdaptor();
    $familymember_adaptor  = $db->get_FamilyMemberAdaptor();

=head1 DESCRIPTION

This object represents a database that is implemented somehow (you shouldn\'t
care much as long as you can get the object). From the object you can pull
out other objects by their stable identifier, such as Clone (accession number),
Exons, Genes and Transcripts. The clone gives you a DB::Clone object, from
which you can pull out associated genes and features. 

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::EnsEMBL::Root to deal with bioperl1<->bioperl07 migration

use Bio::EnsEMBL::Root;
use DBI;

@ISA = qw(Bio::EnsEMBL::Root);

sub new {
  my($class, @args) = @_;

  my $self = bless {}, $class;

  my (
      $db,
      $host,
      $driver,
      $user,
      $password,
      $port,
     ) = $self->_rearrange([qw(
			       DBNAME
			       HOST
			       DRIVER
			       USER
			       PASS
			       PORT
			      )],@args);
  $db   || $self->throw("Database object must have a database name");
  $user || $self->throw("Database object must have a user");

  unless (defined $driver) {
    $driver = 'mysql';
  }
  unless (defined $host) {
    $host = 'localhost';
  }
  unless (defined $port) {
    $port = 3306;
  }
  unless (defined $password) {
    $password = "";
  }

  my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";

  my $dbh;
  eval {
    $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});
  };
    
  $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator\n"
			 . $DBI::errstr);
    
  $self->_db_handle($dbh);

  $self->username($user);
  $self->dbname($db);
  $self->host($host);
  $self->password($password);

  return $self
}


=head2 get_FamilyAdaptor

    my $family_adaptor = $db->get_FamilyAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor>
object, which is used for reading and writing
B<Bio::EnsEMBL::ExternalData::Family::Family> objects from and to the SQL database.

=cut 

sub get_FamilyAdaptor {
  my ($self) = @_;
  
  my $adaptor;
  unless ($adaptor = $self->{'_family_adaptor'}) {
    require Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor;
    $adaptor = Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor->new($self);
    $self->{'_family_adaptor'} = $adaptor;
  }

  return $adaptor;
}

=head2 get_FamilyMemberAdaptor

    my $familymember_adaptor = $db->get_FamilyMemberAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor>
object, which is used for reading and writing
B<Bio::EnsEMBL::ExternalData::FamilyMember> objects from and to the SQL database.

=cut 

sub get_FamilyMemberAdaptor {
  my ($self) = @_;
  
  my $adaptor;
  unless ($adaptor = $self->{'_familymember_adaptor'}) {
    require Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor;
    $adaptor = Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor->new($self);
    $self->{'_familymember_adaptor'} = $adaptor;
  }

  return $adaptor;
}

=head2 get_TaxonAdaptor

    my $taxon__adaptor = $db->get_TaxonAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor>
object, which is used for reading and writing
B<Bio::Species> objects from and to the SQL database.

=cut 

sub get_TaxonAdaptor {
  my ($self) = @_;
  
  my $adaptor;
  unless ($adaptor = $self->{'_taxon_adaptor'}) {
    require Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor;
    $adaptor = Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor->new($self);
    $self->{'_taxon_adaptor'} = $adaptor;
  }

  return $adaptor;
}

sub dbname {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_dbname} = $value;
  }

  return $self->{_dbname};
}

sub username {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_username} = $value;
  }

  return $self->{_username};
}

sub host {
  my ($self, $value) = @_;
  
  if (defined $value) {
    $self->{_host} = $value;
  }

  return $self->{_host};
}

sub password {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_password} = $value;
  }

  return $self->{_password};
}

=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function: 
 Example : 
 Returns : value of _db_handle
 Args    : newvalue (optional)


=cut

sub _db_handle {
  my ($self,$value) = @_;

  if (defined $value) {
    $self->{'_db_handle'} = $value;
  }
  
  return $self->{'_db_handle'};

}

=head2 _lock_tables

 Title   : _lock_tables
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _lock_tables{
  my ($self,@tables) = @_;
  
  my $state;
  foreach my $table ( @tables ) {
    if( $self->{'_lock_table_hash'}->{$table} == 1 ) {
      $self->warn("$table already locked. Relock request ignored");
    } else {
      if( $state ) { $state .= ","; } 
      $state .= "$table write";
      $self->{'_lock_table_hash'}->{$table} = 1;
    }
  }
  
  my $sth = $self->prepare("lock tables $state");
  my $rv = $sth->execute();
  $self->throw("Failed to lock tables $state") unless $rv;
  
}

=head2 _unlock_tables

 Title   : _unlock_tables
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _unlock_tables{
  my ($self,@tables) = @_;
  
  my $sth = $self->prepare("unlock tables");
  my $rv  = $sth->execute();
  $self->throw("Failed to unlock tables") unless $rv;
  %{$self->{'_lock_table_hash'}} = ();
}


=head2 prepare

 Title   : prepare
 Usage   : $sth = $dbobj->prepare("select seq_start,seq_end from feature where analysis = \" \" ");
 Function: prepares a SQL statement on the DBI handle
 Example :
 Returns : A DBI statement handle object
 Args    : a SQL string


=cut

sub prepare {
   my ($self,$string) = @_;

   unless (defined $string) {
     $self->throw("Attempting to prepare an empty SQL query!");
   }
   unless (defined $self->_db_handle) {
     $self->throw("Database object has lost its database handle! getting otta here!");
   }

   return $self->_db_handle->prepare($string);
}

=head2 DESTROY

 Title   : DESTROY
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub DESTROY {
  my ($self) = @_;

  #$obj->_unlock_tables();

  if (defined $self->{'_db_handle'}) {
    $self->{'_db_handle'}->disconnect;
    $self->{'_db_handle'} = undef;
  }

}

1;
