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
            $ens_pep_dbname $ens_gene_dbname $sp_dbname
            @word_order);

use Getopt::Std;

$max_desc_len = 255;                    # max length of description
$ens_pep_dbname = 'ENSEMBLPEP';          # name of EnsEMBL peptides database
$ens_gene_dbname = 'ENSEMBLGENE';        # name of EnsEMBL peptides database
$sp_dbname = 'SWISSPROT';               # name of SWISSPROT database
my $add_ens_pep =1;                     # should ens_peptides be added?
my $add_ens_gene =1;                    # should ens_genes be added?
my $add_swissprot =1;                   # should swissprot entries be added?

## list of regexps tested, in order of increasing desirability, when
## deciding which family to assign a gene to in case of conflicts (used in
## compare_desc):
@word_order = qw(UNKNOWN HYPOTHETICAL FRAGMENT CDNA);

# $fam_id_format= 'ENSF%011d'; 

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

sub open_ensembl { 
warn "using hardcoded host, db and user here";
#     my ($host, $user, $db) = ('ensrv3', 'ensro', 'simon_oct07');
     my ($host, $user, $db) = ('ecs1b', 'ensro', 'ens075');
#     my ($host, $user, $db) = ('ecs1b', 'ensro', 'arne_ensembl_main');

    my $dbh=DBI->connect("DBI:mysql:database=$db;host=$host", $user) ||
      die "couldn't connect to $db at $host as $user:" . $DBI::errstr;
    $dbh;
}

# find peptide or gene back in ensembl
sub ens_find {
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
            warn "for $pepid, I got: " 
              . join(':', @results), "\n"; 
            die "expected exactly one";
        } else {
            # warn "for $pepid, I got no genes\n";
            # die "not exactly one gene"; # ignore for now
        }
    }
    my $id =     $results[0];
    $id;
}

sub delete_prev_assign {
    my ($q) = @_; 
    $q->execute($q);
    die $q->errstr if $q->err;
}

# return -1 if description a worse than b, 0 if equal, 1 if better
# (this function could be used in a sort(compare_desc, @descriptions)
sub compare_desc {
    my ($a, $b) = @_; 

    my ($am, $bm);
    foreach my $w (@word_order) {
        $am = ($a =~ /$w/)?1:0;
        $bm = ($b =~ /$w/)?1:0;

        if ($am  != $bm ) {             # ie, one matches, other doesn't
            if ( $am == 1 ) {           # first one worse than second 
                return -1;
            } else { 
                return 1; 
            }
        }
    }
    # still look same; base result on length: longer is better
    return length($a) <=> length($b);
}                                       # compare_desc

sub main {
    # god this function is hairy
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


    # separate handle for looking up translation from ens_pep to ens_gene:
    my $ensdb = open_ensembl();

    $internal_id = get_max_id($dbh) +1;
### queries:
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

    # to check for existence
    my $pep_q = "SELECT id from translation where id = ?";
    $pep_q = $ensdb->prepare($pep_q) || die $ensdb->errstr;

    my $gene_q = 
      "SELECT g.id 
       FROM gene g, translation tl, transcript tc 
       WHERE tl.id = ? 
           AND tl.id = tc.translation and tc.gene = g.id";

    $gene_q = $ensdb->prepare($gene_q) || die $ensdb->errstr;

    my $del_q = 
      "DELETE FROM family_members
       WHERE db_name = '$ens_gene_dbname'
         AND db_id = ?";
    $del_q = $dbh->prepare($del_q) || die $dbh->errstr;
### end of queries

    my %gene_fam = undef;
    my %fam_desc = undef;

    while(<>) {
        next if /^#/;
        chomp;
        my ($fam_id, $desc, $score, $mems, $dummy, $mems2)= split '\t';

        ### work around bug in format:
        if ( $mems !~ /^:/) {
            my $s = "$mems $dummy $mems2";
            ($mems) = ( $s =~ /(:.*)$/);
        }

        my @mems = split(':', $mems);
        shift @mems;                    # superfluous ':' at start.

        die "didn't find members for family $fam_id, line $.:\n$_\n" if (@mems < 1);

        if (length($desc) > $max_desc_len) {
            warn "Description longer than $max_desc_len; truncating it\n";
            $desc = substr($desc, 0, $max_desc_len);
        }
        
        $fam_desc{$fam_id} = $desc;
        
        # my $fam_id = format_fam_id $num; now in file.
        
        $fam_q->execute($internal_id, $fam_id, $desc, $release, $score)
          || die "couldn't insert line $.:\n$_\n " . $fam_q->errstr;

        my %seen_gene = undef;          # just for filtering transcripts
      MEM:
        foreach my $mem (@mems) {
            if ($mem =~ /^ENSP/ || $mem =~ /^COBP/ ) {
                
                if ($add_ens_pep)  {
                    $mem_q->execute($internal_id, $ens_pep_dbname, $mem)
                      || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
                    $mem_count++;
                }
                
                if ($add_ens_gene) {
                    if ( ens_find($pep_q, $mem) eq '' ) {
                        warn "couldn't find peptide $mem - database mismatch? Can't find gene, continuing\n";
                        next MEM;
                    }
                    
                    my $ens_gene_id = ens_find($gene_q, $mem);
                    
                    if ( ! $ens_gene_id ) {
                        warn "### did not find gene of $mem; continuing\n";
                        next MEM;
                    } 
                    
                    if ( defined $seen_gene{$ens_gene_id}) {
                        # different transcripts into same family; OK
                        next MEM;
                    }

                    ### check to see if this gene was previously assigned
                    ### to another family; if so, try to correct
                    if ( defined( $gene_fam{$ens_gene_id} )
                         &&       $gene_fam{$ens_gene_id} ne $fam_id ) {
                        warn "### assigning gene $ens_gene_id (peptide: $mem) to $fam_id; already assigned to: $gene_fam{$ens_gene_id}\n";
                        
                        my $prev_fam = $gene_fam{$ens_gene_id};
                        my $prev_desc = $fam_desc{$prev_fam};
                        
                        # see if new description is better than previous:
                        my $cmp = compare_desc($prev_desc, $desc);
                        if ( $cmp >= 0 ) { # not really better
                            warn "### leaving as is; desc: $prev_desc\n";
                            warn "### alternative would be: $desc\n" 
                               unless $desc eq $prev_desc;
                            warn "\n";
                            next MEM;
                        }
                        # new one is better; delete old one
                        warn "### replacing previous $prev_fam, desc: $prev_desc\n";
                        warn "### with $fam_id, desc: $desc\n\n";
                        $del_q->execute($ens_gene_id);
                        die $del_q->errstr if $del_q->err;
                    }
                    $gene_fam{$ens_gene_id} = $fam_id;
                    $seen_gene{$ens_gene_id}=$mem;
                    
                    $mem_q->execute($internal_id, $ens_gene_dbname, 
                                    $ens_gene_id)
                      || die "couldn't insert line $.:\n$_\n " 
                        . $mem_q->errstr;
                    $mem_count++;
                }                       # if add_ens_gene
            } else {                    # this must be swissprot
                if ($add_swissprot) { 
                    $mem_q->execute($internal_id, $sp_dbname, $mem)
                      || die "couldn't insert line $.:\n$_\n " . $mem_q->errstr;
                    $mem_count++;
                }
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
