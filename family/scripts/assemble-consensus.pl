#!/usr/local/bin/perl 

# Script to assembl the consensus annotations from different files into
# final ones.

$|=1;
use POSIX;

use strict;
use Getopt::Std;

my $opts = 'h';
use vars qw($opt_h);

my $discarded_file="annotations.discarded";

my $Usage=<<END_USAGE;

Usage:
  $0  [options ] file.annotated file.SWISSPROT-consensus file.SPTREMBL-consensus > families
  Discarded annotations are written to $discarded_file.
  Options:
   -h          : this message
END_USAGE
  #;
  ;

if (@ARGV!=3 
    || !getopts($opts) 
    || $opt_h ) { 
    die $Usage; 
}

open (FILEOUT,">$discarded_file") || die "$discarded_file: $!";

my %clusters;
my $file=$ARGV[0];
open (FILE,$file) || die "$file$!";
while (<FILE>) {
    chomp($_);
    my @temp=split(" ",$_);
    my $cluster=$temp[1];
    my $name=$temp[2];
    push(@{$clusters{$cluster}},$name);
}
close FILE;

my (%swisshash, %swissscore, %tremblhash, %tremblscore);

$file = $ARGV[1];
# make sure we're first reading the SWISSPROT one first ...
die "$file: expecting 'sw' as part of filename: first one should be swissprot" 
  unless $file =~ /sw/i;
open (FILE,$file) || die "$file:$!";
while (<FILE>)	{
    /^(\d+)\s+>>>(.*)<<<\s+(\d+)/;
    $swisshash{$1}=$2;
    $swissscore{$1}=$3;
}
close FILE;

$file=$ARGV[2];
# ... and sptrembl second:
die "$file: expecting 'tr' as part of filename: first one should be trembl" 
  unless $file =~ /tr/i;
open (FILE,$file) || die "$file:$!";
while (<FILE>) {
    /^(\d+)\s+>>>(.*)<<<\s+(\d+)/;
    $tremblhash{$1}=$2;
    $tremblscore{$1}=$3;
}

my $final_total=0;
my $total_discarded=0;
foreach my $cluster_id (sort numeric (keys(%clusters))) {
    my $members="";

    my $annotation="UNKNOWN";
    my $score=0;

    if ($swisshash{$cluster_id}) {
        $annotation=$swisshash{$cluster_id};
        $score=$swissscore{$cluster_id};
        if ($score==0) {
            $score=1;
        }
    } elsif ($tremblhash{$cluster_id}) {
        $annotation=$tremblhash{$cluster_id};
        $score=$tremblscore{$cluster_id};
        if ($score==0) {
            $score=1;
        }
    }

    # Do Some Annotation Checking

    my @array=split(" ",$annotation);
    
    my $total=$#array+1;
    my $discarded=0;	
    
    foreach my $element (@array) {
        $_=$element;
        if (
            (/^PROTEIN$/) 
            || (/^FRAGMENT$/) 
            || (/^\d+$/) 
            || (/^HSPC\d+/) 
            || (/^FACTOR$/) 
            || (/^HYPOTHETICAL$/) 
            || (/^KIAA\d+/) 
            || (/^PRECURSOR$/) 
            || (/^EST$/) 
            || (/\S+RIK/) 
            || (/IMAGE:\d+/)
           )  {              $discarded++;    }
    }
    
    $_=$annotation;
    #Global Fixes;
    if (
        /CDNA/ 
        && /FIS/ 
        && /CLONE/ 
        && !/WEAKLY SIMILAR/ 
        && !/MODERATELY SIMILAR/
       ) {
        $total=0;
    }
    
    $_=$annotation;
    $annotation=~ s/EC (\d+) (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.$4/;
    $annotation=~ s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.-/;
    $annotation=~ s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.-\.-/;
    $annotation=~ s/(\d+) (\d+) KDA/$1\.$2 KDA/;
    
    if (($total-$discarded) <= 0) {
        print FILEOUT "$cluster_id\t$annotation\t$score\t:$members\n";
        $annotation="UNKNOWN"; 
        $score=0;
    }
    $total_discarded += $discarded;

    $final_total +=  ($#{$clusters{$cluster_id}}+1);
    $members=join(":",@{$clusters{$cluster_id}});
    print "ENSF";
    printf("%011.0d",$cluster_id+1);
    print "\t$annotation\t$score\t:$members\n";
}                                       # foreach $cluster_id

print STDERR "FINAL TOTAL: $final_total\n";
print STDERR "discarded: $total_discarded (see $discarded_file)\n";

sub numeric { $a <=> $b}

