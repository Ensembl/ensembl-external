#!/usr/local/bin/perl
# Inputs the alignments into a Family database
# 
# $Id$

use DBI;
use DBD::mysql;
use strict;

use Getopt::Long;

# defaults
my $dbhost='ecs1c';
my $dbname='family100';
my $dbuser='ensadmin';
my $dbpass='secret' ;
my $tmpdir = `pwd`;                     # use absolute path, and no /tmp, 
my $alignments_dir = './alignments';

chomp($tmpdir);                         # otherwise mysql server uses
                                        # local file

&GetOptions( 
	     'dbhost:s'     => \$dbhost,
# 	     'idmapping:s'   => \$idmapping, 
	     'dbname:s'   => \$dbname, 
	     'dbuser:s'   => \$dbuser,
	     'dbpass:s'   => \$dbpass,
             'tmpdir:s'  => \$tmpdir,
             'dir:s' => \$alignments_dir, # where to read from
	     );

my @alignment_files  = `ls $alignments_dir`; 
die $@ if $@;

my $dbh=db_connect("database=$dbname;host=$dbhost;user=$dbuser;pass=$dbpass");

warn "Using internal id's for the families !\n";

$dbh->{AutoCommit}++;
$dbh->{RaiseError}++;

my $checkq = <<__ENDOFQUERY__;
SELECT count(*) 
FROM family_members fm
WHERE fm.db_id = ?
  AND fm.family = ?
__ENDOFQUERY__
;
$checkq = $dbh->prepare($checkq) || die  $DBI::errstr;

my $all_alignments="$tmpdir/alignments-$$.dat";
warn "Creating file $all_alignments ... \n";
open(ALL, "> $all_alignments" ) || die "$all_alignments: $!";
foreach my $file (@alignment_files)  {
    chomp($file);
    
    my $famid=(split('\.',$file))[0];    $famid += 1;
    my $alignment="";
    my $f= "$alignments_dir/$file";
    open (FILE,$f) || die "$f:$!";

    my $empty_lines=0;
    while (<FILE>) {
        $empty_lines++ if /^$/;
        if ( /^\S+/ && !/^CLUSTAL/ && $empty_lines == 2) { 
            my ($mem) = (/^(\S+)\b/);
            unless (isa_fam_member($famid, $mem)) {
                warn "$mem not a member of $famid!";
            }
        }
        s/\n/\\n/;
        $alignment .= $_;
    }
    close(FILE) || die "$f:$!";
 
    print ALL "$famid\t$alignment\n";
    warn "done $file, size: ",length($alignment),"\n";
}                                       # foreach file
close(ALL) || die "$all_alignments: $!";
warn "Done creating file $all_alignments ... \n";

warn "Importing $all_alignments ... \n";
if ( $dbh->do("load data infile '$all_alignments' into table alignments") ) { 
    warn "Done importing $all_alignments; this file now deleted\n";
    unlink $all_alignments;
} else {
  warn "Something wrong: $DBI::errstr; file $all_alignments not deleted";
}

sub isa_fam_member {
    my($famid, $mem) = @_;

    $checkq->execute($mem, $famid);

    my ($count) = $checkq->fetchrow_array;
    $count;
}


## This comes from family-inputpl, and should at one point be put somewhere
## more central (the ones in EnsEMBL load modules etc. that are not relevant)
## Takes string that looks like
## "database=foo;host=bar;user=jsmith;passwd=secret", connects to mysql
## and return the handle
sub db_connect { 
    my ($dbcs) = @_;

    my %keyvals= split('[=;]', $dbcs);
    my $user=$keyvals{'user'};
    my $paw=$keyvals{'pass'};
#    $dbcs =~ s/user=[^;]+;?//g;
#    $dbcs =~ s/password=[^;]+;?//g;
# (mysql doesn't seem to mind the extra user/passwd values, leave them)

    my $dsn = "DBI:mysql:$dbcs";

    my $dbh=DBI->connect($dsn, $user, $paw) ||
      die "couldn't connect using dsn $dsn, user $user, password $paw:" 
         . $DBI::errstr;
    $dbh;
}                                       # db_connect
