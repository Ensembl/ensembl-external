#!/usr/local/ensembl/bin/perl -w
# $Id$

# Parse MCL output (numbers) back into real clusters (with protein names)

use strict;

my $usage = "
Usage: $0 mcl_file index_file > mcl.clusters
\n";

die $usage unless (scalar @ARGV == 2);

my ($mcl_file,$index_file) = @ARGV;

my @clusters;
my %members_index;
my $headers_off = 0;
my $one_line_members = "";

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

open INDEX, $index_file ||
  die "$index_file: $!";

while (<INDEX>) {
    /^(\S+)\s+(\S+)/;
    $members_index{$1}=$2;
}
close(INDEX)|| die "$index_file: $!";

foreach my $cluster (@clusters) {
  my ($cluster_index, @cluster_members) = split /\s+/,$cluster;
  foreach my $member (@cluster_members) {
    last if ($member =~ /^\$$/);
    print "$cluster_index\t$members_index{$member}\n"
  }
}
