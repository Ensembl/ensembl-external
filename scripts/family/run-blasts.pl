#!/usr/local/bin/perl
# $Id$

# submits all the blast jobs to the queue. NOTE:This script is also called by 
# consistency.pl. (Maybe merge it into here).

use strict;
$|=1;

use Getopt::Std;

my $dflt_q='acarilong';
my $dflt_d='seq';
my $dflt_m='/usr/local/ensembl/data/blastmat';

my $blast="/usr/local/ensembl/bin/blastall_2.0.11";
my $e_value = 0.00001;

my $workdir=`pwd`;
chomp($workdir);

my $dflt_i="$workdir/seq";
my $dflt_o="$workdir/results";

my $opts = 'hq:i:o:n:Cgf';
use vars qw($opt_h $opt_q $opt_i $opt_o $opt_m $opt_n $opt_g $opt_C $opt_f);

my $Usage=<<END_USAGE;

Usage:
  $0 [ options ]  /data/sync/peptidefile
  Options:
   -m DIR   : where to find blast matrices (default: $dflt_m)
   -q QUEUE : use QUEUE  (default: $dflt_q)
   -i DIR   : take chunks (<database>.<N>) from DIR (default: $dflt_i)
   -o DIR   : write output (<N>.{out.gz,jobout,joberr}) to DIR (default: $dflt_o)
   -n N     : do things for just chunk N
   -g       : go do it
   -C       : consistency-check mode: resubmits jobs that appear to have failed
   -f       : also resubmit jobs that appear to be still running or 
              have not run at all (typically when the lsf says all is done)

Note: the envvar FAMPATH needs to be defined; source setenv.(c)sh (adapt
      from setenv.(c)sh.example) for this.

END_USAGE
#'; # pacify emacs

if (@ARGV==0 || !getopts($opts) || $opt_h ||  @ARGV!=1 ) {
    die $Usage; 
}

if (!defined $ENV{FAMPATH}) {
    die "need env.var. FAMPATH to be set (for finding `scripts/parse')\n";
}

my $queue = ($opt_q || $dflt_q);
my $blastmat = ($opt_m || $dflt_m);

my $chunks_dir= $opt_i || $dflt_i ;     # where chunks are taken from
-d $chunks_dir || die "Expecting input in $chunks_dir: $!";
$chunks_dir = &absolutify($chunks_dir);

my $results_dir= $opt_o || $dflt_o; 
mkdir($results_dir, 0755) || warn "$results_dir: $!";
warn "output will go to $results_dir\n";

my $arg = shift; 
-f $arg || die "$arg: $!";

my ($sync_dir,$database)= &file_parts($arg);

warn "``$sync_dir''is not an absolute filename;
expecting something like /data/sync/stuff\n" if $sync_dir !~ /\//;

my $parse = "$ENV{FAMPATH}/parse";

my @chunks = `(ls $chunks_dir/*.[0-9]*;)`;

CHUNK:
foreach my $chunk ( @chunks) {
    chomp($chunk);
    my $i = (split /\//, $chunk)[-1];
    $i = (split /\./, $i)[-1];

    if ($opt_n) {
        next CHUNK unless  $opt_n ==  $i;
    }
      
    my $tmp_name="/tmp/fam-$ENV{USER}-$$-$i";
    my $tmp_file="$tmp_name.out";
    my $command=join(" ", 
                  ("bsub -q $queue", 
                   "-e $results_dir/$i.joberr", 
                   "-o $results_dir/$i.jobout",
                   "-E \" ls -al $sync_dir/$database.phr\" ",
                   " \" ",               # 
                   # the real blast run:
                   "BLASTMAT=$blastmat $blast",
                   "-p blastp",
                   "-d $sync_dir/$database",
                   "-i $chunk",
                   " -e $e_value",
                   "| $parse > $tmp_file;", 
#                   "gzip < $tmp_file > $results_dir/$i.out.gz && ",
#                   "rm -f $tmp_name.*",
# (nfs may get overloaded; rcp should be more robust
                   "gzip $tmp_file && ",
                   "/usr/bin/rcp $tmp_file.gz acari:$results_dir/$i.out.gz && ",
                   "rm -f $tmp_name.*",
                   " \" ")
                 );

    my $run =1;

    if ($opt_C) {
        my $expected = &count_expected($chunks_dir, $i);
        my $found = &count_found($results_dir, $i);
        
        if ($found == -1) { 
            if ($opt_f) {
                warn "No results for job $i; resubmitting it\n";
                $run=1 ;
            } else {
                warn "No results for job $i; still running? NOT resubmitting";
                $run=0;
            }
        } elsif ($found != $expected) {
            warn "job $i: expecting $expected, found $found; resubmitting\n";
            system("rm -fr $results_dir/$i.*") if $opt_g;
            $run=1;
        } else { 
            warn "job $i ok\n";
            $run=0;
        }
    }
    warn "$command\n" if $run;
    if ( $opt_g && $run ) {
        my $pants = system ($command);
        print "Result = $pants\n";
        sleep 1;
    }
}                                       # foreach chunk

if (! $opt_g) { 
    warn "Not running; specify ``-g'' to actually submit jobs; see also -h\n";
}                                       # for all chunks

sub count_expected {
    my ($dir, $num)=@_;
    my $cmd = "grep -c '^>' $dir/*.pep.$num";
    my $count = `$cmd`;
    if ($?) { 
        warn "$cmd had errors;";
        return -1;
    }
    chomp($count);
    $count;
}

sub count_found {
    my ($dir, $num) = @_;
    my $cmd="gunzip -c $dir/$num.out.gz | tail -1";
    my $count=`$cmd`;
    if ($?) { 
        warn "$cmd had errors;";
        return -1;
    }
    $count =~ s/\D*(\d+)$/$1/;
    chomp($count);
    $count= -1 if $count eq '';
    $count;
}     

sub absolutify {
    my ($dir)=shift;
    if ($dir !~ /\//) { 
        my $pwd=`pwd`;
        chomp $pwd;
        $dir = "$pwd/$dir";
    }
    $dir;
}

sub file_parts {
    my $arg=shift;
    my @t = split(/\//, $arg);
    my $db= pop @t;
    my $dir=join('/', @t);
    ($dir, $db);
}
