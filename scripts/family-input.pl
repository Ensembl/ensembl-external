#!/usr/local/bin/perl
# $Id$
# parser for Anton's Families
# 
# format is like:
# Cluster Number <TAB> Family Name <TAB> Annotation Score <TAB> Protein List (Colon Separated)

use DBI;
use strict;

use vars qw($opt_h $opt_r $opt_U $opt_H $opt_D $opt_C $opt_r $release 
            $opt_C $ddl $max_desc_len 
            $enspep_dbname $ensgene_dbname $sp_dbname
            $fam_id_format);

use Getopt::Std;

$max_desc_len = 255;                    # max length of description
$enspep_dbname = 'ENSEMBLPEP';          # name of EnsEMBL peptides database
$ensgene_dbname = 'ENSEMBLGENE';        # name of EnsEMBL peptides database
$sp_dbname = 'SWISSPROT';               # name of SWISSPROT database
my $add_ens_pep =1;                     # should ens_peptides be added
my $add_ens_gene =1;                    # should ens_genes be added
my $add_sp =1;                          # should swissprot entries be added

$fam_id_format= 'ENSF%011d';

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

$ddl = '../sql/family.sql' if $ddl == 1;

sub create_db {
    my ($dbh) = @_;
    $dbh->do("CREATE DATABASE $database");
    warn "problem creating database: " . $DBI::errstr if $DBI::err;
}

### Aargggh! 
sub create_tables { 
    my ($dbh, $ddl) = @_;
    my $q = `cat $ddl`;

    # $dbh->do( "$q" ); # doesn't work @!"@$!
    my $cmd ="echo source $ddl | mysql -u $user -h $host $database";
    `$cmd`;
    warn "problem  creating tables: " . $! if $!;
}
 

# from database
sub get_max_id { 
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
sub format_fam_id {
    my $num = shift;
    sprintf $fam_id_format, $num;
}

sub open_ensembl { 
warn "using hardcoded host, db and user here";
     my ($host, $user, $db) = ('ensrv3', 'ensro', 'simon_oct07');
#     my ($host, $user, $db) = ('ecs1b', 'ensro', 'arne_ensembl_main');

    my $dbh=DBI->connect("DBI:mysql:database=$db;host=$host", $user) ||
      die "couldn't connect to $db at $host as $user:" . $DBI::errstr;
    $dbh;
}

sub ens_gene_of {
    my ($q, $pepid) = @_;
    $q->execute($pepid);

    my $rowhash;
    my @results;
    while ( $rowhash = $q->fetchrow_hashref) {
        push @results, $rowhash->{id};
    }
    die "couldn't execute:" . $q->err if $q->errstr;
    if (@results != 1) {
        if (@results){
            warn "for $pepid, I got these genes: " 
              . join(':', @results), "\n"; 
            die "not exactly one gene";
        } else {
            warn "for $pepid, I got no genes\n";
            # die "not exactly one gene"; # ignore for now
        }
    }
    my $id =     $results[0];
    warn "gene  is: $id \n";
    $id;
}

sub main {
warn "checking for /^COBP/ too ...";
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
        create_db($dbh, $ddl);
        $dbh->disconnect;

        $dsn = "DBI:mysql:database=$database;host=$host";
        $dbh = DBI->connect("$dsn",'root') ||
          die "couldn't connect using $dsn and 'root':" . $DBI::errstr;
        create_tables($dbh, $ddl);

        warn "created...";
    }

    $dsn = "DBI:mysql:database=$database;host=$host";
    $dbh = DBI->connect($dsn,$user) ||
      die "couldn't connect using $dsn and user $user:" . $DBI::errstr;
    $dbh->{autocommit}++;


    # separate handle for looking up translation from enspep to ensgene:
    my $ensdb = open_ensembl();

    $internal_id = get_max_id($dbh) +1;
    my $fam_q = 
      "INSERT INTO family(internal_id, id, description, release, 
                         annotation_confidence_score)
       VALUES(?,            ?,         ?,        ?,        ?)\n";
