#!/usr/local/bin/perl
# $Id$

die "not tested yet";

use DBI;
use DBD::mysql;

$|=1;
$database=shift;
$user="root";
$password="";

open (PROC,"| mysql -u root family102");

open (FILE,$ARGV[0]);
while (<FILE>)  {
    /^(\S+)\s+(\S+)/;
    $hash{$1}=$2;
}

foreach $file (`ls ./alignments`)  {
    chop($file);
    
    $id=(split('\.',$file))[0];
    $id=$id+1;
    $alignment="";
    open (FILE,"./alignments/$file");
    while (<FILE>) {
        if (/^(COBP\d+)(.*)/)
          {
              $_="$hash{$1}$2\n";
          }
        $alignment=join("",$alignment,$_);
    }
    
    print STDERR "Total Size: ",length($alignment),"\n";
    print PROC "INSERT INTO alignments VALUES ($id,\'$alignment\')\;\n";
}


