#!/usr/local/bin/perl
use POSIX;
use strict;
# throws away unnecessary  cruft from raw blast output

my $total=0;
# open (FILE,$ARGV[0]);
LINE:
while(<>) {
    my ($protein1, $protein2, $first, $second, $last1, $last2);
    if ( /^PARSED>\s*(\d+)/ ) {
        $total += $1;
        next LINE;
    }
    if (/^(\S+)\s+(\S+)/) {
        $protein1=$1;
        $protein2=$2;
    }
    if (/([\S+]?)e-(\d+)/) {
        chop($_);
        $first=$1;
        $second=$2;
        # $text=join("e-","$first","$second");
        # @rest=split(/$text/,$_);
        
        if ($first eq '') {
            $first=1;	
        }

        if (($last1 ne $protein1) || ($last2 ne $protein2)) {
            print "$protein1\t$protein2\t$first\t$second\n";
        }

        $last1=$protein1;
        $last2=$protein2;
    } else {
        chop($_);
        /^(\S+)\s+(\S+)/;
        print "$1\t$2\t1\t200\n";
    }
}

warn "Found  total of $total parsed peptides\n";
