=head1 NAME

Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor - 
Database adaptor for a Glovar database

=head1 SYNOPSIS

    $db_adaptor = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
        -user   => 'root',
        -pass   => 'secret',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'Oracle'
        );
    $snp_adaptor = $db_adaptor->get_GlovarSNPAdaptor;
    
=head1 DESCRIPTION

This object represents a Glovar database Once created you can retrieve object
adaptors that allow you to create objects from data in the Glovar database.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;

use strict;
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

    # be very sneaky and actually return a container object which is outside of
    # the circular reference loops and will perform cleanup when all references
    # to the container are gone.
    return new Bio::EnsEMBL::Container($self);
}

=head2 get_GlovarAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $glovar_adaptor = $db_adaptor->get_GlovarAdaptor;
  Description: Retrieves a glovar adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor');
}

=head2 get_GlovarSNPAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $snp_adaptor = $db_adaptor->get_GlovarSNPAdaptor;
  Description: Retrieves a glovar SNP adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarSNPAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor');
}

=head2 get_GlovarBaseCompAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $basecomp_adaptor = $db_adaptor->get_GlovarBaseCompAdaptor;
  Description: Retrieves a glovar base composition adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarBaseCompAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarBaseCompAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarBaseCompAdaptor');
}

=head2 get_GlovarSTSAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $sts_adaptor = $db_adaptor->get_GlovarSTSAdaptor;
  Description: Retrieves a glovar STS adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarSTSAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor');
}

=head2 get_GlovarTraceAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $trace_adaptor = $db_adaptor->get_GlovarTraceAdaptor;
  Description: Retrieves a glovar trace adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarTraceAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor');
}

=head2 get_GlovarHaplotypeAdaptor

  Arg [1]    : none
  Example    :
        my $db_adaptor = new Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor;
        my $haplotype_adaptor = $db_adaptor->get_GlovarHaplotypeAdaptor;
  Description: Retrieves a glovar haplotype adaptor
  Returntype : Bio::EnsEMBL::ExternalData::Glovar::GlovarHaplotypeAdaptor
  Exceptions : none
  Caller     : EnsEBML::Web::DB::Core, EnsEBML::Web::DB::DBConnection, general

=cut

sub get_GlovarHaplotypeAdaptor {
    my $self = shift;
    return $self->_get_adaptor('Bio::EnsEMBL::ExternalData::Glovar::GlovarHaplotypeAdaptor');
}

1;
