#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my ($idqy,$fastadb,$fastaindex,$dir);

my $blast_executable = "/usr/local/ensembl/bin/blastall-2.2.1";
my $fastafetch_executable = "/nfs/acari/abel/bin/fastafetch";
my $tribe_parse_executable = "/nfs/acari/abel/bin/tribe-parse";

GetOptions('idqy=s' => \$idqy,
	   'fastadb=s' => \$fastadb,
	   'fastaindex=s' => \$fastaindex,
	   'dir=s' => \$dir);

unless (-e $idqy) {
  die "$idqy does not exist\n";
}

my $rand = time().rand(1000);

my $qy_file = "/tmp/qy.$rand";
my $blast_file = "/tmp/blast.$rand";
my $blast_tribe_file = "/tmp/blast_tribe.$rand";

unless(system("$fastafetch_executable $fastadb $fastaindex $idqy > $qy_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $fastafetch_executable, $!\n";
} 

my $status = system("$blast_executable -d $fastadb -i $qy_file -p blastp -e 0.00001 > $blast_file");
#unless ($status == 0 || $status == 4096 || $status == 5888) {
unless ($status == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $blast_executable, $!\n";
}
unless (system("$tribe_parse_executable $blast_file > $blast_tribe_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $tribe_parse_executable, $!\n";
}

my $final_file = $dir."/".basename($idqy).".blast_tribe";
unless (system("cp $blast_tribe_file $final_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in cp $blast_tribe_file, $!\n";
}

unlink glob("/tmp/*$rand*");

exit 0;
