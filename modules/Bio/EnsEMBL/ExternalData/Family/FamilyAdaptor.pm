# $Id$
# BioPerl module for Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor
#
# Cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
#
# Copyright Philip Lijnzaad
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a database of protein families.

=head1 SYNOPSIS

my $famdb=Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor\
                               ->new(-dbname=>'anton-1', 
                                     -host=>'ecs1c', 
                                     -user=>'ensadmin');
my $fam, @fam;

$fam = $famdb->get_Family_by_id('ENSF000013034');  # family id
$fam = $famdb->get_Family_of_Ensembl_id('ENSP00000012304');
$fam = $famdb->get_Family_of_db_id('SWISSPROT', 'P000123');
@fam = $famdb->get_Family_described_as('interleukin');
@fam = $famdb->all_Families();

=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
# use Bio::Root::RootI;
use DBI;
#use Bio::EnsEMBL::DBLoader; ??

use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Family::Family;
use vars qw(@ISA);


@ISA = qw(Bio::Root::Object);
# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

# set stuff in self from @args
 return $make; # success - we hope!
}

=head2 new

 Title   : new
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub new{
   my ($class,@args) = @_;

   my $self = bless {}, $class;
    
   my ($db,$host,$driver,$user,$password,$debug,$ensdb,$famdb) = 
      $self->_rearrange([qw(DBNAME
			    HOST
			    DRIVER
			    USER
			    PASS
			    DEBUG
			    ENSDB
			    FAMDB
			    )],@args);

    $driver || ( $driver = 'mysql' );
    $host   || ( $host = 'localhost' );
    $db     || ( $db = 'family' );
    $user   || ( $user = 'ensembl' );   
#    $ensdb  || $self->throw("I need ensembl db obj"); ? 
    $famdb  || $self->throw("I need family db obj");
   
#     $self->_ensdb($ensdb); 
    $self->_famdb($famdb); 

   my $dsn = "DBI:$driver:database=$db;host=$host";
   my $dbh = DBI->connect("$dsn","$user",$password,{RaiseError => 1});
   $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
   $self->_db_handle($dbh);
}                                       # new


sub get_Family_by_id  {# ('ENSF000013034');           # get family, given id
    my ($self) = @_; 
    $self->throw("not yet implemented");
} 

sub get_Family_of_Ensembl_id { # ('ENSP00000012304'); # family _of_ an entry
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

sub get_Family_of_db_id{ # ('SWISSPROT', 'P000123')  # family of any entry
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

sub get_Families_described_as{ # ('interleukin'); # families that contain this
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

sub all_Families(){ 
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

# set/get handle on ensembl database
sub _ensdb 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_ensdb'} = $value;}
  
  return $self->{'_ensdb'};
}

# get/set handle on family database
sub _famdb 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_famdb'} = $value;}
  
  return $self->{'_famdb'};
}


sub _get_family_objects {
    my ($self, $query) = @_;

    $self->throw("not yet implemented");

    $query = $self->_db_handle->prepare($query);
    $query->execute;
    
    my $id; 
    my $fam;
    my @fams;

#     while ( my $rowhash = $query->fetchrow_hashref) {
# 
#         ...;
#         $fam = new Bio::EnsEMBL::ExternalData::Family::Family(
#                                                               ...;
#                                                               );
#     }
}


sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
}


sub _prepare
{
    my ($self,$string) = @_;
    
    if( ! $string ) {$self->throw("Attempting to prepare an empty SQL query!");}
    
    my( $sth );
    eval {$sth = $self->_db_handle->prepare($string);};
    $self->throw("Error preparing $string\n$@") if $@;
    return $sth;
    
}


sub _ensdb 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_ensdb'} = $value;}
  
  return $self->{'_ensdb'};
}

