#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

my ($family_stable_id,$family_id,$fasta_file,$fasta_index,$dir);

my $store = 0;

GetOptions('fasta_file=s' => \$fasta_file);

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => 'ecs1b.internal.sanger.ac.uk',
									 -user   => 'ensadmin',
									 -pass   => 'ensembl',
									 -dbname => 'ensembl_family_test');

my $FamilyMemberAdaptor = $family_db->get_FamilyMemberAdaptor;

my $FH = IO::File->new();
$FH->open($fasta_file) || die "Could not open alignment file [$fasta_file], $!\n;";

my $member_stable_id;
my $member_seq;

while (<$FH>) {
  if (/^>(\S+)\s*.*$/) {
    if (defined $member_stable_id && defined $member_seq) {
      print "MEMBER: $member_stable_id\n";
      print "SEQ: $member_seq\n";
      my $member = $FamilyMemberAdaptor->fetch_by_stable_id($member_stable_id)->[0];
      $member->alignment_string($member_seq);
      $FamilyMemberAdaptor->update($member);
      undef $member_stable_id;
      undef $member_seq;
    }
    $member_stable_id = $1;
  } elsif (/^[a-zA-Z]+$/) {
    chomp;
    $member_seq .= $_;
  }
}

if (defined $member_stable_id && defined $member_seq) {
  my $member = $FamilyMemberAdaptor->fetch_by_stable_id($member_stable_id)->[0];
  $member->alignment_string($member_seq);
  undef $member_stable_id;
  undef $member_seq;
}

$FH->close;
