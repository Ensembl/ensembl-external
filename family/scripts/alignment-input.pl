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

&GetOptions( 
	     'dbhost:s'     => \$dbhost,
# 	     'idmapping:s'   => \$idmapping, 
	     'dbname:s'   => \$dbname, 
	     'dbuser:s'   => \$dbuser,
	     'dbpass:s'   => \$dbpass,
	     );

# my $alignments_dir = './alignments.mapped';
my $alignments_dir = './test2';
my @alignment_files  = `ls $alignments_dir`; 
die $@ if $@;

my $dbh=db_connect("database=$dbname;host=$dbhost;user=$dbuser;pass=$dbpass");

warn "Using internal id's for the families !\n";

my $insertq = <<__ENDOFQUERY__;
insert into alignments values(?, ?)
__ENDOFQUERY__
;
$insertq = $dbh->prepare($insertq) || die  $DBI::errstr;

my $checkq = <<__ENDOFQUERY__;
SELECT count(*) 
FROM family_members fm
WHERE fm.db_id = ?
  AND fm.family = ?
__ENDOFQUERY__
;
$checkq = $dbh->prepare($checkq) || die  $DBI::errstr;

$|=1;

my $proc = "mysql -u $dbuser -h $dbhost -p$dbpass $dbname";
# using a pipe since had trouble with passing really long strings using perl
# note that we'll only 
# my $logfile = "/tmp/loadalign.$$.log";
# open (PROC,"| $proc > $logfile 2>&1 ") || die "$proc: $!";
# select(PROC);$|=1;

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
                warn "inserting $mem of $famid: not a family member";
            }
        }

        $alignment .= $_;
    }
    close(FILE) || die "$f:$!";
    
    $insertq->execute($famid, $alignment ) || warn $DBI::errstr;
    
#    print PROC "INSERT INTO alignments VALUES ($famid,\'$alignment\')\;\n";
    print STDERR "done $file, size: ",length($alignment),"\n";
}                                       # foreach file
# close(PROC) || do { 
#     warn "something wrong during loading; $proc: $!\n";
#     warn "logfile is:\n";
#     `cat $logfile >&2`;
#     warn "Note: may well be more than just this error (e.g. duplicates warnings)\n";
#     unlink($logfile); 
# };

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
