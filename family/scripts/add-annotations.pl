#!/usr/local/bin/perl
# $Id$

### This produces one big file with database name, cluster_id, accession,
### and description. It is the input for the consensifier.pl script.

use strict;
use Getopt::Std;

my $opts = 'h';
use vars qw($opt_h);

my (%annotatehash, %clustered, %seqtype, $lastcluster);

my $Usage=<<END_USAGE;

Usage:
  $0 peptidefile seqtypes clusterfile > outfile
  Options:
   -h       : this message
END_USAGE
  #;
  ;

if (@ARGV!=3 || !getopts($opts) || $opt_h ) {
    die $Usage; 
}


warn "Reading Annotations\n";
# my $outfile="annotate.out";
# open (OUT,">$outfile") or die "$outfile:$!\n";

my $file=$ARGV[0];
open (FILE,$file) || die "pepfile $file: $!";
while (<FILE>) {
    chomp($_);
    if (/^>(\S+)\s+(.*)/) {
          $annotatehash{$1}=$2;
          my $seqid=$1;
          $_=$seqid;
          if (/^ENS/ || /^COB/ || /^PGB/ ) {
              $seqtype{$seqid}="ENSEMBL";
          }
      }
}
close (FILE)|| die "$file:$!";

warn "Reading Sequence Type Information\n";
$file=$ARGV[1];
open (FILE,$file) || die "Sequence information file $file:$!";
while (<FILE>) {
    /^(\S+)\: (\S+)/;
    $seqtype{$2}=$1;
}
close (FILE)|| die "$file:$!";

warn "Reading Clustering Information\n";
$file=$ARGV[2];
open (FILE, $file) ||  die "Clusters file:$!";
while (<FILE>) {
    /^(\S+)\s+(\S+)/;
    
    if ($lastcluster ne $1)       {       } # so?
    # $id=(split('\|',$2))[-1]; # not used

    if ($seqtype{$2} eq '')  {
        print "Error: $2\n";
        $seqtype{$2} = 'SPTREMBL'
    }
    print STDOUT "$seqtype{$2} $1\t$2\t>$annotatehash{$2}\n";
    $clustered{$2}=1;
    $lastcluster=$1;
}
close (FILE)|| die "$file:$!";

foreach my $thing (sort(keys(%annotatehash))) {
    if (!$clustered{$thing})
      {
          $lastcluster++;
          print STDOUT "$seqtype{$thing} $lastcluster $thing >$annotatehash{$thing}\n";
      }
}
# close (OUT)|| die "$outfile:$!";

