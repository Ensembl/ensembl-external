#!/usr/local/ensembl/bin/perl -w
# $Id$

### This produces one big file with database name, cluster_id, accession,
### and description. It is the input for the consensifier.pl script.

use strict;
use Getopt::Long;

my $help = 0;

my $usage=<<END_USAGE;

Usage:
  $0 description_file cluster_file > outfile
  Options:
   -h       : this message

END_USAGE

unless (GetOptions('help' => \$help)) {
  die $usage;
}

unless (scalar @ARGV == 2 || ! $help ) {
  die $usage; 
}

my ($desc_file, $cluster_file) = @ARGV;

print STDERR  "Reading Annotations and Sequence Type Information...";

my (%annotatehash, %clustered, %seqtype, $lastcluster);
my $file=$ARGV[0];

open (DESC,$desc_file) || die "can not open $desc_file, $!\n";

while (<DESC>) {
  if (/^(.*)\t(.*)\t(.*)\t.*$/) {
    my ($type,$seqid,$desc) = ($1,$2,$3);
    $seqtype{$seqid} = $type; 
    $annotatehash{$seqid} = uc $desc;
  }
}

close DESC;

print STDERR "Done\n";

print STDERR "Reading Clustering Information...";

open (CLUSTER, $cluster_file) ||  die "can not open $cluster_file, $!\n";

my $last_cluster_id;

while (<CLUSTER>) {
  if (/^(\S+)\s+(\S+)$/) {
    my ($cluster_id,$seqid) = ($1,$2);

    unless (defined $seqtype{$seqid})  {
      die "$seqid not identified previously in $desc_file\n" 
    }
    print "$seqtype{$seqid} $cluster_id\t$seqid\t>$annotatehash{$seqid}\n";
    $clustered{$seqid} = 1;
    $last_cluster_id = $cluster_id;
  }
}

close CLUSTER;

#to get sequence not included in the clustering because no blastp hits to anything

foreach my $seqid (sort keys %annotatehash) {
  unless ($clustered{$seqid}) {
    $last_cluster_id++;
    print "$seqtype{$seqid} $last_cluster_id $seqid >$annotatehash{$seqid}\n";
  }
}

print STDERR "Done\n";

exit 0;
