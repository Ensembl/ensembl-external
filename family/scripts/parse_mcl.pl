#!/usr/local/ensembl/bin/perl -w
# $Id$

# Parse MCL output (numbers) back into real clusters (with protein names)

use strict;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use Bio::EnsEMBL::ExternalData::Family::Taxon;

my $usage = "
Usage: $0 mcl_file index_file desc_file > mcl.clusters
\n";

die $usage unless (scalar @ARGV == 3);

my ($mcl_file,$index_file,$desc_file) = @ARGV;

my $release_number = "13_1";
my $family_prefix = "ENSF";
my $family_offset = 1;

my @clusters;
my %seqinfo;
my %member_index;
my $headers_off = 0;
my $one_line_members = "";

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => "ecs1b.sanger.ac.uk",
									 -user   => "ensadmin",
									 -dbname => "family_load_test",
									 -pass => "ensembl");

my $FamilyAdaptor = $family_db->get_FamilyAdaptor;
my $TaxonAdaptor = $family_db->get_TaxonAdaptor;

print STDERR "Reading index file...";

open INDEX, $index_file ||
  die "$index_file: $!";

my $max_member_index;

while (<INDEX>) {
    /^(\S+)\s+(\S+)/;
    my ($index,$seqid) = ($1,$2);
    $member_index{$index} = $seqid;
    $seqinfo{$seqid}{'index'} = $index;
    unless (defined $max_member_index) {
      $max_member_index = $index;
    } elsif ($index > $max_member_index) {
      $max_member_index = $index;
    }
}
close INDEX
  || die "$index_file: $!";

print STDERR "Done\n";

print STDERR "Reading description file...";

open DESC, $desc_file ||
  die "$desc_file: $!";

while (<DESC>) {
  if (/^(.*)\t(.*)\t(.*)\t(.*)$/) {
    my ($type,$seqid,$desc,$taxon) = ($1,$2,$3,$4);
    $desc = "" unless (defined $desc);
    $seqinfo{$seqid}{'type'} = $type;
    $seqinfo{$seqid}{'description'} = $desc;
    $seqinfo{$seqid}{'taxon'} = $taxon;
    unless (defined $seqinfo{$seqid}{'index'}) {
      $max_member_index++;
      $seqinfo{$seqid}{'index'} = $max_member_index;
    }
  }
}

close DESC
  || die "$desc_file: $!";

print STDERR "Done\n";

print STDERR "Reading mcl file...";

open MCL, $mcl_file ||
  die "$mcl_file: $!";

while (<MCL>) {
  if (/^begin$/) {
    $headers_off = 1;
    next;
  }
  next unless ($headers_off);
  last if (/^\)$/);
  chomp;
  $one_line_members .= $_;
  if (/\$/) {
    push @clusters, $one_line_members;
    $one_line_members = "";
  }
}

close MCL ||
  die "$mcl_file: $!";

print STDERR "Done\n";

print STDERR "Starting family db loading...";

# starting to use the Family API here to load in a family database
# still print out description for each entries in order to determinate 
# a consensus description

my $max_cluster_index;

foreach my $cluster (@clusters) {
  my ($cluster_index, @cluster_members) = split /\s+/,$cluster;
  print STDERR "Loading cluster $cluster_index...";

  unless (defined $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  } elsif ($cluster_index > $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  }

  my $Family = new  Bio::EnsEMBL::ExternalData::Family::Family;
  my $family_stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
  $Family->stable_id($family_stable_id);
  $Family->release($release_number);
  $Family->description("NULL");
  $Family->annotation_confidence_score(0);

  foreach my $member (@cluster_members) {
    last if ($member =~ /^\$$/);
    my $seqid = $member_index{$member};

    my $taxon_hash = parse_taxon($seqinfo{$seqid}{'taxon'});
    my @classification = split(':',$taxon_hash->{'taxon_classification'});
    my $taxon = new Bio::EnsEMBL::ExternalData::Family::Taxon->new(-classification=>\@classification);
    $taxon->common_name($taxon_hash->{'taxon_common_name'});
    $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
    $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});
    $TaxonAdaptor->store_if_needed($taxon);

    my $FamilyMember = new Bio::EnsEMBL::ExternalData::Family::FamilyMember;
    $FamilyMember->stable_id($seqid);
    $FamilyMember->database(uc $seqinfo{$seqid}{'type'});
    $FamilyMember->taxon_id($taxon->ncbi_taxid);
    $FamilyMember->alignment_string("NULL");
    $Family->add_member($FamilyMember);
  }

  my $dbID = $FamilyAdaptor->store($Family);

  foreach my $FamilyMember (@{$Family->get_all_members}) {
    print $FamilyMember->database,"\t$dbID\t",$FamilyMember->stable_id,"\t",$seqinfo{$FamilyMember->stable_id}{'description'},"\n";
    $seqinfo{$FamilyMember->stable_id}{'printed'} = 1;
  }
  print STDERR "Done\n";
}

# taking care here of the protein that did not give any hit in the blastp run
# and therefore were not included in the mcl matrix. So making sure they are stored in the
# family database as singletons.

foreach my $seqid (keys %seqinfo) {
  next if (defined $seqinfo{$seqid}{'printed'});
  $max_cluster_index++;

  my $Family = new  Bio::EnsEMBL::ExternalData::Family::Family;
  my $family_stable_id = sprintf ("$family_prefix%011.0d",$max_cluster_index + $family_offset);
  $Family->stable_id($family_stable_id);
  $Family->release($release_number);
  $Family->description("NULL");
  $Family->annotation_confidence_score(0);

  my $taxon_hash = parse_taxon($seqinfo{$seqid}{'taxon'});
  my @classification = split(':',$taxon_hash->{'taxon_classification'});
  my $taxon = new Bio::EnsEMBL::ExternalData::Family::Taxon(-classification=>\@classification);
  $taxon->common_name($taxon_hash->{'taxon_common_name'});
  $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
  $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});
  $TaxonAdaptor->store_if_needed($taxon);
  
  my $FamilyMember = new Bio::EnsEMBL::ExternalData::Family::FamilyMember;
  $FamilyMember->stable_id($seqid);
  $FamilyMember->database(uc $seqinfo{$seqid}{'type'});
  $FamilyMember->taxon_id($taxon->ncbi_taxid);
  $FamilyMember->alignment_string("NULL");
  $Family->add_member($FamilyMember);
  
  my $dbID = $FamilyAdaptor->store($Family);

  print $FamilyMember->database,"\t$dbID\t",$FamilyMember->stable_id,"\t",$seqinfo{$FamilyMember->stable_id}{'description'},"\n";
  $seqinfo{$FamilyMember->stable_id}{'printed'} = 1;
}

sub parse_taxon {
  my ($str) = @_;

  $str=~s/=;/=NULL;/g;
  my %taxon = map {split '=',$_} split';',$str;

  return \%taxon;
}
