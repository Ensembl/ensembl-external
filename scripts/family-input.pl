#!/usr/local/bin/perl
# $Id$
# parser for Anton's Families
# 
# format is like:
# Cluster Number <TAB> Family Name <TAB> Annotation Score <TAB> Protein List (Colon Separated)

use DBI;
use strict;

use vars qw($opt_h $opt_r $opt_U $opt_H $opt_D $opt_C $opt_r $release 
            $opt_C $ddl);
use Getopt::Std;

my $usage = 
"Usage:\n\n\tfamily-parse.pl [-h(elp) ] -r release [-U user] [-H host] [ -D database-name ] [ -C DDL-file (to create database)] [< ] FILENAME ]\n";

my $opts = 'hr:H:U:D:C:';
getopts($opts) || die $usage;

die $usage if $opt_h;

my $user = ($opt_U || 'root');
my $host = ($opt_H || 'localhost');
my $database = ($opt_D || 'family');
my $release = ($opt_r || die " need a release number\n");
my $ddl = $opt_C;

sub _create_db {
    my ($dbh) = @_;
    $dbh->do("CREATE DATABASE $database");
    warn "problem creating database: " . $DBI::errstr if $DBI::err;
}

### Aargggh! 
sub _create_tables { 
    my ($dbh, $ddl) = @_;
    my $q = `cat $ddl`;

    # $dbh->do( "$q" ); # doesn't work @!"@$!
    my $cmd ="echo source $ddl | mysql -u $user -h $host $database";
    `$cmd`;
    warn "problem  creating tables: " . $! if $!;
}
 

# from database
sub _get_max_id { 
    my($dbh) = @_; 
    my $query = 
      "SELECT MAX(internal_id) AS id 
       FROM  family";
    
    my $sth   = $dbh->prepare($query);
    $sth->execute;
    my ($id)   = $sth->fetchrow;
    
    if (!defined $id || $id eq "") {
        $id = 0;
    }
    $id;
}

# create id for format
sub _format_fam_id {
    my $num = shift;
    sprintf "ENSF%011d", $num;
}

sub main {
    my $fam_count = 0;
    my $mem_count =0;
    my $dsn;
    my $dbh;

    my $internal_id;

    if ($ddl) {
        warn "creating...";
        $dsn = "DBI:mysql:database=mysql;host=$host";
        $dbh = DBI->connect("$dsn",'root') ||
          die "couldn't connect using $dsn and 'root':" . $DBI::errstr;
        _create_db($dbh, $ddl);
        $dbh->disconnect;

        $dsn = "DBI:mysql:database=$database;host=$host";
        $dbh = DBI->connect("$dsn",'root') ||
          die "couldn't connect using $dsn and 'root':" . $DBI::errstr;
        _create_tables($dbh, $ddl);

        warn "created...";
    }

    $dsn = "DBI:mysql:database=$database;host=$host";
    $dbh = DBI->connect($dsn,$user) ||
      die "couldn't connect using $dsn and user $user:" . $DBI::errstr;
    $dbh->{autocommit}++;

    $internal_id = _get_max_id($dbh) +1;

    my $max_desc_len  = 255;

    my $fam_q = 
      "INSERT INTO family(internal_id, id, description, release, 
                         annotation_confidence_score)
       VALUES(?,            ?,         ?,        ?,        ?)\n";
###            $internal_id, '$fam_id', '$descr', $release, $score);

    my $fam_q = $dbh->prepare($fam_q) || die $dbh->errstr;

    my $mem_q = 
      "INSERT INTO family_members(family, db_name, db_id)
                           VALUES(?,      ?,       ?)\n";
###                         $internal_id, '$db_name', '$mem'

    my $mem_q = $dbh->prepare($mem_q) || die $dbh->errstr;

    while(<>) {
        chomp;
        my ($num, $descr, $dummy, $score, $mems)= split '\t';
        my @mems = split(':', $mems);


        if (length($descr) > $max_desc_len) {
            warn "Description longer than $max_desc_len; truncating it\n";
            $descr = substr($descr, 0, $max_desc_len);
        }
        
        my $fam_id = _format_fam_id $num;
        
        $fam_q->execute($internal_id, $fam_id, $descr, $release, $score)
          || die "couldn't insert line $.:\n$_\n " . $fam_q->errstr;
        
        foreach my $mem (@mems) {
            my $db_name = ( $mem =~ /^ENSP/ )? 'ENSEMLPEP' : 'SWISSPROT';
                                        # or SPTREMBL, or SPALL ? 

            $mem_q->execute($internal_id, $db_name, $mem)
              || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
            $mem_count++;
        }
        $internal_id++;
        $fam_count++;
    }

    $dbh->disconnect;
    warn "inserted $fam_count families, having a total of $mem_count members\n";
}                                       # main

main;
exit 0;
