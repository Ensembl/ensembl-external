#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

my ($family_stable_id,$family_id,$fasta_file,$fasta_index,$dir);

my $store = 0;

my $clustalw_executable = "/usr/local/ensembl/bin/clustalw1.82";

GetOptions('family_stable_id=s' => \$family_stable_id,
	   'family_id=s' => \$family_id,
	   'fasta_file=s' => \$fasta_file,
	   'fasta_index=s' => \$fasta_index,
	   'dir=s' => \$dir,
	   'store' => \$store);

my $rand = time().rand(1000);



my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => 'ecs1b.internal.sanger.ac.uk',
									 -user   => 'ensadmin',
									 -pass   => 'ensembl',
									 -dbname => 'ensembl_family_test');

my $FamilyAdaptor = $family_db->get_FamilyAdaptor;
my $FamilyMemberAdaptor = $family_db->get_FamilyMemberAdaptor;

my $family;
my $id;

if (defined $family_stable_id) {
  $id = $family_stable_id;
  $family = $FamilyAdaptor->fetch_by_stable_id($family_stable_id);
} elsif (defined $family_id) {
  $id = $family_id;
  $family = $FamilyAdaptor->fetch_by_dbID($family_id);
}

my @members;

push @members,@{$family->get_members_by_dbname('ENSEMBLPEP')};
push @members,@{$family->get_members_by_dbname('SWISSPROT')};
push @members,@{$family->get_members_by_dbname('SPTREMBL')};
print STDERR scalar @members ,"\n";

exit 0 if (scalar @members == 1);

my $sb_id = "/tmp/sb_id.$rand";

open S,">$sb_id";

foreach my $member (@members) {
  my $member_stable_id = $member->stable_id;
  print STDERR $member_stable_id,"\n";
  print S $member_stable_id,"\n";
}

close S;

my $sb_file = "/tmp/sb.$rand";

unless (system("/nfs/acari/abel/bin/fastafetch $fasta_file $fasta_index $sb_id > $sb_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in fastafetch $sb_id, $!\n";
}

my $clustal_file = "/tmp/clustalw.$rand";

my $status = system("$clustalw_executable -INFILE=$sb_file -OUTFILE=$clustal_file");

unless ($status == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in clustalw, $!\n";
}

if ($store) {
  $family->read_clustalw($clustal_file);
  foreach my $member (@{$family->get_all_members}) {
    $FamilyMemberAdaptor->update($member);
  }
} else {
  unless (system("cp $clustal_file $dir/$id.out") == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in cp $id.out,$1\n";
  }
}

unlink glob("/tmp/*$rand*");

exit 0;
