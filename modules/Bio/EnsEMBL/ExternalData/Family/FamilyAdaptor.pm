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
#    $famdb  || $self->throw("I need family db obj");
   
#     $self->_ensdb($ensdb); 
    $self->_famdb($famdb); 

   my $dsn = "DBI:$driver:database=$db;host=$host";
   my $dbh = DBI->connect("$dsn","$user",$password,{RaiseError => 1});
   $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
   $self->_db_handle($dbh);
   $self;
}                                       # new

sub get_Family_by_id  {# ('ENSF000013034');           # get family, given id
    my ($self, $id) = @_; 

    my $q = 
      "SELECT internal_id, id, description, release, annotation_confidence_score
       FROM family
       WHERE id = '$id'";

    $self->_get_family($q);
}                                       # get_Family_by_id

# pull all fam's members from db
sub _get_members {
    my ($self, $fam) = @_;

    my $iid = $fam->internal_id;
    my $q = 
      "SELECT db_name, db_id
       FROM family_members
       WHERE family = $iid";

    $q = $self->_prepare($q);
    $q->execute;

    my ($rowhash, $n, $mem, $db_name, $db_id);

    while ( $rowhash = $q->fetchrow_hashref) {
        $fam->add_member( $rowhash->{db_name}, $rowhash->{db_id});
        $n++;
    }

    $self->throw("internal error; expecting at least one member for id $iid") 
      if ($n < 1);
    undef;
}

sub get_Family_of_Ensembl_id { # ('ENSP00000012304'); # family _of_ an entry
    my ($self, $eid) = @_; 

    $self->get_Family_of_db_id('ENSEMBLPEP', $eid);  #PL: what db_name ???
}

sub get_Family_of_db_id { # ('SWISSPROT', 'P000123')  # family of any entry
    my ($self, $db_name, $db_id) = @_; 

    my $q = 
      "SELECT f.internal_id, f.id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f, family_members fm
       WHERE f.internal_id = fm.family
         AND fm.db_name = '$db_name' 
         AND fm.db_id = '$db_id'"; 

    $self->_get_family($q);
}

sub get_Families_described_as{ # ('interleukin'); # families that contain this
    my ($self, $desc) = @_; 

    my $q = 
      "SELECT f.internal_id, f.id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f
       WHERE f.description LIKE '%". $desc . "%'";

    $self->_get_families($q);
}

sub all_Families() { 
    my ($self) = @_; 
    
    my $q = 
      "SELECT f.internal_id, f.id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f";
    $self->_get_families($q);
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
# get one or no family, given some query
sub _get_family {
    my ($self, $q) = @_;
    
    my @fams = $self->_get_families($q);
    
    if (@fams > 1) {
        $self->throw("internal error; expecting at most one Family");
    };
    return $fams[0];                    # may be undef
}                                       # _get_family

# get 0 or more families
sub _get_families {
    my ($self, $q) = @_;

    $q = $self->_prepare($q);
    $q->execute;

    my $rowhash =undef;
    my $fam;
    my @fams;
    while ( $rowhash = $q->fetchrow_hashref) {
        $self->throw("internal error: " . $self->errstr) if  $q->err;
        $fam = new Bio::EnsEMBL::ExternalData::Family::Family;

        $fam->internal_id($rowhash->{internal_id});
        $fam->id($rowhash->{id});
        $fam->description($rowhash->{description});
        $fam->release($rowhash->{release});
        $fam->annotation_confidence_score(
                                 $rowhash->{annotation_confidence_score});
        $self->_get_members($fam);
        push(@fams, $fam);
    }
    $self->throw("internal error: " . $self->errstr) if  $q->err;
    
    @fams;                              # maybe empty
}                                       # _get_families

sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
}


sub _prepare {
    my ($self,$string) = @_;
    
    if( ! $string ) {$self->throw("Attempting to prepare an empty SQL query!");}
    
    my $sth = $self->_db_handle->prepare($string);
    $self->throw("Error preparing statement $string:\n".$sth->errstr) 
      if (! $sth  or $sth->err);
    $sth;
}

sub DESTROY {
   my ($self) = @_;

#    my $sth = $self->_prepare("unlock tables");
#    my $rv  = $sth->execute();
#    $self->throw("Failed to unlock tables") unless $rv;
#    %{$self->{'_lock_table_hash'}} = ();

   if( $self->{'_db_handle'} ) {
       $self->{'_db_handle'}->disconnect;
       $self->{'_db_handle'} = undef;
   }
}
