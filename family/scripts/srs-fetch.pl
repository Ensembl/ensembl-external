#!/usr/local/bin/perl
# $Id$

#
# Pull all vertebrate seqs from an SRS server in swissprot format.
#
# Original by Anton Enright, adapted by Philip Lijnzaad
# 

use strict;

# $|=1;  #line-buffering (e.g. during debugging)

my $types_file='seq_types';
my $pept_file= 'vertebrate.pep';

# my $user = 'lijnzaad@';
my $user = ''; # assume an ssh-agent is running, and .ssh/config is done
               # properly ; this way, everything should be smooth.
my $srs_host = 'ice.ebi.ac.uk';
my $ssh_dest = "$user$srs_host";
my $getz = '/ebi/services/pkgs/srs/bin/osf_5/getz';
my $organism = 'vertebrata*';

### (alternatively, use srs on plato.sanger.ac.uk)


open (FILEOUT,"> $pept_file") ||  die "$pept_file: $!";
open (SEQTYPES,"> $types_file") || die "$types_file: $!";

warn "fetching sequences: ... \n";
my $count=0;

$count += &get_stuff('SWISSPROT', \*FILEOUT, \*SEQTYPES);
$count += &get_stuff('SPTREMBL', \*FILEOUT, \*SEQTYPES);

close FILEOUT || die "$!";
close SEQTYPES || die "$!";
warn "done\n";
warn "Dumped $count sequences into file $pept_file\n";
exit 0;

sub get_stuff {
    # pull stuff from an srs server; return number of things read.
    my ($database, $FILEOUT, $SEQTYPES) = @_;
    my ($accession, $description, $temp, $count);
    $count=0;
    my $cmd = "ssh $ssh_dest \'$getz -f des -f seq -f acc -sf fasta \"[libs={$database}-Organism: $organism] & [libs-SeqLength# 80:]\"\' |";

    warn "Connecting to srs\@$srs_host ... \n";
    open (PROC,$cmd) || die "$cmd:$!";
    warn "fetching sequences from $database-$organism ...\n";
    while (<PROC>) {
	chop($_);
	if (/^AC\s+(\S+);/)
          {
              $accession=$1;
              $description="";
          }
        
	elsif (/^DE\s+(.*)/)
          {
              $temp=$1;
              $description=join(" ",$description,$temp);
          }
        
	elsif (/^>/)
          {
              chop($description);
              print $FILEOUT ">$accession $description\n";
              $count++;
              print $SEQTYPES "$database: $accession\n";
          }
	else
          {
              print $FILEOUT "$_\n";
          }
    }
    warn "done\n";
    close PROC || die "$cmd: $!";
    return $count;
}                                       # get_stuff
