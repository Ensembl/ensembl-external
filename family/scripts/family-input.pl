#!/usr/local/bin/perl
# $Id$
#
# script to input output from assemble-consensus.pl into a proper family
# database.
#
# Run as:
#
# family-input.pl -r 2 -F 'host=ecs1b;user=root;database=fam100;'  -E  \
#   'DBCONNECTION[,DBCONNECTION...]'  families.pep 2> fam.log
# 
# where DBCONNECTION is a string like
# 'host=ecs1b;user=root;database=fam100;' 
# 
# and families.pep a file as output by assemble-consensus.pl (and possibly
# remapped using e.g. univeral-id-mapper.pl)
#
#### Note: we rely on ensemblid's matching /^[A-Z]{3}[PG]0\d{10}/ ! (or
#### something else ...)

#
#
#  After this, run fam-stats.sh ecs1b ensro fam100 fam.log
#

warn "**** WARNING: hacks ahead ... relying on translation id's matching 'COBP'";
# die "actually, don't use it for now ... ";

use DBI;
use strict;

use vars qw($opt_h $opt_r $opt_C $opt_E $opt_F);

use Getopt::Std;

my $max_desc_len = 255;                 # max length of description

# my $ensid_regexp = '^([A-Z]{3})([PG])(0\d{10})$'; # '; # fool emacs
my $ensid_regexp = '^(COB)([PG])(\d+)$';   # '; #fool emacs
warn "\$ensid_regexp = $ensid_regexp !!! ";

my $sp_dbname = 'SPTR';                 # name of SWISSPROT +TREMBL db

my $add_ens_pep =1;                     # should ens_peptides be added?
my $add_ens_gene =1;                    # should ens_genes be added?
my $add_other =1;                       # should swissprot (or others)
                                        # be added?

# my @id_prefixes = qw(ENSP COBP PGBP);

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

my $famdb_connect_string = ($opt_F || 'database=family110;host=ensrv3;user=ensadmin');
my $ensdb_connect_string = ($opt_E || 'database=homo_sapiens_core_110;host=ensr3;user=ensro');
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
$famdb->{AutoCommit}++;
$famdb->{RaiseError}++; # so we can forget about all '|| die' s
create_tables($famdb, $ddl) if $ddl;

my @ensdbs = &setup_aux_dbs($ensdb_connect_string);
die "no auxiliary db's defined, need at least one" unless @ensdbs;

### we now have to deal with two or more database connections. Make a
### little 'object' that has the handle and the two cursors.
### Note: we rely on ensemblid's matching /^[A-Z]{3}[PG]0\d$/ !
sub setup_aux_dbs {
    my ($connectstring)=@_;
    my (@dbs);
    foreach my $c ( split(',', $connectstring ) ) {
        my $db = {};
        my $dbhandle = db_connect($c);
        $dbhandle->{RaiseError}++;
        $db->{'connect'}=$c;            # for debugging
        $db->{'db'}=$dbhandle;
        
        # query that checks for existence
        my $pep_q = "SELECT translation_id from translation where translation_id = ?";
        $db->{'peptide_query'}= $pep_q; # for debugging
        $db->{'peptide_cursor'}=$dbhandle->prepare($pep_q);
        
        # query that finds gene of a peptide
        my $gene_q = 
          "SELECT g.gene_id 
       FROM gene g, translation tl, transcript tc 
       WHERE tl.translation_id = ? 
           AND tl.translation_id = tc.translation_id and tc.gene_id = g.gene_id";
        $db->{'gene_query'}= $gene_q;
        $db->{'gene_cursor'}= $dbhandle->prepare($gene_q);
        push(@dbs, $db);
    }
    @dbs;
}                                       # setup_aux_dbs

warn "loading families";
&load_families($famdb, @ensdbs);
warn "doing statistics tables\n";
&do_stats($famdb);
warn "done with statistics\n";
$famdb->disconnect;

foreach my $db  ( @ensdbs) {
    $db->disconnect;
}
exit 0;

