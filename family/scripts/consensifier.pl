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
        $desc= &apply_edits($desc);
        push(@{$hash{$cluster}},$desc);
    }
}
close(FILE) || die "$filter:$!";


sub as_words { 
    #add ^ and $ to regexp
    my (@words);
    my @newwords=();

    foreach my $word (@words) { push @newwords, "^$word\$" };
}

sub apply_edits  { 
    local($_)=@_;

my @deletes = (( 'FOR\$',  'SIMILAR TO\$', 'SIMILAR TO PROTEIN\$', 
               'RIKEN.*FULL.*LENGTH.*ENRICHED.*LIBRARY',
               '.*\d\d\d+.*',
               'HYPOTHETICAL PROTEIN'
               ), &as_words(qw(NOVEL PUTATIVE PREDICTED 
                               UNNAMED UNNMAED ORF CLONE MRNA 
                               CDNA EST RIKEN FIS KIAA\d+ \S+RIK IMAGE HSPC\d+
                               FOR HYPOTETICAL HYPOTHETICAL)));

# warn join("\n", @deletes),"\n"; exit 2;

    foreach my $re ( @deletes ) { s/$re//g; }

    #Apply some fixes to the annotation:
    s/EC (\d+) (\d+) (\d+) (\d+)/EC $1.$2.$3.$4/;
    s/EC (\d+) (\d+) (\d+)/EC $1.$2.$3.-/;
    s/EC (\d+) (\d+)/EC $1\.$2.-.-/;
    s/(\d+) (\d+) KDA/$1.$2 KDA/;

    $_;
}

foreach my $cluster (sort sort_num(keys(%hash))) {
    print "$cluster\t";

    my @array=@{$hash{$cluster}};
    
    my $total_members=scalar(@array);
#    my $final_annotation = "AMBIGUOUS";
    my $best_annotation;

    if ($total_members==1) {
        $best_annotation= $ {hash{$cluster}}[0];
    }

    my %lcshash = undef;
    my %lcnext = undef;
    while (@array) {
        # do an all-against-all LCS (longest commong substring) of the
        # descriptions of all members; take the resulting strings, and
        # again do an all-against-all LCS on them, until we have nothing
        # left. The LCS's found along the way are in lcshash.
        #
        # Incidentally, longest common substring is a misnomer, since it
        # is not guaranteed to occur in either of the original strings. It
        # is more like the common parts of a Unix diff ... 
        for (my $i=0;$i<@array;$i++) {
            for (my $j=$i+1;$j<@array;$j++){
                my @list1=split(" ",$array[$i]);
                my @list2=split(" ",$array[$j]);
                my @lcs=LCS(\@list1,\@list2);
                my $lcs=join(" ",@lcs);
                $lcshash{$lcs}=1;
                $lcnext{$lcs}=1;
            }
        }
        @array=keys(%lcnext);
        undef %lcnext;
    }

    my ($best_score, $best_perc)=(0, 0);
    foreach my $candidate_consensus (sort sort_len_desc(keys(%lcshash))) {
        my @temp=split(" ",$candidate_consensus);
        my $length=@temp;               # num of words in annotation

        # see how many members of cluster contain this LCS:

        my ($lcs_count)=0;
        foreach my $orig_desc (@{$hash{$cluster}}) {
            my @list1=split(" ",$candidate_consensus);
            my @list2=split(" ",$orig_desc);
            my @lcs=LCS(\@list1,\@list2);
            my $lcs=join(" ",@lcs);  
            
            if ($lcs eq $candidate_consensus
                || index($orig_desc,$candidate_consensus) != -1 # addition;
                # many good (single word) annotations fall out otherwise
               ) {
                $lcs_count++;
                
                # Following is occurs frequently, as LCS is _not_ the longest
                # common substring ... so we can't use the shortcut either
                
                # if ( index($orig_desc,$candidate_consensus) == -1 ) {
                #   warn "lcs:'$lcs' eq cons:'$candidate_consensus' and
                # orig:'$orig_desc', but index == -1\n" 
                # }
            }
        }	
        
        my $perc=($lcs_count/$total_members)*100;
        my $score=$perc + ($length*14); # take length into account as well
        if (($perc >= 40) && ($length >= 1)) {
            if ($score > $best_score) {
                $best_score=$score;
                $best_perc=$perc;
                $best_annotation=$candidate_consensus;
            }
        }
    }
    if ($best_perc==0 || $best_perc >= 100 )  {
        $best_perc=100;
    }
    print ">>>$best_annotation<<<\t$best_perc\n";
    $best_annotation="";
}                                       # foreach cluster

sub sort_num { $a <=> $b };

sub sort_len_desc { length($b) <=> length($a) };
