#!/usr/local/bin/perl
# $Id$
# parser for Anton's Families
# 
# format is like:
# Cluster Number <TAB> Family Name <TAB> Annotation Score <TAB> Protein List (Colon Separated)

use DBI;
use strict;

use vars qw($opt_h $opt_r $opt_C $opt_E $opt_F);

use Getopt::Std;

my $max_desc_len = 255;                    # max length of description
my $ens_pep_dbname = 'ENSEMBLPEP';          # name of EnsEMBL peptides database
my $ens_gene_dbname = 'ENSEMBLGENE';        # name of EnsEMBL peptides database
my $sp_dbname = 'SWISSPROT';               # name of SWISSPROT database
my $add_ens_pep =1;                     # should ens_peptides be added?
my $add_ens_gene =1;                    # should ens_genes be added?
my $add_swissprot =1;                   # should swissprot entries be added?

## list of regexps tested, in order of increasing desirability, when
## deciding which family to assign a gene to in case of conflicts (used in
## compare_desc):
my @word_order = qw(UNKNOWN HYPOTHETICAL FRAGMENT CDNA);

# $fam_id_format= 'ENSF%011d'; 

my $usage = 
"Usage:\n\tfamily-parse.pl [-h(elp) ] -r release [ -C ] [ -F famdb ] [-E ensdb ]  [ FILE  ]
  famdb, ensdb: string like 'database=foo;host=bar;user=jsmith;pass=secret'
";

my $opts = 'hr:CF:E:';
getopts($opts) || die $usage; # bugger, getopt docu is wrong, use getopts.

die $usage if $opt_h;

my $famdb_connect_string = ($opt_F || 'database=family;host=localhost;user=root');
my $ensdb_connect_string = ($opt_E || 'database=ens075;host=ecs1b;user=ensro');
#     my ($host, $user, $db) = ('ensrv3', 'ensro', 'simon_oct07');

my $release = ($opt_r || die " need a release number\n");
my $ddl = undef;
$ddl = '../sql/family.sql' if $opt_C;

# just creates empty database, returns nothing.
sub create_db {
    my ($conn) = @_;

    my ($database) = ($conn =~ /database=([^;]+);/);
    # connect to database 'mysql' instead, since $database doesn't exist yet
    $conn =~ s/database=[^;]+;/database=mysql;/;

    $conn = db_connect($conn);
    
    $conn->do("CREATE DATABASE $database");
    warn "problem creating database: " . $DBI::errstr if $DBI::err;
    $conn->disconnect;
    undef;
}

sub create_tables { 
    my ($dbh, $ddl) = @_;

## taken from EnsTestDB:
    open SQL, $ddl or die "Can't read SQL file '$ddl' : $!";
    my $sql='';
    while (<SQL>) {
        s/(#|--).*//;       # Remove comments
        next unless /\S/;   # Skip lines which are all space
        $sql .= $_;
        $sql .= ' ';
    }
    close SQL;
    #Modified split statement, only semicolumns before end of line,
    #so we can have them inside a string in the statement
    foreach my $s (grep /\S/, split /;\n/, $sql) {
        $dbh->do($s) || die $DBI::errstr;
    }
    undef;
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


## slightly more general function, which takes string that looks like
## "database=foo;host=bar;user=jsmith;passwd=secret", connects to mysql
## and return the handle
sub db_connect { 
    my ($dbcs) = @_;

    my %keyvals= split('[=;]', $dbcs);
    my $user=$keyvals{'user'};
    my $paw=$keyvals{'password'};
#    $dbcs =~ s/user=[^;]+;?//g;
#    $dbcs =~ s/password=[^;]+;?//g;
# (mysql doesn't seem to mind the extra user/passwd values, leave them)

    my $dsn = "DBI:mysql:$dbcs";

    my $dbh=DBI->connect($dsn, $user, $paw) ||
      die "couldn't connect using dsn $dsn, user $user, password $paw:" 
         . $DBI::errstr;
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
    my $famdb;

    my $internal_id;

    if ($ddl) {                         # create database
        warn "creating...";
        create_db($famdb_connect_string);
    }

    $famdb = db_connect($famdb_connect_string);
                                        # create tables
    if ($ddl) { 
        create_tables($famdb, $ddl);
    }

    $famdb->{autocommit}++;


    # separate handle for looking up translation from ens_pep to ens_gene:
    my $ensdb = db_connect($ensdb_connect_string);

    $internal_id = get_max_id($famdb) +1;
### queries:
    my $fam_q = 
      "INSERT INTO family(internal_id, id, description, release, 
                         annotation_confidence_score)
       VALUES(?,            ?,         ?,        ?,        ?)\n";
###            $internal_id, '$fam_id', '$descr', $release, $score);

    $fam_q = $famdb->prepare($fam_q) || die $famdb->errstr;

    my $mem_q = 
      "INSERT INTO family_members(family, db_name, db_id)
                           VALUES(?,      ?,       ?)\n";
###                         $internal_id, '$db_name', '$mem'

    $mem_q = $famdb->prepare($mem_q) || die $famdb->errstr;

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
    $del_q = $famdb->prepare($del_q) || die $famdb->errstr;
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

    $famdb->disconnect;
    $ensdb->disconnect;
    warn "inserted $fam_count families, having a total of $mem_count members\n";
}                                       # main

main;
exit 0;
