# $Id$
#
# BioPerl module for Family
#
# Cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
#
# Copyright Philip Lijnzaad
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Family - DESCRIPTION of Object

=head1 SYNOPSIS

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;

$famdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                             -user   => 'ensro',
                                             -dbname => 'family102',
                                             -host   => 'ecs1b',
                                             -driver => 'mysql',
                                            );

my $fam_adtor = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($famdb);

my $fam = $fam_adtor->get_family_by_Ensembl_id('ENSP00000012304');

print $fam->description, join('; ',$fam->keywords), $fam->release, 
      $fam->score, $fam->size;


=head1 DESCRIPTION

This object describes protein families obtained from clustering
SWISSPROT/TREMBL using Anton Enright's Tribe algorithm. The clustering
neatly follows the SWISSPROT/TREMBL DE-lines, which are taken as the
description of the whole family.

The object is a bit bare, still; dbxrefs (i.e., family to family) are not
implemented, and SWSISSPROT keywords aren't there yet either. 

The family members are currently represented by DBLink's; more convenient
navigation may be added at a later stage.


=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk>, Anton Enright <enright@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::Family;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object
use Bio::Root::Root;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;


@ISA = qw(Bio::Root::Root Bio::DBLinkContainerI);
# new() is inherited from Bio::Root::Object

=head2 new

 Title   : new
 Usage   : not intended for general use.
 Function:
 Example :
 Returns : a family (but without members; caller has to fill using
           add_member or add_DBLink)
 Args    :
         
=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  my $n = scalar(@args);
  if ($n) {
      #do this explicitly.
      my ($dbid, $stable_id,$descr,$release, $score, $memb,$totalhash,$adap); 
      $self->_rearrange([qw(
			    DBID
			    STABLE_ID
			    DESCRIPTION
			    RELEASE
			    SCORE
			    MEMBERS
			    TOTALHASH
			    ADAPTOR
			    )], @args);
      
      $dbid && $self->dbID($dbid);
      $stable_id || $self->throw("Must have a stable_id");
      $self->stable_id($stable_id);

      $descr || $self->throw("family must have a description");
      $self->description($descr);

      $release && $self->release($release);
      $score && $self->annotation_confidence_score($score);
      $totalhash && $self->_totalhash($totalhash);
      $self->{_members} = []; 
      my @members = @$memb;
      push (@{$self->{_members}},@members);
      $adap && $self->adaptor($adap);
  }
  
  return $self;
}   

=head2 adaptor

 Title   : adaptor
 Usage   : $adaptor = $fam->adaptor
 Function: find this objects\'s adaptor object (set by FamilyAdaptor)
 Example :
 Returns : 
 Args    : 
=cut

sub adaptor {
  my ($self)= shift;
  return $self->{'adaptor'};
}


=head2 stable_id

 Title   : stable_id
 Usage   : 
 Function: get/set the display stable_id of the Family
 Example :
 Returns : 
 Args    : 
=cut

sub stable_id {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'stable_id'} = $value;
    }
    return $self->{'stable_id'};
}

=head2 dbID

 Title   : dbID
 Usage   : 
 Function: get/set the dbID of the Family
 Example :
 Returns : 
 Args    : 
=cut

sub dbID {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'dbID'} = $value;
    }
    return $self->{'dbID'};
}

=head2 description

 Title   : description
 Usage   : 
 Function: get/set the description of the Family. 
 Example :
 Returns : A string (currently all upper case, and no longer than 255 chars).
 Args    : 
=cut

sub description {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'desc'} = $value;
    }
    return $self->{'desc'};
}

=head2 release

 Title   : release
 Usage   : 
 Function: get/set the release number of the family database;
 Example :
 Returns : 
 Args    : 
=cut

sub release {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'release'} = $value;
    }
    return $self->{'release'};
}

