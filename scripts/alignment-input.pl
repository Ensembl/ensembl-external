#!/usr/local/bin/perl
# Inputs the alignments into a Family database
# 
# $Id$

die  "not tested";

use DBI;
use DBD::mysql;

# defaults
my $host='ecs1c';
my $idmapping='translation.idmap';
my $dbname='family100';
my $user='root';
my $dbpass=undef;


&GetOptions( 
	     'host:s'     => \$host,
	     'idmapping:s'   => \$idmapping, 
	     'dbname:s'   => \$dbname, 
	     'dbuser:s'   => \$dbuser,
	     'dbpass:s'   => \$dbpass,
	     );

$alignments_dir = './alignments';
@alignment_files  = `ls $alignment_dir`; 
die $@ if $@;

$|=1;

open (PROC,"| mysql -u $user $dbname") || die $!;

# read idmapping:
open (FILE,$idmapping) || die "$idmapping:$!";
while (<FILE>)  {
    /^(\S+)\s+(\S+)/;
    $hash{$1}=$2;
}

foreach $file (@alignment_files)  {
    chop($file);
    
    $id=(split('\.',$file))[0];
    $id=$id+1;
    $alignment="";
    $f= "$alignments_dir/$file";
    open (FILE,) || die "$f:$!";
    while (<FILE>) {
        if (/^(COBP\d+)(.*)/)
          {
              $_="$hash{$1}$2\n";
          }
        $alignment=join("",$alignment,$_);
    }
    
    print STDERR "done $file, size: ",length($alignment),"\n";
    print PROC "INSERT INTO alignments VALUES ($id,\'$alignment\')\;\n";
}                                       # foreach file


