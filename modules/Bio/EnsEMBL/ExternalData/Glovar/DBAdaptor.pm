use strict;

package Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Container;
use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw(Bio::EnsEMBL::DBSQL::DBConnection);


=head2 new

  Arg [DBNAME] : string
                 The name of the database to connect to.
  Arg [HOST] : (optional) string
               The domain name of the database host to connect to.  
               'localhost' by default. 
  Arg [USER] : string
               The name of the database user to connect with 
  Arg [PASS] : (optional) string
               The password to be used to connect to the database
  Arg [PORT] : int
               The port to use when connecting to the database
               3306 by default.
  Arg [DRIVER] : (optional) string
                 The type of database driver to use to connect to the DB
                 mysql by default.
  Example    :$dbc = new Bio::EnsEMBL::DBSQL::DBConnection(-user=> 'anonymous',
                                                           -dbname => 'pog',
							   -host   => 'caldy',
							   -driver => 'mysql');
  Description: Constructor for a DatabaseConenction. Any adaptors that require
               database connectivity should inherit from this class.
  Returntype : Bio::EnsEMBL::DBSQL::DBConnection 
  Exceptions : thrown if USER or DBNAME are not specified, or if the database
               cannot be connected to.
  Caller     : Bio::EnsEMBL::DBSQL::DBAdaptor

=cut

sub new {
  my $class = shift;

  my $self = {};
  bless $self, $class;

  my (
      $db,
      $host,
      $driver,
      $user,
      $password,
     ) = $self->_rearrange([qw(
			       DBNAME
			       HOST
			       DRIVER
			       USER
			       PASS
			      )],@_);
    

  $db   || $self->throw("Database object must have a database name");
  $user || $self->throw("Database object must have a user");

  $driver ||= 'Oracle';
  my $dsn =   "DBI:$driver:";
  my $dbh =    undef;

  eval{
        $dsn = "DBI:$driver:";
        my  $userstring = $user . "\@" . $db;
        $dbh = DBI->connect($dsn,$userstring,$password, { 
                                                    'RaiseError' => 1,
						                            'PrintError' => 0 
                                                  }); 
  };
    
  $dbh || $self->throw("Could not connect to database $db user " .
		       "$user using [$dsn] as a locator\n" . $DBI::errstr);

  $self->db_handle($dbh);
  $self->username( $user );
  $self->host( $host );
  $self->dbname( $db );
  $self->password( $password);
  $self->driver($driver);

  #be very sneaky and actually return a container object which is outside
  #of the circular reference loops and will perform cleanup when all references
  #to the container are gone.
  return new Bio::EnsEMBL::Container($self);
}

=head2 get_GlovarAdaptor

  Arg [1]    : none
  Example    : $glovar_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
  Description: Retrieves a glovar adaptor
  Returntype : none
  Exceptions : none
  Caller     : EnsWeb, general

=cut

sub get_GlovarAdaptor {
  my $self = shift;
  return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor');

}
sub get_GlovarSNPAdaptor {
  my $self = shift;
  return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor');

}
sub get_GlovarTraceAdaptor {
  my $self = shift;
  return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor');

}