=head2 annotation_confidence_score

 Title   : annotation_confidence_score
 Usage   : 

 Function: get/set the annotation_confidence_score of the Family. This a
           measure of how good the cluster is (what is the scale??)
 Example :
 Returns : 
 Args    : 
=cut

sub annotation_confidence_score {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'annotation_confidence_score'} = $value;
    }
    return $self->{'annotation_confidence_score'};
}

=head2 _totalhash

 Title   : _totalhash
 Usage   : internal method for family_totalhash hash
 Function: Getset for family_totalhash hash
 Returns : internal hash of total number of members per database id
 Args    : newvalue (optional)


=cut

sub _totalhash{
   my $self= shift;

   if( @_ ) {
       my $value = shift;
       $self->{'_totalhash'} = $value;
   }
   return $self->{'_totalhash'};
}



=head2 size

 Title   : size
 Usage   : $fam->size
 Function: returns the number of members of the family
 Returns : an int
 Args : optionally, a databasename; if given, only members belonging to
        that database are counted, otherwise, all are given.
=cut

sub size {
    my ($self, $dbname) = @_; 
    
    my %tot = %{$self->_totalhash()};
    if  ( defined $dbname) { 
	return $tot{$dbname};
    }
    else {
	return $tot{'all'};
    }
}

=head2 each_member_of_db

 Title   : each_member_of_db
 Usage   : $obj->each_member_of_db('SPTR')
 Function: returns all the members that belong to a particular database
 Returns : a list of DBLinks (which may be empty)
 Args    : the database name

=cut

sub each_member_of_db {
    my ($self, $db) = @_;
    
    # might be slowish; do we need to change this, e.g., go to database? 
    
    # see if we have it cached -- big win when doing family id mapping
    if ( defined($self->{mems_per_db}->{$db}) ) {
	return @{$self->{mems_per_db}->{$db}};
    }
    my @mems;
    if ($self->adaptor) {
	@mems = $self->adaptor->fetch_members_of_db($db);
	$self->{mems_per_db}->{$db}= \@mems;
    }
    else {
	@mems = $self->_each_member_of_db($db);
	$self->{mems_per_db}->{$db}= \@mems;
    }
    return @mems;
}

sub _each_member_of_db {
  my ($self, $db) = @_;

  my @mems = ();
  foreach my $mem ($self->each_DBLink()) {  
    if ($mem->database eq $db) { 
         push @mems, $mem;
     };
  }
  return @mems;
}

### inherited from Bio::DBLinkContainerI
=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBLink() )
 Function: find all the members of the family
 Example :
 Returns : an array of Bio::Annotation::DBLink objects
 Args    : none
=cut

sub each_DBLink{
    my ($self) = @_;
    
    if ( defined $self->{'_members'} ) { return @{$self->{'_members'}}; }
    return ();
}

=head2 add_member

 Title   : add_member
 Usage   : (not for general usage)
 Function: adds member to family. Like add_DBLlink, but takes a string
           pair, rather than a DBLink.
 Example : $fam->add_member('SPTR', 'P12345');
 Returns : undef
 Args    : db: the database name and primary_id: the primary_id of the database

=cut

sub add_member { 
    my ($self, $link) = @_; 
    
    push (@{$self->{_members}}, $link);
}

=head2 get_alignment_string

 Title   : get_alignment_string
 Usage   : $obj->get_alignment_string
 Function: returns a complete clustal alignment as a string
 Example : 
 Returns : complete clustal alignment as a string, or undef if not found
 Args    : none

=cut

sub get_alignment_string {
    my ($self) = @_;
    $self->adaptor->_get_alignment_string($self);
}

=head2 get_alignment

 Title   : get_alignment
 Usage   : $obj->get_alignment
 Function: returns a complete clustal alignment as a Bio::SimpleAlign
 Example : 
 Returns : complete clustal alignment or undef if not found
 Args    : none

=cut

sub get_alignment {
    my ($self) = @_;
    $self->adaptor->_get_alignment($self);
}

1;
