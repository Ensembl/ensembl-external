#!/usr/local/bin/perl
# $Id$

# based on ~ae1/alignments2/go.pl

use strict;

use Getopt::Std;

my $queue = 'acarilong';
my $outdir='alignments';
my $opts = 'fc';
use vars qw($opt_f $opt_c $opt_h);

my $Usage=<<END_USAGE;
Usage:
  $0 [ options ]  foo.clusters  bar.pep
  -h : this message
  -c : check (do not run, unless providing -f option as well)
  -f : rerun jobs that failed

foo.clusters is a file like that produced by by parse_mcl.pl; bar.pep is a
FASTA file containing all the peptides clustered.  
Output goes to $outdir/clusterno.aln

END_USAGE
;


my $fetcher = "$ENV{FAMPATH}/scripts/fetcher";
my $clustalw = "/nfs/acari/ae1/bin/clustal/clustalw"; # or wherever; any
                                                      # vanilla clustalw
                                                      # should be fine


if (@ARGV==0 || !getopts($opts) || $opt_h ||  @ARGV!=2 ) {
    die $Usage; 
}

my $check= $opt_c;
my $fix = $opt_f;

my $clusterfile=$ARGV[0];
my $peptidesfile=$ARGV[1];

if (!defined $ENV{FAMPATH}) {
    die "need env.var. FAMPATH to be set (for finding `scripts/fetcher')\n";
}


my %families;
my %has_ens_members;
open (FILE,$clusterfile) || die "$clusterfile:$!";
while (<FILE>) 	{
    my ($cluster, $member) = (/^(\d+)\s+(\S+)/);
    push(@{$families{$cluster}},$member);
    if ( $member =~  /COBP/ || $member =~ /ENS/ ) {
        $has_ens_members{$cluster}=1;
    }
}
close(FILE) || die "$clusterfile:$!";

if (! -e $peptidesfile ) {
    die "can't find $peptidesfile\n";
}

foreach my $cluster (sort numeric(keys(%families))) {

    my $command;
    if (($has_ens_members{$cluster})     # only if it has ENS peptides
        && ( @{$families{$cluster}} > 1) # and only if more than 1!
       ) {

        my $mems=join(" ",@{$families{$cluster}});
        my $aliseqs="/tmp/ali-seqs.$cluster-$$";
        my $outfile = "$outdir/$cluster.aln";

        $command = "bsub -q $queue "
          ."-e aln-err/$cluster.err -o aln-out/$cluster.out "
          ."\' $fetcher < $peptidesfile $mems > $aliseqs; "
          ."$clustalw $aliseqs -outfile\=$outfile;"
          ."rm $aliseqs;"
          ."\'";
    
        if (! $check && ! $fix ) {      # ie, normal run
            warn "submitting $cluster $mems\n";
            if (system($command)) { die "something wrong with $command"; }
        } else {
            warn "Checking\n";
            warn "$command\n";
            unless (-e $outfile && -s $outfile) {
                warn "$outfile not found or empty\n";
                if ($fix) {
                    warn "resubmitting $cluster $mems\n";
                    if (system($command)) { 
                        die "something wrong with $command"; 
                    }
                }
            }
        }
    }
}

sub numeric {$a <=> $b}
