#
# BioPerl module for DBDAS::DASAdaptor
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBDAS::DBAdaptor - Object representing an instance of a DAS DB connection

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::DBDAS::DASAdaptor->new(
        -url   => 'http://servlet.sanger.ac.uk:8080/das',
        -dsn   => 'ensembl100',
        );

    @features  = $db->get_Features('X45667.00001');

    

=head1 DESCRIPTION

This object represents a DAS database that is implemented somehow (you shouldn\'t
care much as long as you can get the object). From the object you can pull
out other objects by their stable identifier. 

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::DBDAS::DASAdaptor;

use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;
use Bio::Das;
use Bio::EnsEMBL::DBDAS::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::Root Bio::EnsEMBL::DBDAS::BaseAdaptor);

sub new {
	my($pkg, @args) = @_;

	my $self = bless {}, $pkg;

    my ( $url, $dsn, $ensdb, $proxy_url ) = $self->_rearrange([qw( URL DSN ENSDB PROXY_URL )],@args);

    $url   || $self->throw("DAS database adaptor must be given a database url");
    $dsn   || $self->throw("DAS database adaptor must be given a DSN (data source name)");

    my $dbh = Bio::Das->new(30);
    if (defined $proxy_url){
        $dbh->proxy($proxy_url);
        warn "Setting proxy URL to $proxy_url for $dsn\n";
    }
    $self->_db_handle($dbh);
    $self->dsn($dsn);
    $self->url($url);
    $self->ensembldb($ensdb);

    return $self; # success - we hope!
}


=head2 ensembldb

 Title   : ensembldb
 Usage   : $obj->ensembldb($ensdb)
 Function: store an Ensembl database handle
 Returns : 
 Args    : none


=cut

sub ensembldb {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_ensembldb'} = $value;
    }
    return $self->{'_ensembldb'};
}


=head2 url

 Title   : url
 Usage   : $obj->url("http://www.there.co.uk/das")
 Function: store a DAS data source URL
 Returns : 
 Args    : none


=cut

sub url {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_url'} = $value;
    }
    return $self->{'_url'};
}


=head2 dsn

 Title   : dsn
 Usage   : $obj->dsn("source")
 Function: select a DAS data source
 Returns : 
 Args    : none


=cut

sub dsn {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_dsn'} = $value;
    }
    return $self->{'_dsn'};
}


=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function: 
 Example : 
 Returns : value of _db_handle
 Args    : newvalue (optional)


=cut

sub _db_handle{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_db_handle'} = $value;
    }
    return $self->{'_db_handle'};

}


=head2 _debug

 Title   : _debug
 Usage   : $obj->_debug($newval)
 Function: 
 Example : 
 Returns : value of _debug
 Args    : newvalue (optional)


=cut

sub _debug{
    my ($self,$value) = @_;
    if( defined $value) {
		$self->{'_debug'} = $value;
    }
    return $self->{'_debug'};
    
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
   my ($obj) = @_;

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'} = undef;
   }
}



1;