###            $internal_id, '$fam_id', '$descr', $release, $score);

    $fam_q = $dbh->prepare($fam_q) || die $dbh->errstr;

    my $mem_q = 
      "INSERT INTO family_members(family, db_name, db_id)
                           VALUES(?,      ?,       ?)\n";
###                         $internal_id, '$db_name', '$mem'

    $mem_q = $dbh->prepare($mem_q) || die $dbh->errstr;


    my $gene_q = 
      "SELECT g.id 
       FROM gene g, translation tl, transcript tc 
       WHERE tl.id = ? 
           AND tl.id = tc.translation and tc.gene = g.id";

    $gene_q = $ensdb->prepare($gene_q) || die $dbh->errstr;

                                              
    my %gene_fam = undef;
    while(<>) {
        chomp;
        my ($num, $descr, $dummy, $score, $mems)= split '\t';
        
        ## work around bug in format:
        if ($score =~ /^ENSP/ || $score =~ /^COBP/) {
            warn "correcting score for ENSEMBLPEP-only cluster\n";
            $mems = $score;
            $score = 0;
        }

        my @mems = split(':', $mems);


        if (length($descr) > $max_desc_len) {
            warn "Description longer than $max_desc_len; truncating it\n";
            $descr = substr($descr, 0, $max_desc_len);
        }
        
        my $fam_id = format_fam_id $num;
        
        $fam_q->execute($internal_id, $fam_id, $descr, $release, $score)
          || die "couldn't insert line $.:\n$_\n " . $fam_q->errstr;

        my %seen_gene = undef;          # just for filtering transcripts
        foreach my $mem (@mems) {
            if ($mem =~ /^ENSP/ || $mem =~ /^COBP/ ) {
                if ($add_ens_pep)  {
                    $mem_q->execute($internal_id, $enspep_dbname, $mem)
                      || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
                    $mem_count++;
                }
                
                if ($add_ens_gene) {
                    my $ens_gene_id = ens_gene_of($gene_q, $mem);

                    if ( ! $ens_gene_id ) {
                        warn '#' x 72, "\n";
                        warn '#' x 72, "\n";
                        warn "### did not find gene of $mem\n";
                        warn '#' x 72, "\n";
                        warn '#' x 72, "\n";
                    } elsif ( defined $seen_gene{$ens_gene_id}) {
                        warn "have seen $ens_gene_id already (first for: $seen_gene{$ens_gene_id}); probably OK.\n";
                    } else { 
                        $seen_gene{$ens_gene_id}=$mem;
                        $mem_q->execute($internal_id, $ensgene_dbname, 
                                        $ens_gene_id)
                          || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
                        $mem_count++;
                    }

                    ### check to see if this gene was previously assigned
                    ### to another family; if so, that means trouble
                    if ( defined( $gene_fam{$ens_gene_id} )
                         &&       $gene_fam{$ens_gene_id} ne $fam_id ) {
                        warn '#' x 72, "\n";
                        warn '#' x 72, "\n";
                        warn "### gene $ens_gene_id was previously assigned to: $gene_fam{$ens_gene_id}\n";
                        warn "### do different transcripts of gene end up in different protein families???\n";
                        warn '#' x 72, "\n";
                        warn '#' x 72, "\n";
                     } else { 
                        $gene_fam{$ens_gene_id} = $fam_id;
                    }

                }
            } else {                    # swissprot entry
                $mem_q->execute($internal_id, $sp_dbname, $mem)
                  || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
                $mem_count++;
            }
        }                               # foreach mem
        $internal_id++;
        $fam_count++;
    }                                   # foreach fam

    $dbh->disconnect;
    warn "inserted $fam_count families, having a total of $mem_count members\n";
}                                       # main

main;
exit 0;
