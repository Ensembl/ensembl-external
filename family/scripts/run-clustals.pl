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
  $0 [ options ]  foo.clusters bar.pep seqs.origin
  -h : this message
  -c : check (do not run, unless providing -f option as well)
  -f : rerun jobs that failed

foo.clusters is a file like that produced by by parse_mcl.pl
bar.pep is a FASTA file containing all the peptides clustered

seqs.origin a file with DATABASE: ACCNO pairs indicating wether ACCNO
came from SWISSPROT or from SPTREMBL. 

Output goes to $outdir/clusterno.aln

END_USAGE
;


my $fetcher = "$ENV{FAMPATH}/scripts/fetcher";
my $clustalw = "/nfs/acari/ae1/bin/clustal/clustalw"; # or wherever; any
                                                      # vanilla clustalw
                                                      # should be fine


if (@ARGV==0 || !getopts($opts) || $opt_h ||  @ARGV!=3 ) {
    die $Usage; 
}

my $check= $opt_c;
my $fix = $opt_f;

my $clusterfile=$ARGV[0];
my $peptidesfile=$ARGV[1];
my $originfile=$ARGV[2];

if (!defined $ENV{FAMPATH}) {
    die "need env.var. FAMPATH to be set (for finding `scripts/fetcher')\n";
}

my %families;
my %num_ens_members;
my %num_sp_members;
my %ens_origin;
my %sp_origin;

open(FILE, $originfile) || die "$originfile:$!";
ORIG_LINE:
while(<FILE>) {
    next ORIG_LINE unless /SWISSPROT/;
    my($accno, $orig) = (/(\S+)\s*:\s*(\S+)/);
    $sp_origin{$accno}=1;
}
close(FILE) || die "$originfile:$!";

open (FILE,$clusterfile) || die "$clusterfile:$!";
while (<FILE>) 	{
    my ($cluster, $member) = (/^(\d+)\s+(\S+)/);
    push(@{$families{$cluster}},$member);
    if ( $member =~  /COBP/ || $member =~ /ENS/ ) {
        $ens_origin{$member}=1;
        $num_ens_members{$cluster}++;
    }
    if ( $sp_origin{$member}  ) {
        $num_sp_members{$cluster}++;
    }
#    last if $cluster > 10;
}
close(FILE) || die "$clusterfile:$!";

if (! -e $peptidesfile ) {
    die "can't find $peptidesfile\n";
}

foreach my $cluster (sort numeric(keys(%families))) {

    my $command;
    if (($num_ens_members{$cluster})     # only if it has ENS peptides
        && ( @{$families{$cluster}} > 1) # and only if more than 1!
       ) {

        my @wanted=();
        my @members = @{$families{$cluster}};
        my $nmembers = int(@members);

        # If cluster too big, throw away non-SPTREMBLS, unless there
        # are only SPTREMBL, in which case we take at most half,
        # selected randomly.
        if ( $nmembers < 40 ) {
            @wanted =  @members;
        } else {
            my @sps = grep( $sp_origin{$_}, @members);
            my @enses = grep( $ens_origin{$_}, @members);
            my @trembls = grep( !$ens_origin{$_} && !$sp_origin{$_}, @members); 

            my $sps = int(@sps);
            my $enses = int(@enses);
            my $trembls = int(@trembls);

            @wanted = @sps;         # start with sps
            for (my $i=int(@sps); $i<40; $i++) { # add random trembls up to 40 
                my $tr = splice(@trembls, rand @trembls, 1); 
                push @wanted, $tr;
            }
            @wanted = (@wanted, @enses); # finally add all the enses
            my $nrandom = 40 - $sps; $nrandom = 0 if $nrandom < 0;
            warn "found $sps SWISS-PROTs, $trembls TrEMBLs in cluster of $nmembers members; kept all SPs and $nrandom random TrEMBLs\n";
        }

        my $mems=join(" ",@wanted);


        # my $aliseqs="/tmp/aliseqs.$cluster-$$";
        warn "testing"; my $aliseqs="./aliseqs.$cluster";

        my $outfile = "$outdir/$cluster.aln";

        $command = "bsub -q $queue "
          ."-e aln-err/$cluster.err -o aln-out/$cluster.out "
          ."\' $fetcher < $peptidesfile $mems > $aliseqs; "
          ."$clustalw -infile=$aliseqs -outfile\=$outfile -outorder=aligned;"
          ."rm $aliseqs;"
          ."\'";
    
        if (! $check && ! $fix ) {      # ie, normal run
            warn "submitting $cluster $mems\n";
            if (system($command)) { die "something wrong with $command"; }
        } else {
# debugging
#             `$fetcher < $peptidesfile $mems > $aliseqs`;
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
