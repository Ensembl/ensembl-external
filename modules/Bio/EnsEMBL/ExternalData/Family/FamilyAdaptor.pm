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

$fam = $fam_adtor->get_Family_by_id('ENSF000013034');  # family id
$fam = $fam_adtor->get_Family_of_Ensembl_pep_id('ENSP00000012304');
$fam = $fam_adtor->get_Family_of_Ensembl_gene_id('ENSG00000012304');
$fam = $fam_adtor->get_Family_of_db_id('SPTR', 'P000123');
@fam = $fam_adtor->get_Family_described_as('interleukin');
@fam = $fam_adtor->all_Families();

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
clustering SWISSPROT/TREMBL using Anton Enright's algorithm. The clustering
neatly follows the SWISSPROT DE-lines, which are taken as the description
of the whole family.

The objects can only be read from the database, not written. (They are
loaded ussing a separate perl script).

For more info, see Family.pm

=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk>, Anton Enright <enright@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# '; pacify emacs

package Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
use DBI;

use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Family::Family;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

# set stuff in self from @args

 return $make; # success - we hope!
}

=head2 get_Family_by_id

 Title   : get_Family_by_id
 Usage   : $db->get_Family_by_id('ENSF00000000009');
 Function: find Family, given its id.
 Example :
 Returns : a Family object if found, undef otherwise
 Args    : an ENS Family ID

=cut

sub get_Family_by_id  {
    my ($self, $id) = @_; 

    my $q = 
      "SELECT internal_id, id, description, release, annotation_confidence_score
       FROM family
       WHERE id = '$id'";

    $self->_get_family($q);
}                                       # get_Family_by_id

=head2 get_Family_of_Ensembl_pep_id

 Title   : get_Family_of_Ensembl_pep_id
 Usage   : $fam = $db->get_Family_of_Ensembl_pep_id('ENSP00000204233');
 Function: find the family to which the given Ensembl peptide id belongs.
 Example :
 Returns : a Family or undef if not found 
 Args    : the ENSEMBLPEP identifier (display_id)

=cut

sub get_Family_of_Ensembl_pep_id {
    my ($self, $eid) = @_; 

    $self->get_Family_of_db_id('ENSEMBLPEP', $eid);  #PL: what db_name ???
}

=head2 get_Family_of_Ensembl_gene_id

 Title   : get_Family_of_Ensembl_gene_id
 Usage   : $fam = $db->get_Family_of_Ensembl_gene_id('ENSP00000204233');
 Function: find the family to which the given Ensembl peptide id belongs.
 Example :
 Returns : a Family or undef if not found 
 Args    : the ENSEMBL gene identifier (display_id)

=cut

sub get_Family_of_Ensembl_gene_id {
    my ($self, $eid) = @_; 

    $self->get_Family_of_db_id('ENSEMBLGENE', $eid);  #PL: what db_name ???
}

=head2 get_Family_of_db_id

 Title   : get_Family_of_db_id
 Usage   : $fam = $db->get_Family_of_db_id('SPTR', 'P01235');
 Function: find the family to which the given database and id belong
 Example :
 Returns : a Family or undef if not found 
 Args    : the ENSEMBLPEP identifier (display_id)

=cut

sub get_Family_of_db_id { 
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

=head2 get_Families_described_as

 Title   : get_Families_described_as
 Usage   : my @fams = $db->get_Families_described_as('REDUCTASE');
 Function: simplistic substring searching on the description
 Example :
 Returns : a possibly empty list of Families that contain the string. 
           (The search is currently case-insensitive; this may change if
           SPTR changes to case-preservation)
 Args    : search string.

=cut

sub get_Families_described_as{ 
    my ($self, $desc) = @_; 

    my $q = 
      "SELECT f.internal_id, f.id, f.description, 
              f.release, f.annotation_confidence_score
       FROM family f
       WHERE f.description LIKE '%". "\U$desc" . "%'";

    $self->_get_families($q);
}

=head2 all_Families

 Title   : all_Families
 Usage   : 
 Function: return all known families (use with care)
 Example :
 Returns : 
 Args    : 

=cut


sub all_Families { 
    my ($self) = @_; 
    
    my $q = 
      "SELECT f.internal_id, f.id, f.description, 
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
    "SELECT distinct db_name 
     FROM family_members";
  $q = $self->prepare($q);
  $q->execute;

  my @res= ();
  while ( my ( @row ) = $q->fetchrow_array ) {
        push @res, $row[0];
  }
  # $q->finish;
  $self->throw("didn't find any database") if (int(@res) == 0);
  return \@res;
}

# pull all fam's members from db
sub _get_members {
    my ($self, $fam) = @_;

    my $iid = $fam->internal_id;
    my $q = 
      "SELECT db_name, db_id
       FROM family_members
       WHERE family = $iid";

    $q = $self->prepare($q);
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

# function for finding alignemnts. They are not cached because they are
# too big. 
sub _get_alignment_string {
    my ($self, $fam) = @_; 

    my $internal_id = $fam->internal_id();
    my $q= "SELECT alignment
            FROM alignments 
            WHERE family = $internal_id";

    $q = $self->prepare($q);
    $q->execute();

    my ( $row ) = $q->fetchrow_arrayref;
    if ( !defined($row) || int(@$row) == 0 ) {            # not found
        return undef;
    }  else { return $$row[0];}
}

sub get_Alignment {
  my ($self,$fam) = @_;

  if (!defined($fam)) {
    $self->throw("No family entered for _get_alignment");
  } elsif (! $fam->isa("Bio::EnsEMBL::ExternalData::Family::Family")) {
    $self->throw("[$fam] is not a Bio::EnsEBML::ExtnernalData::Family::Family");
  }
  
  my $alignstr = $self->_get_alignment_string($fam);
  print STDERR "Getting alignment $fam\n";
  print STDERR "ALignmnet $alignstr\n";
  # Not sure that this is the best way to do this.
  open(ALN,"echo \'$alignstr\' |");
  my $alnfh     = Bio::AlignIO->newFh(-format => "clustalw",-fh => \*ALN);

  my ($align) = <$alnfh>;

  return $align;
}
  
# get 0 or more families
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
        $fam->internal_id($rowhash->{internal_id});
        $fam->id($rowhash->{id});
        $fam->description($rowhash->{description});
        $fam->release($rowhash->{release});
        $fam->annotation_confidence_score(
                                 $rowhash->{annotation_confidence_score});
        $self->_get_members($fam);
        push(@fams, $fam);
    }
    
    @fams;                              # maybe empty
}                                       # _get_families

sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
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
