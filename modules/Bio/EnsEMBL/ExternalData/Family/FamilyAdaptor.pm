# $Id$
# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor
# (i.e. for Anton Enright's Tribe database).
# 
# Cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a database of protein families.

=head1 SYNOPSIS

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::AlignIO;

$famdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                             -user   => 'ensro',
                                             -dbname => 'family102',
                                             -host   => 'ecs1b',
                                             -driver => 'mysql',
                                            );
my $fam_adtor = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($famdb);

$fam = $fam_adtor->fetch_by_stable_id('ENSF000013034');  # family id
$fam = $fam_adtor->fetch_by_dbname_id('SPTR', 'P000123');
@fam = $fam_adtor->fetch_by_description_with_wildcards('interleukin',1);
@fam = $fam_adtor->fetch_all();

### You can add the FamilyAdaptor as an 'external adaptor' to the 'main'
### Ensembl database object, then use it as:

$ensdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new( ... );

$ensdb->add_ExternalAdaptor('family', $fam_adtor);

# then later on, elsewhere: 
$fam_adtor = $ensdb->get_ExternalAdaptor('family');
# also available:
$ensdb->list_ExternalAdaptors();
$ensdb->remove_ExternalAdaptor('family');

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE algorithm by 
Anton Enright. The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can only be read from the database, not written. (They are
loaded ussing a separate perl script).

For more info, see Bio::EnsEMBL::ExternalData::Family

=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk> [original perl modules]
 Anton Enright <enright@ebi.ac.uk> [TRIBE algorithm]
 Elia Stupka elia@fugu-sg.org [refactoring]

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use vars qw(@ISA);
use strict;

use Bio::Annotation::DBLink;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_dbID{
   my ($self,$fid) = @_;

   my $q = 
       "SELECT family_id, stable_id, description, release, 
              annotation_confidence_score
       FROM family f
       WHERE family_id = $fid";
   
   $self->_get_family($q);
}    

=head2 store

 Title   : store
 Usage   : $famad->store($fam)
 Function: Stores a family object into the database
 Example : $famas->store($fam)
 Returns : dbID
 Args    : Bio::EnsEMBL::ExternalData::Family object

=cut

sub store{
   my ($self,$fam) = @_;

   $fam->isa('Bio::EnsEMBL::ExternalData::Family::Family') || $self->throw("You have to store a Bio::EnsEMBL::ExternalData::Family::Family object, not a $fam");

   my $q = "SELECT family_id from family where stable_id ='".$fam->stable_id."'";
   $q = $self->prepare($q);
   $q->execute();
   my $rowhash = $q->fetchrow_hashref;
   if ($rowhash->{family_id}) {
       #print STDERR "Family ".$fam->stable_id." already in the database with id ".$rowhash->{family_id}."\n";
       return $rowhash->{family_id};
   }

   $q = "INSERT INTO family (family_id, stable_id, description, release, annotation_confidence_score) VALUES (NULL,'".$fam->stable_id."','".$fam->description."','".$fam->release."',".$fam->annotation_confidence_score.")";
   $q = $self->prepare($q);
   $q->execute();
   my $fid = $self->get_last_id();
   foreach my $member ($fam->each_DBLink) {
       my $dbid = $self->_store_db_if_needed($member->database);
       $q = "INSERT INTO family_members (family_id, external_db_id, external_member_id) 
            VALUES ($fid,$dbid,'".$member->primary_id."')";
       $q = $self->prepare($q);
       $q->execute();
   }
   $self->_populate_totals($fid);
   return $fid;
}

sub _populate_totals {
    my ($self,$fid) = @_;
    
    my $q = "SELECT external_db_id,count(external_member_id) as total FROM family_members WHERE family_id = ".$fid." GROUP BY external_db_id";
    $q = $self->prepare($q);
    $q->execute();
    
    while (my $rowhash = $q->fetchrow_hashref) {
	my $q = "INSERT INTO family_totals (family_id,external_db_id,members_total) VALUES($fid,".$rowhash->{external_db_id}.",".$rowhash->{total}.")";
	$q = $self->prepare($q);
	$q->execute();
    }
}

