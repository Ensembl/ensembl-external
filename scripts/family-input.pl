#!/usr/local/bin/perl
# $Id$
# parser for Anton's Families
# 
# format is like:
# Cluster Number <TAB> Family Name <TAB> Annotation Score <TAB> Protein List (Colon Separated)
#
# Run as:
#
#  family-input.pl -r 2 -E 'host=ecs1b;user=ensro;database=ensembl100;' \
#       -F 'host=ecs1b;user=root;database=fam100;' families.pep 2> fam.log
# 
#  Where families.pep is Anton's families file, remapped using pep-id-remap.pl
#
#  After this, run fam-stats.sh ecs1b ensro fam100 fam.log
#

use DBI;
use strict;

use vars qw($opt_h $opt_r $opt_C $opt_E $opt_F);

use Getopt::Std;

my $max_desc_len = 255;                 # max length of description
my $ens_pep_dbname = 'ENSEMBLPEP';      # name of EnsEMBL peptides database
my $ens_gene_dbname = 'ENSEMBLGENE';    # name of EnsEMBL peptides database
my $sp_dbname = 'SPTR';                 # name of SWISSPROT +TREMBL db
my $add_ens_pep =1;                     # should ens_peptides be added?
my $add_ens_gene =1;                    # should ens_genes be added?
my $add_swissprot =1;                   # should swissprot entries be added?

my @id_prefixes = qw(ENSP COBP PGBP);

## list of regexps tested, in order of increasing desirability, when
## deciding which family to assign a gene to in case of conflicts (used in
## compare_desc):
my @word_order = qw(UNKNOWN HYPOTHETICAL FRAGMENT CDNA);

# $fam_id_format= 'ENSF%011d'; 

my $usage = 
"Usage:\n\tfamily-input.pl [-h(elp) ] -r release [ -C tables.sql ] [ -F famdb ] [-E ensdb ]  [ FILE  ]
  famdb, ensdb: string like 'database=foo;host=bar;user=jsmith;pass=secret'
";

my $opts = 'hr:C:F:E:';

getopts($opts) || die $usage; # bugger, getopt docu is wrong, use getopts.

die $usage if $opt_h;

my $famdb_connect_string = ($opt_F || 'database=family;host=localhost;user=root');
my $ensdb_connect_string = ($opt_E || 'database=ens075;host=ecs1b;user=ensro');
#     my ($host, $user, $db) = ('ensrv5', 'ensro', 'ensembl080');
#     my ($host, $user, $db) = ('ensrv3', 'ensro', 'simon_oct07');

my $release = ($opt_r || die " need a release number\n");
my $ddl = undef;
$ddl = $opt_C;


if ($ddl) {                         # create database
    warn "creating...";
    create_db($famdb_connect_string);
}
my $famdb = db_connect($famdb_connect_string);
$famdb->{autocommit}++;
$famdb->{RaiseError}++; # so we can forget about all '|| die' s
create_tables($famdb, $ddl) if $ddl;

my $ensdb = db_connect($ensdb_connect_string);
$ensdb->{RaiseError}++;

warn "loading families";
&load_families($famdb, $ensdb);
warn "doing statistics tables\n";
&do_stats($famdb);
warn "done with statistics\n";
$famdb->disconnect;
$ensdb->disconnect;
exit 0;

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
}                                       # create_db

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
    foreach my $s (grep /\S/, split /;\s*\n/, $sql) {
        $dbh->do($s);
    }
}                                       # create_tables
 
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
}                                       # get_max_id


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
}                                       # db_connect

# find peptide or gene back in ensembl
sub ens_find {
    my ($q, $pepid) = @_;
    $q->execute($pepid);

    my $rowhash;
    my @results;
    while ( $rowhash = $q->fetchrow_hashref) {
        push @results, $rowhash->{id};
    }

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
}                                       # ens_find

sub delete_prev_assign {
    my ($q) = @_; 
    $q->execute($q);
}                                       # delete_prev_assign

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

sub fill_in_member_count {
## add the numbers of enspep members (==family_size) per family into
## family. Returns total number of enspepts.
    my ($dbh) = @_;

    my $q = "SELECT family as famid, COUNT(*) as n
          FROM family_members 
          WHERE db_name = '$ens_pep_dbname'
          GROUP BY famid";
    $q = $dbh->prepare($q);
    $q->execute;

    my $u = "UPDATE family SET num_ens_pepts = ? WHERE internal_id = ?";
    $u = $dbh->prepare($u);

    my $tot_n=0;
 
    while ( my @row = $q->fetchrow ) {
        my ($famid, $n) = @row;
        $tot_n += $n;
        $u->execute($n, $famid);
    }
    return $tot_n;
}                                       # fill_in_member_count


