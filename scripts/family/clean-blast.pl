#!/usr/local/bin/perl
# $Id$

# Usage: clean-blast.pl < file(s) > otherfile

use POSIX;
use strict;
# throws away unnecessary  cruft from raw blast output

my $total=0;

my ($last1, $last2);
LINE:
while(<>) {
    if ( /^PARSED>\s*(\d+)/ ) {
        $total += $1;
        next LINE;
    }
    my ($protein1, $protein2, $a, $b, $score) = split(' ');
    my ($factor, $magnitude);

    if ($score =~ /([0-9.]?)e-(\d+)/) {
        $factor= ($1 || 1);
        $magnitude=$2;
    } elsif ($score eq '0.0') { 
        $factor = 1;
        $magnitude=200;
    } elsif ($score =~  '^0\.') { 
        $score = sprintf "%e", $score;
        if ( $score !~ /([0-9.]?)e-(\d+)/) { die "$score doesn't match:bug";}
        $factor= ($1 || 1);
        $magnitude=$2;
    } else {
        die "not a valid score: '$score'";
    }
    #only 
    if (($last1 ne $protein1) || ($last2 ne $protein2)) {
        print "$protein1\t$protein2\t$factor\t$magnitude\n";
    }
    $last1=$protein1;
    $last2=$protein2;
}

warn "Found  total of $total parsed peptides\n";
