#!/usr/local/bin/perl 

# Script to assembl the consensus annotations from different files into
# final ones.

$|=1;
use POSIX;
use strict;
use Getopt::Std;

### deletes to be applied to correct some howlers:
my @deletes = (' FOR\$', 'SIMILAR TO\$', 'SIMILAR TO PROTEIN\$' ); #

### any complete annotation that matches one of the following, gets
### ticked off completely:
my @useless_annots = 
  qw( ^.$  
      ^\d+$ 
      .*RIKEN.*FULL.*LENGTH.*ENRICHED.*LIBRARY.*
    );

### regexp to split the annotations into separate words for scoring:
my $word_splitter='[\/ \t,:]+';

### words that get scored off; the balance of useful/useless words
### determines whether they make it through.
### (these regexps are surrounded by ^ and $ before they're used)
my @useless_words =  # and misspellings, that is
  qw( PROTEIN UNKNOWN FRAGMENT HYPOTHETICAL HYPOTETICAL 
      NOVEL PUTATIVE PREDICTED UNNAMED UNNMAED
      PEPTIDE KDA ORF CLONE MRNA CDNA FOR
      EST
      RIKEN FIS KIAA\d+ \S+RIK IMAGE HSPC\d+  # db-specific ID's
      .*\d\d\d+.*                       # anything that looks like an ID
    );

use vars qw($opt_h);
my $opts = 'h';
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

# sanity check on the words:
foreach my $w (@useless_words) {
    if ( $w =~ /$word_splitter/) {
        die "word '$w' to be matched matches ".
          "the word_splitter regexp '$word_splitter', so will never match";
    }
}

my $discarded_file="annotations.discarded";

open (DISCARDED,">$discarded_file") || die "$discarded_file: $!";

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

my (%descriptions, %scores);

$file = $ARGV[2];
# make sure we're read the SPTREMBL first, then override with SWISSPROT
die "$file: expecting 'tr' as part of filename: second one should be trembl" 
  unless $file =~ /tr/i;
read_consensus($file, \%descriptions, \%scores);

# now override with SWISSPROT:
$file=$ARGV[1];
die "$file: expecting 'sw' as part of filename: first one should be swissprot" 
  unless $file =~ /sw/i;
read_consensus($file, \%descriptions, \%scores);

my $final_total=0;
my $discarded=0;

foreach my $cluster_id (sort numeric (keys(%clusters))) {
    my $annotation="UNKNOWN";
    my $score=0;

    if ( $descriptions{$cluster_id}  ) {
        $annotation=$descriptions{$cluster_id};
        $score=$scores{$cluster_id};
        if ($score==0) {
            $score=1;
        }
    }

    # apply the deletes:
    foreach my $re ( @deletes ) { $annotation =~ s/$re//g; }

    my $useless=0;	
    my $total= 1;

    $_=$annotation;
    # see if the annotation as a whole is useless:
    if (  grep($annotation =~ /$_/, @useless_annots )   ) {
        $useless=1000;
    } else {
        # word based checking: what is balance of useful/less words:
        my @words=split(/$word_splitter/,$annotation);
        $total= int(@words);
        foreach my $word (@words) {
            if ( grep( $word =~ /^$_$/, @useless_words ) ) {
                $useless++;
            }
        }
        $useless += 1 if $annotation =~ /\bKDA\b/;
        # (because the kiloDaltons come with at least one meaningless number)
    }
        
    if ( $annotation eq ''
         || ($useless >= 1 && $total == 1)
         || $useless > ($total+1)/2 ) {
        print DISCARDED "uselessness: $useless/$total: $cluster_id\t$annotation\t$score\n";
        $discarded++;
        $annotation="UNKNOWN"; 
        $score=0;
    }

    $_=$annotation;

    #Apply some fixes to the annotation:
    s/EC (\d+) (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.$4/;
    s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.-/;
    s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.-\.-/;
    s/(\d+) (\d+) KDA/$1\.$2 KDA/;
        
    my @members = @{$clusters{$cluster_id}};
    $final_total +=  int(@members);
    printf "ENSF%011.0d\t%s\t%d\t:%s\n"
      , $cluster_id+1, $_, $score, join(":",@members);
}                                       # foreach $cluster_id
close(DISCARDED);

print STDERR "FINAL TOTAL: $final_total\n";
print STDERR "discarded: $discarded (see $discarded_file)\n";

sub numeric { $a <=> $b}

### read consensus annotations and scores into hashes
sub read_consensus { 
    my($file, $deschash, $scorehash)=@_;
    my (%hash, %score);

    open (FILE,$file) || die "$file:$!";

    while (<FILE>) {
        my ($id, $desc, $score) = ( /^(\d+)\s+>>>(.*)<<<\s+(\d+)/ );
        if (0 &&                        # for debugging purposes
            defined ( $deschash->{$id} ) ) {
            warn "for $id, replacing '$deschash->{$id}' (score $scorehash->{$id})"
              ." with '$desc' (score $score)\n";
        }
        $deschash->{$1}=$2;
        $scorehash->{$1}=$3;
    }
    close(FILE) || die "$file:$!";
    undef;
}