sub _store_db_if_needed {
    my ($self,$db) = @_;

    my $q = "select external_db_id from external_db where name='".$db."'";
    $q = $self->prepare($q);
    $q->execute();
    my $rowhash = $q->fetchrow_hashref;
    if ($rowhash->{external_db_id}) {
	return $rowhash->{external_db_id};
    }
    else {
	$q = "INSERT INTO external_db (external_db_id,name) VALUES(NULL,'$db')";
	$q = $self->prepare($q);
	$q->execute();
	return $self->get_last_id();
    }
}

=head2 fetch_by_stable_id

 Title   : fetch_by_stable_id
 Usage   : $db->fetch_by_stable_id($id);
 Function: fetches a Family given its stable identifier
 Example : $db->fetch_by_stable_id('ENSF00000000009');
 Returns : a Family object if found, undef otherwise
 Args    : an EnsEMBL Family stable id

=cut

sub fetch_by_stable_id  {
    my ($self, $stable_id) = @_; 

    my $q = "SELECT family_id FROM family WHERE stable_id = '$stable_id'";
    $q = $self->prepare($q);
    $q->execute;
    my ($id) = $q->fetchrow_array;
    $id || $self->throw("Could not find family for stable id $stable_id");
    $self->fetch_by_dbID($id);
}                                       # fetch_by_stable_id

=head2 fetch_by_dbname_id

 Title   : fetch_of_dbname_id
 Usage   : $fam = $db->fetch_of_dbname_id($dbname,$dbid);
 Function: find the family to which the given database and id belong
 Example : $fam = $db->fetch_of_dbname_id('SPTR', 'P01235');
 Returns : a Family or undef if not found 
 Args    : a database name and a member identifier (display_id)

=cut

sub fetch_by_dbname_id { 
    my ($self, $dbname, $extm_id) = @_; 

    my $q = 
      "SELECT f.family_id, f.stable_id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f, family_members fm, external_db edb
       WHERE f.family_id = fm.family_id
         AND fm.external_db_id = edb.external_db_id
         AND edb.name = '$dbname' 
         AND fm.external_member_id = '$extm_id'"; 

    $self->_get_family($q);
}

=head2 fetch_by_description_with_wildcards

 Title   : fetch_by_description_with_wildcards
 Usage   : my @fams = $db->fetch_by_description_with_wildcards($desc);
 Function: simplistic substring searching on the description
 Example : my @fams = $db->fetch_by_description_with_wildcards('REDUCTASE',1);
 Returns : a (possibly empty) list of Families that either are named by the string,
           or contain the string (depending on the optional wildcard argument) 
           (The search is currently case-insensitive; this may change if
           SPTR changes to case-preservation)
 Args    : search string, optional wildcard (if set to 1, wildcards are added and the 
           search is a slower LIKE search)

=cut

sub fetch_by_description_with_wildcards{ 
    my ($self,$desc,$wildcard) = @_; 

    my $query = $desc;
    my $q;
    if ($wildcard) {
	$query = "%"."\U$desc"."%";
        $q = 
	    "SELECT f.family_id, f.stable_id, f.description, 
                    f.release, f.annotation_confidence_score
               FROM family f
              WHERE f.description LIKE '$query'";
    }
    else {
	$q = 
	    "SELECT f.family_id, f.stable_id, f.description, 
                    f.release, f.annotation_confidence_score
               FROM family f
              WHERE f.description = '$query'";
    }
    $self->_get_families($q);
}

=head2 fetch_all

 Title   : fetch_all
 Usage   : 
 Function: return all known families (use with care)
 Example :
 Returns : 
 Args    : 

=cut


sub fetch_all { 
    my ($self) = @_; 

    my $q = 
      "SELECT f.family_id, f.stable_id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f";
    $self->_get_families($q);
}

=head2 known_databases

 Title   : known_databases
 Usage   : 
 Function: return all names of databases being cross-referenced by this db
 Example :
 Returns : list of strings
 Args    : none

=cut

sub known_databases {
  my ($self)= shift;
  
  if (not defined $self->{_known_databases}) {
      $self->{_known_databases} = $self->_known_databases();
  }
  
  return @{$self->{_known_databases}};
}

sub _known_databases {
  my ($self)= shift;
  
  my $q = 
    "SELECT name FROM external_db";
  $q = $self->prepare($q);
  $q->execute;

  my @res= ();
  while ( my ( @row ) = $q->fetchrow_array ) {
        push @res, $row[0];
  }
  $self->throw("didn't find any database") if (int(@res) == 0);
  return \@res;
}