## 
sub do_stats { 
    my ($dbh) = @_;

    my $totn_enspepts = fill_in_member_count($dbh);

    ### temporary histogram (family_size, occurrences) for the
    ### distribution:
    my $distr_table= "tmp_distr_enspep_$$";

    ## note: we can't use a CREATE TEMPORARY TABLE here, since MySQL
    ## doesn't allow self-joins on tmp tables ...
    my $q = "CREATE TABLE $distr_table
             SELECT num_ens_pepts as n, COUNT(id) as cnt
             FROM  family
             GROUP BY n";
    $dbh->do($q);
    $q = "ALTER TABLE $distr_table ADD INDEX idx_$distr_table (n)";
    $dbh->do($q);

    ## find the fractional cumulative distribution ('running totals') of
    ## this (i.e., the fraction of ensembl peptides in clusters of size N
    ## and smaller). This uses a nifty SQL construct called a theta
    ## self-join. We know the total number of members, so we can divide by
    ## it straight away
    $q = "INSERT INTO cumulative_distrib
          SELECT d1.n, d1.cnt, (SUM(d2.cnt*d2.n))/$totn_enspepts
          FROM $distr_table d1, $distr_table d2
          WHERE d1.n >= d2.n
          GROUP by d1.n, d1.cnt";
    $dbh->do($q);

    $q = "DROP TABLE $distr_table"; 
    $dbh->do($q);
}                                       # do_stats

sub load_families {
    my ($famdb, $ensdb)=@_;
    # god this function is hairy
    warn "checking for all id with prefixes " , join(' ', @id_prefixes), "\n";
    my $fam_count = 0;
    my $mem_count =0;

    my $internal_id;


    $internal_id = get_max_id($famdb) +1;
### queries:
    my $fam_q = 
      "INSERT INTO family(internal_id, id, description, release, 
                         annotation_confidence_score)
       VALUES(?,            ?,         ?,        ?,        ?)\n";
###            $internal_id, '$fam_id', '$descr', $release, $score);

    $fam_q = $famdb->prepare($fam_q);

    my $mem_q = 
      "INSERT INTO family_members(family, db_name, db_id)
                           VALUES(?,      ?,       ?)\n";
###                         $internal_id, '$db_name', '$mem'

    $mem_q = $famdb->prepare($mem_q);

    # to check for existence
    my $pep_q = "SELECT id from translation where id = ?";
    $pep_q = $ensdb->prepare($pep_q);

    my $gene_q = 
      "SELECT g.id 
       FROM gene g, translation tl, transcript tc 
       WHERE tl.id = ? 
           AND tl.id = tc.translation and tc.gene = g.id";

    $gene_q = $ensdb->prepare($gene_q);

    my $del_q = 
      "DELETE FROM family_members
       WHERE db_name = '$ens_gene_dbname'
         AND db_id = ?";
    $del_q = $famdb->prepare($del_q);
### end of queries

    my %gene_fam = undef;
    my %fam_desc = undef;
    my %fam_score = undef;

#    $famdb->{RaiseError}=0; doesn't work !?!$?!@~@
#    $ensdb->{RaiseError}=0;

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

        $fam_score{$fam_id} = $score;
        $fam_desc{$fam_id} = $desc;
        
        # my $fam_id = format_fam_id $num; now in file.
        
        $fam_q->execute($internal_id, $fam_id, $desc, $release, $score);

        my %seen_gene = undef;          # just for filtering transcripts

      MEM:
        foreach my $mem (@mems) {
            if ( grep $mem =~ /^$_/,@id_prefixes ) {
                
                if ($add_ens_pep)  {
                    $mem_q->execute("$internal_id", $ens_pep_dbname, $mem);
                    $mem_count++;
                }
                
                if ($add_ens_gene) {
                    # find the peptide back:
                    if ( ens_find($pep_q, $mem) eq '' ) {
                        warn "couldn't find peptide $mem - database mismatch? Can't find gene, continuing\n";
                        next MEM;
                    }

                    #find ENSGxxx, given ENSPxxx:
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

                        ## we have a conflict: a previous peptide of the
                        ## same gene was already 'assigned' to a family,
                        ## but now a different transcript of the same gene
                        ## is about to be assigned to a different family:
                        warn "### assigning gene $ens_gene_id (peptide: $mem) to $fam_id; already assigned to: $gene_fam{$ens_gene_id}\n";
                        
                        my $prev_fam = $gene_fam{$ens_gene_id};
                        my $prev_score = $fam_score{$prev_fam};
                        my $prev_desc = $fam_desc{$prev_fam};

                        if (   ($score < $prev_score)
                            || (($score == $prev_score) && compare_desc($prev_desc, $desc) >= 0)) {
                            warn "### leaving as is; score: $prev_score; desc: $prev_desc\n";
                            warn "### alternative would be: score $score; desc: $desc\n" 
                               unless $desc eq $prev_desc;
                            warn "\n";
                            next MEM;
                        }

                        # new one is better; delete old one
                        warn "### replacing previous $prev_fam, score: $prev_score; desc: $prev_desc\n";
                        warn "### with $fam_id, score: $score; desc: $desc\n\n";
                        $del_q->execute($ens_gene_id);
                    }
                    $gene_fam{$ens_gene_id} = $fam_id;
                    $seen_gene{$ens_gene_id}=$mem;
                    
                    # if this fails, we have duplicate ensembl gene
                    $mem_q->execute($internal_id, $ens_gene_dbname, 
                                    $ens_gene_id);
                    $mem_count++;
                }                       # if add_ens_gene
            } else {                    # this must be a swissprot
                if ($add_swissprot) { 
                    # if this fails, we have duplicate swissprot pept
                    $mem_q->execute($internal_id, $sp_dbname, $mem);
                    $mem_count++;
                }
            }
        }                               # foreach mem
        $internal_id++;
        $fam_count++;
    }                                   # foreach fam
    warn "inserted $fam_count families, having a total of $mem_count members\n";
}                                       # load_families
