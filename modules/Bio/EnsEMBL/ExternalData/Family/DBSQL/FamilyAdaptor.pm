# $Id$
# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor
# 
# Initially cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
# Now cared by Elia Stupka <elia@fugu-sg.org> and Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a family coming from a database of protein families.

=head1 SYNOPSIS

  use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

  my $famdb = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-user   => 'ensro',
								       -dbname => 'familydb',
								       -host   => 'ecs1b');

  my $fam_adtor = $famdb->get_FamilyAdaptor;

  my $fam = $fam_adtor->fetch_by_stable_id('ENSF000013034');
  $fam = $fam_adtor->fetch_by_dbname_id('SPTR', 'P000123');
  my @fam = $fam_adtor->fetch_by_description_with_wildcards('interleukin',1);
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

The objects can be read from and write to a family database.

For more info, see ensembl-doc/family.txt

=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk> [original perl modules]
 Anton Enright <enright@ebi.ac.uk> [TRIBE algorithm]
 Elia Stupka <elia@fugu-sg.org> [refactoring]
 Able Ureta-Vidal <abel@ebi.ac.uk> [multispecies migration]

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor;

use vars qw(@ISA);
use strict;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::ExternalData::Family::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   : $family_adaptor->fetch_by_dbID($id);
 Function: fetches a Family given its internal database identifier
 Example : $family_adaptor->fetch_by_dbID(1)
 Returns : a Bio::EnsEMBL::ExternalData::Family::Family object
 Args    : an integer


=cut

sub fetch_by_dbID {
  my ($self,$fid) = @_;
  
  $self->throw("Should give a defined family_id as argument\n") unless (defined $fid);

  my $q = "SELECT family_id,stable_id,description,release,annotation_confidence_score
           FROM family
           WHERE family_id = $fid";
  
  return $self->_get_family($q);

}

=head2 fetch_by_stable_id

 Title   : fetch_by_stable_id
 Usage   : $family_adaptor->fetch_by_stable_id($id);
 Function: fetches a Family given its stable identifier
 Example : $db->fetch_by_stable_id('ENSF00000000009');
 Returns : a Family object if found, undef otherwise
 Args    : an EnsEMBL Family stable id

=cut

sub fetch_by_stable_id  {
    my ($self, $stable_id) = @_; 

    $self->throw("Should give a defined family_stable_id as argument\n") unless (defined $stable_id);

    my $q = "SELECT family_id FROM family WHERE stable_id = '$stable_id'";
    $q = $self->prepare($q);
    $q->execute;
    my ($id) = $q->fetchrow_array;
    $id || $self->throw("Could not find family for stable id $stable_id");
    return $self->fetch_by_dbID($id);
}           

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

    $self->throw("Should give defined databasename and member_stable_id as arguments\n") unless (defined $dbname && defined $extm_id);

    my $q = "SELECT f.family_id, f.stable_id, f.description, 
                    f.release, f.annotation_confidence_score
             FROM family f, family_members fm, external_db edb
             WHERE f.family_id = fm.family_id
             AND fm.external_db_id = edb.external_db_id
             AND edb.name = '$dbname' 
             AND fm.external_member_id = '$extm_id'"; 

    return $self->_get_family($q);
}

=head2 fetch_by_dbname_taxon_member

 Title   : fetch_of_dbname_taxon_member
 Usage   : $fam = $db->fetch_of_dbname_taxon_member($dbname,$taxon_id,$member_stable_id);
 Function: find the family to which the given database and id belong
 Example : $fam = $db->fetch_of_dbname_taxon_member('ENSEMBLGENE', '9606', 'ENSG000001101002');
 Returns : a Family or undef if not found 
 Args    : a database name and a member identifier (display_id)

=cut