# just creates empty database, returns nothing.
sub create_db {
    my ($conn) = @_;
    $conn = "$conn;" unless $conn =~ /;$/;

    my ($database) = ($conn =~ /database=([^;]+);/g);
    # connect to database 'mysql' instead, since $database doesn't exist yet
    $conn =~ s/database=[^;]+;/database=mysql;/g;

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

# find peptide or gene back in a list of ensembl auxdb's
# this function tried to be clever, but ended up being  muddled
sub ens_find {
    my ($pepid, $cursor_key, @dbs) = @_;
    my @results;

    foreach my $db (@dbs) { 
        my $q = $db->{$cursor_key};     # 'peptide_cursor' or 'gene_cursor'
        my $id_field=undef;
        if ($cursor_key eq 'peptide_cursor') {
            $id_field = 'translation_id';
        } elsif ( $cursor_key eq 'gene_cursor') {
            $id_field = 'gene_id';
        } else {
            die "bug: don't now id_field for cursor_key $cursor_key";
        }

        $q->execute($pepid);

        my $rowhash;
        while ( $rowhash = $q->fetchrow_hashref) {
            push @results, $rowhash->{$id_field};
        }
    }
    if (@results != 1) {
        if (@results){
            warn "for $pepid, I got: " 
              . join(':', @results), "\n"; 
            die "expected exactly one";
        }                          
    }
    $results[0];                        # may still be empty ? 
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
## add the numbers of ens_pep members (==family_size) per family into
## family. Returns total number of enspepts.
    my ($dbh, $dbname) = @_;

    my $q = "SELECT family as famid, COUNT(*) as n
          FROM family_members 
          WHERE db_name like '___P'
          GROUP BY famid";
    $q = $dbh->prepare($q);
    $q->execute || die;

    my $u = "UPDATE family SET num_ens_pepts = ? WHERE internal_id = ?";
    $u = $dbh->prepare($u);

    my $tot_n=0;
    while ( my @row = $q->fetchrow_array   ) {
# warn @row;
        my ($famid, $n) = @row;
        $tot_n += $n;
        $u->execute($n, $famid);
    }
    return $tot_n;
}                                       # fill_in_member_count


## 
sub do_stats { 
    my ($dbh) = @_;

    warn "filling in member counts ...\n";
    my $totn_enspepts = fill_in_member_count($dbh);
    ### note: these are the number of EnsEMBL members only, not
    ### totals.
    
    ### temporary histogram (family_size, occurrences) for the
    ### distribution:
    my $distr_table= "tmp_distr_enspep_$$";

    warn "doing histogram ...\n";
    ## note: we can't use a CREATE TEMPORARY TABLE here, since MySQL
    ## doesn't allow self-joins on tmp tables ...
    my $q = "CREATE TABLE $distr_table
             SELECT num_ens_pepts as n, COUNT(id) as cnt
             FROM  family
             GROUP BY n";
    $dbh->do($q);

    $q = "ALTER TABLE $distr_table ADD INDEX idx_$distr_table (n)";
    $dbh->do($q);


    warn "doing (cumulative) distribution ...\n";
    ## find the fractional cumulative distribution ('running totals') of
    ## this (i.e., the fraction of ENSEMBL peptides in clusters of size N
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
    my ($famdb, @ensdbs)=@_;
    # god this function is hairy

#     warn "checking for all id with prefixes " , join(' ', @id_prefixes),
#     "\n";

    my $fam_count = 0;
    my $mem_count =0;

    my $internal_id;


    $internal_id = get_max_id($famdb) +1;
### queries:
    my $addfam_q = 
      "INSERT INTO family(internal_id, id, description, release, 
                         annotation_confidence_score)
       VALUES(?,            ?,         ?,        ?,        ?)\n";
###            $internal_id, '$fam_id', '$descr', $release, $score);

    $addfam_q = $famdb->prepare($addfam_q);

    my $addmem_q = 
      "INSERT INTO family_members(family, db_name, db_id)
                           VALUES(?,      ?,       ?)\n";
###                         $internal_id, '$db_name', '$mem'

    $addmem_q = $famdb->prepare($addmem_q);

    my $del_q = 
      "DELETE FROM family_members
       WHERE db_id = ?";                
#        AND db_name = '$ens_gene_dbname' : forgetting this, should be uniq.
    $del_q = $famdb->prepare($del_q);
### end of queries

    my %gene_fam = undef;
    my %fam_desc = undef;
    my %fam_score = undef;

#    $famdb->{RaiseError}=0; doesn't work !?!$?!@~@
#    $ensdb->{RaiseError}=0;

    my %seen_pept = undef;              # for ignoring (rare) duplicates
                                        # in the original clustering

# format is like:
# Cluster Number <TAB> Family Name <TAB> Annotation Score <TAB> Protein List (Colon Separated)
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
        
        $addfam_q->execute($internal_id, $fam_id, $desc, $release, $score);
        my %seen_gene = undef;          # just for filtering transcripts

      MEM:
        foreach my $mem (@mems) {
            my ($db, $type, $rest)  = ($mem =~ /$ensid_regexp/ );
            my $pep_dbname = "$db$type"; # e.g. ENSP
            if ( $db && $type && $rest ) {                # we have an ENS pep

                my $mem_internal_id = $mem; $mem_internal_id =~ s/^COBP//g;
                
                if ( defined $seen_pept{$mem} ) {
                    warn "### already seen peptide $mem; at line $seen_pept{$mem}; ignoring it now\n";
                    next MEM;
                }
                $seen_pept{$mem} = $.;  # where we (last) saw  it
                
                if ($add_ens_pep)  {
                    $addmem_q->execute("$internal_id", $pep_dbname, $mem);
                    $mem_count++;
                }
                
                if ($add_ens_gene) {
                    # find the peptide back, to see if it's there
                    if ( ens_find($mem_internal_id, 
                                  'peptide_cursor', @ensdbs) eq '' ) {
                        warn "couldn't find peptide $mem_internal_id - database mismatch? Can't find peptide, continuing\n";
                        next MEM;
                    }

                    # it is there, now find ENSGxxx, given ENSPxxx:
                    my $gene_id = ens_find($mem_internal_id, 'gene_cursor', @ensdbs);
                    # This is an ensembl internal_id! 

                    if ( ! $gene_id ) {
                        warn "### did not find gene of $mem; continuing\n";
                        next MEM;
                    } 
                    
                    if ( defined $seen_gene{$gene_id}) {
                        # different transcripts into same family; OK
                        next MEM;
                    }

                    my ($db2, $type2)  = ($gene_id =~ /$ensid_regexp/ );
                    my $gene_dbname = "$db2$type2";

                    ### check to see if this gene was previously assigned
                    ### to another family; if so, try to correct
                    if ( defined( $gene_fam{$gene_id} )
                         &&       $gene_fam{$gene_id} ne $fam_id ) {

                        ## we have a conflict: a previous peptide of the
                        ## same gene was already 'assigned' to a family,
                        ## but now a different transcript of the same gene
                        ## is about to be assigned to a different family:
                        warn "### assigning gene $gene_id (peptide: $mem) to $fam_id; already assigned to: $gene_fam{$gene_id}\n";
                        
                        my $prev_fam = $gene_fam{$gene_id};
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
                        $del_q->execute("COBG$gene_id");
                    }
                    $gene_fam{$gene_id} = $fam_id;
                    $seen_gene{$gene_id}=$mem;
                    
                    # if this fails, we have duplicate ensembl gene
                    $addmem_q->execute($internal_id, $gene_dbname, 
                                       "COBG$gene_id"); # hack! 
                    $mem_count++;
                }                       # if add_ens_gene
            } else {                    # this must be a swissprot id
                if ($add_other) { 
                    my $dbname;         # which database name to use?
                    if ( $mem =~ /^ENSMUSP/ ) { 
                        $dbname = 'ENSMUSPEP'; # Boo! Hiss! Hardcoded
                                               # stuff here ...
                    } elsif ( $mem =~ /^ENSMUSG/ ) { # (not there yet)
                        $dbname = 'ENSMUSGENE'; # likewise
                    } else {
                        $dbname = $sp_dbname;
                    }
                    $addmem_q->execute($internal_id, $dbname, $mem);
                    # (if this failed, we have a duplicate swissprot peptide)
                    $mem_count++;
                }
            }
        }                               # foreach mem
        $internal_id++;
        $fam_count++;
    }                                   # foreach fam
    warn "inserted $fam_count families, having a total of $mem_count members\n";
}                                       # load_families
