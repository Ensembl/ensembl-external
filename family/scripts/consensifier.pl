#!/usr/local/bin/perl
# $Id$
# 
# Derives consensus annotations from descriptions in a database, using a
# longest common substring approach.
#

use strict;
use Getopt::Std;

use Algorithm::Diff qw(diff LCS traverse_sequences);

my @allowed_dbs= qw(SWISSPROT SPTREMBL);

my $opts = 'hd:';
use vars qw($opt_h $opt_d);

my $Usage=<<END_USAGE;

Usage:
  $0 -d database file.annotated > outfile
  Options:
   -h          : this message
   -d DATABASE : the database to use (allowed: @allowed_dbs)
END_USAGE
  #;
  ;

if (@ARGV!=3 
    || !getopts($opts) 
    || $opt_h 
    || !grep( $opt_d eq $_, @allowed_dbs ) ) {
    die $Usage; 
}

my $database=$opt_d;

$|=1;

my $file=$ARGV[0];
die "$file: can't open" unless -f $file;
my $goners='().-';
my $spaces= ' ' x length($goners);
my $filter = "tr '$goners' '$spaces' < $file";
open (FILE,"$filter | ") || die "$filter: $!";

my %hash;
while (<FILE>) {
    /^\S+\s+(\d+)\s+(\S+)\s+>(.*)/;
    my $protein=$2;
    my $cluster=$1;
    my $desc=$3;
    my @temp=split(" ",$desc);
    pop(@temp);
    $desc=join(" ",@temp);
    
    if ( /$database/ ) {
        push(@{$hash{$cluster}},$desc);
    }
}
close(FILE) || die "$filter:$!";

foreach my $cluster (sort sort_num(keys(%hash))) {
    print "$cluster\t";
    my %lcshash = undef;
    my %lcnext = undef;

    my @array=@{$hash{$cluster}};
    
    my $total_members=$#array+1;
    my $temp=join("\n",@array);
    my $final_annotation;

    if ($total_members==1) {
        $final_annotation= $ {hash{$cluster}}[0];
    }

    while ($#array > 0) {
        $temp=$#array+1;
        for (my $i=0;$i<$#array+1;$i++) {
            for (my $j=$i+1;$j<$#array+1;$j++){
                my @list1=split(" ",$array[$i]);
                my @list2=split(" ",$array[$j]);
                my @lcs=LCS(\@list1,\@list2);
                my $lcs=join(" ",@lcs);
                $lcshash{$lcs}=1;
                $lcnext{$lcs}=1;
            }
        }
        my $j=0;
        undef(@array);
        foreach my $newthing (keys(%lcnext)) {
              $array[$j]=$newthing;
              $j++;
          }
        undef %lcnext;
    }

    my $best=0;
    my $best_lcs=0;
    foreach my $final (sort sort_len(keys(%lcshash))) {
        my @temp=split(" ",$final);
        my $length=$#temp+1;
        my $lcs_count=0;
	
        foreach my $check (@{$hash{$cluster}}) {
            my @list1=split(" ",$final);
            my @list2=split(" ",$check);
            my @lcs=LCS(\@list1,\@list2);
            my $lcs=join(" ",@lcs);  
            
            if ($lcs eq $final) {
                $lcs_count++;
            }
        }	
        
        $lcs_count=($lcs_count/$total_members)*100;
        my $score=$lcs_count+($length*14);
        if (($lcs_count >= 40) && ($length >= 1)) {
            if ($score > $best) {
                $best=$score;
                $best_lcs=$lcs_count;
                $final_annotation=$final;
            }
        }
    }
    if ($best_lcs==0)  {
        $best_lcs=100;
    }
    print ">>>$final_annotation<<<\t$best_lcs\n";
    $final_annotation="";
}

sub sort_num { $a <=> $b };

sub sort_len { length($b) <=> length($a) };