sub fetch_by_dbname_taxon_member { 
    my ($self, $dbname, $taxon_id, $extm_id) = @_; 

    $self->throw("Should give defined databasename and taxon_id and member_stable_id as arguments\n") unless (defined $dbname && defined $taxon_id && defined $extm_id);

    my $q = "SELECT f.family_id, f.stable_id, f.description, 
                    f.release, f.annotation_confidence_score
             FROM family f, family_members fm, external_db edb
             WHERE f.family_id = fm.family_id
             AND fm.external_db_id = edb.external_db_id
             AND edb.name = '$dbname' 
             AND fm.external_member_id = '$extm_id'
             AND fm.taxon_id = $taxon_id"; 

    return $self->_get_family($q);
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
    return $self->_get_families($q);
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
  my ($self) = @_;
  
  if (not defined $self->{_known_databases}) {
      $self->{_known_databases} = $self->_known_databases();
  }
  
  return @{$self->{_known_databases}};
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
    my($self, $db) = @_;

    my $q = "select max(stable_id) from family";
    
    $q = $self->prepare($q);
    $q->execute;

    my ( @row ) = $q->fetchrow_array; 
    return $row[0];
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

##################
# internal methods

#internal method used in multiple calls above to build family objects from table data  

sub _get_families {
    my ($self, $q) = @_;

    $q = $self->prepare($q);
    $q->execute;

    my @fams;

    while (defined (my $rowhash = $q->fetchrow_hashref)) {
        my $fam = new Bio::EnsEMBL::ExternalData::Family::Family;

        $fam->adaptor($self);
        $fam->dbID($rowhash->{family_id});
        $fam->stable_id($rowhash->{stable_id});
        $fam->description($rowhash->{description});
        $fam->release($rowhash->{release});
        $fam->annotation_confidence_score($rowhash->{annotation_confidence_score});

        push(@fams, $fam);
    }
    
    return @fams;                         
}  

# get one or no family, given some query
sub _get_family {
    my ($self, $q) = @_;
    
    my @fams = $self->_get_families($q);
    
    if (scalar @fams > 1) {
      $self->throw("Internal database error, expecting at most one Family.
Check data coherence, e.g. have two families with different family_id have the same stable id.\n");
# as family_id and stable_id are unique keys _get_families should sufficient;
    };

    return $fams[0];  
}              

#internal method to build hash of total number of members per database name
 
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

sub _known_databases {
  my ($self) = @_;
  
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

sub _get_each_member {
  my ($self,$family) = @_;

  $self->throw("Should give a defined family a object as argument\n") unless (defined $family);

  my $family_id = $family->dbID;
  my $FamilyMemberAdaptor = $self->db->get_FamilyMemberAdaptor();
  my @members = $FamilyMemberAdaptor->fetch_by_family_id($family_id);
  foreach my $member (@members) {
    $family->add_member($member);
  }
}

###############
# store methods

=head2 store

 Title   : store
 Usage   : $famad->store($fam)
 Function: Stores a family object into the database
 Example : $famad->store($fam)
 Returns : $fam->dbID
 Args    : Bio::EnsEMBL::ExternalData::Family::Family object

=cut

sub store {
  my ($self,$fam) = @_;

  $fam->isa('Bio::EnsEMBL::ExternalData::Family::Family') ||
    $self->throw("You have to store a Bio::EnsEMBL::ExternalData::Family::Family object, not a $fam");

  my $q = "SELECT family_id from family where stable_id = ?";
  $q = $self->prepare($q);
  $q->execute($fam->stable_id);
  my $rowhash = $q->fetchrow_hashref;
  if ($rowhash->{family_id}) {
    return $rowhash->{family_id};
  }

  $q = "INSERT INTO family (stable_id, description, release, annotation_confidence_score) VALUES (?,?,?,?)";
  $q = $self->prepare($q);
  $q->execute($fam->stable_id,$fam->description,$fam->release,$fam->annotation_confidence_score);
  $fam->dbID($q->{'mysql_insertid'});

  my $member_adaptor = $self->db->get_FamilyMemberAdaptor;
  foreach my $member ($fam->each_member) {
    $self->_store_db_if_needed($member->database);
    $member_adaptor->store($fam->dbID,$member);
  }

  return $fam->dbID;
}

sub _store_db_if_needed {
  my ($self,$dbname) = @_;
  
  my $q = "select external_db_id from external_db where name = ?";
  $q = $self->prepare($q);
  $q->execute($dbname);
  my $rowhash = $q->fetchrow_hashref;
  if ($rowhash->{external_db_id}) {
    return $rowhash->{external_db_id};
  } else {
    $q = "INSERT INTO external_db (name) VALUES (?)";
    $q = $self->prepare($q);
    $q->execute($dbname);
    return $q->{'mysql_insertid'};
  }
}
