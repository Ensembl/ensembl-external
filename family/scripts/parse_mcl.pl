#!/usr/local/bin/perl
# $Id$

# Parse MCL output (numbers) back into real clusters (with protein names)

use strict;

my $Usage = "Usage: $0 file.mcl file.index > file.clusters";

die $Usage unless @ARGV == 2;

my $file=$ARGV[0];

open (FILE, $file) || die "$file: $!";
my $i=0;
my @cluster=undef;
my %hash = undef;

while (<FILE>) {
    if ((!/begin/) && (!/\)/) && (!/mcl/) &&  (!/dimensions/) && (!/\(/) )  {
        chomp;
        $cluster[$i]=join(" ",$cluster[$i],"$_");
        
	if (/\$/) {
            $i++;
        }
    }
}
close(FILE) || die "$file: $!";

$file=$ARGV[1];
open (FILE,$file) || die "$file: $!";
while (<FILE>) {
    /^(\S+)\s+(\S+)/;
    $hash{$1}=$2;
}
close(FILE)|| die "$file: $!";

for (my $j=0;$j<$i;$j++)	{
    my @array=split(" ",$cluster[$j]);
    
    for (my $p=1;$p< $#array; $p++) {
        print "$array[0]\t$hash{$array[$p]}\n";
    }
}