sub _get_members {
    my ($self, $fam) = @_;

    my $fid = $fam->dbID;
    my $q = 
      "SELECT db.name as dbname, fm.external_member_id as id
         FROM family_members fm, external_db db
        WHERE fm.family_id = $fid and db.external_db_id = fm.external_db_id";

    $q = $self->prepare($q);
    $q->execute;

    my ($rowhash, $n, $mem, $db_name, $db_id);

    while ( $rowhash = $q->fetchrow_hashref) {
	my $link = new Bio::Annotation::DBLink();

	$link->database($rowhash->{dbname});
	$link->primary_id($rowhash->{id});
        $fam->add_member($link);
        $n++;
    }
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
    return $fams[0];  
}                     

=head2 get_max_id

 Title   : get_max_id
 Usage   : $new_id=$fam_adtor->get_max_id
 Function: find the higest ENSF in this database (needed for mapping). 
 Example : see Usage
 Returns : an int
 Args    : none

=cut

sub get_max_id {
    my($self, $db)=@_;

    my $q = "select max(stable_id) from family";
    
    $q = $self->prepare($q);
    $q->execute;

    my ( @row ) = $q->fetchrow_array; 
    return $row[0];
}


# function for finding alignemnts. They are not cached because they are
# too big. 
sub _get_alignment_string {
    my ($self, $fam) = @_; 

    my $fid = $fam->dbID();
    my $q= "SELECT alignment
            FROM alignments 
            WHERE family_id = $fid";

    $q = $self->prepare($q);
    $q->execute();

    my ( $row ) = $q->fetchrow_arrayref;
    if ( !defined($row) || int(@$row) == 0 ) {            # not found
        return undef;
    }  else { return $$row[0];}
}

#method to fetch alignments
sub get_Alignment {
  my ($self,$fam) = @_;

  if (!defined($fam)) {
    $self->throw("No family entered for _get_alignment");
  } elsif (! $fam->isa("Bio::EnsEMBL::ExternalData::Family::Family")) {
    $self->throw("[$fam] is not a Bio::EnsEBML::ExtnernalData::Family::Family");
  }
  
  my $alignstr = $self->_get_alignment_string($fam);
  # Not sure that this is the best way to do this.
  open(ALN,"echo \'$alignstr\' |");
  my $alnfh     = Bio::AlignIO->newFh('-format' => "clustalw",-fh => \*ALN);

  my ($align) = <$alnfh>;

  return $align;
}

#internal method used in multiple calls above to build family objects from table data  
sub _get_families {
    my ($self, $q) = @_;

    $q = $self->prepare($q);
    $q->execute;

    my $rowhash =undef;
    my $fam;
    my @fams;
    while ( $rowhash = $q->fetchrow_hashref) {
        $fam = new Bio::EnsEMBL::ExternalData::Family::Family;
        $fam->{'adaptor'}=$self;
        $fam->dbID($rowhash->{family_id});
        $fam->stable_id($rowhash->{stable_id});
        $fam->description($rowhash->{description});
        $fam->release($rowhash->{release});
        $fam->annotation_confidence_score($rowhash->{annotation_confidence_score});

        $self->_get_members($fam); 
        $self->_get_totals($fam);
        push(@fams, $fam);
    }
    
    @fams;                         
}                                  

#internal method to build hash of total number of members per database name
=head2 _get_totals

 Title   : _get_totals
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _get_totals{
   my ($self,$fam) = @_;

   my $fid = $fam->dbID;
   my $q = "SELECT ed.name, ft.members_total
             FROM family_totals ft, external_db ed
             WHERE ft.family_id = $fid
             AND ft.external_db_id = ed.external_db_id";
   
   $q = $self->prepare($q);
   $q->execute;
   
   my $all=0;
   my %totals; 
   
   while ( my $rowhash = $q->fetchrow_hashref) {
       $totals{$rowhash->{name}}=$rowhash->{members_total};
       $all =+ $rowhash->{members_total};
   }
   $totals{'all'}=$all;
   $fam->_totalhash(\%totals);
}


#get-set for database handle
sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
}

sub DESTROY {
   my ($self) = @_;
   
   if( $self->{'_db_handle'} ) {
       $self->{'_db_handle'}->disconnect;
       $self->{'_db_handle'} = undef;
   }
}
