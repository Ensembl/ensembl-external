# $Id$

# testing of family database.

## We start with some black magic to print on failure.
BEGIN { $| = 1; print "1..13\n";
	use vars qw($loaded); }

END {print "not ok 1\n" unless $loaded;}

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;
## use Bio::EnsEMBL::DBLoader;
use lib 't';
use EnsTestDB;

$loaded = 1;
print "ok 1\n";    # 1st test passes.

$" = ", ";                          # for easier list-printing

## configuration thing. Note: EnsTestDB.conf is always read (if available); this
## hash only overrides bits and pieces of that.
my $testconf={
    'driver'        => 'mysql',
    'host'          => 'ecs1a',
    'user'          => 'ensadmin',
    'port'          => '3306',
    'pass'      => 'ensembl',
    'schema_sql'    => ['../sql/family.sql'],
    'module'        => 'Bio::EnsEMBL::DBSQL::DBAdaptor'
};
    
my $testdb = EnsTestDB->new($testconf);

# Load some data into the db

$testdb->do_sql_file("t/family.dump");
# $testdb->pause;

my $db = $testdb->get_DBSQL_Obj;

my $famadtor = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($db);
print "ok 2\n";    

@expected = qw(ENSEMBLPEP ENSEMBLGENE SPTR);

%dbs=undef;
foreach my $ex (@expected) {
    $dbs{$ex}++;
}

@found = $famadtor->known_databases;
foreach my $f (@found) {
    $dbs{$f}--;
}
$"=' ';

if ( grep($_ != 0, values %dbs)) {
    print "not ok 3\n";
    warn "expected " , sort @expected, ", found ", sort @found, "\n";
} else {print "ok 3\n";};


$id= 'ENSF00000000002';
my $fam = $famadtor->get_Family_by_id($id);
if (defined($fam)){
    print "ok 4\n";
} else  {
    print "not ok 4\n";
    warn "didn't find family $id";
};

my $got = length($fam->get_alignment_string());
$expected = 1911;
if ($got == $expected) {
    print "ok 5\n";
} else  {
    print "not ok 5\n";
    warn "expected alignment length $expected, got $got\n";
}
## now same for one without an alignment; should fail gracefully
$id= 'ENSF00000000005';
eval {
    $ali=$famadtor->get_Family_by_id($id)->get_alignment_string();
};

if ($@ || defined($ali) ) {
    print "not ok 6\n";
    warn "got: $@ and/or $ali\n";
} else {
    print "ok 6\n";
}

if (defined($fam)){
    print "ok 7\n";
} else  {
    print "not ok 7\n";
    warn "didn't find family $id";
};

# not finding given family should fail gracefully:
$id= 'all your base are belong to us';
eval { 
    $fam = $famadtor->get_Family_by_id($id);
};
if ($@ || $fam) {
    print "not ok 8\n";
    warn "got: $@ and/or $fam\n";
} else  {
    print "ok 8\n";
};




$id='ENSP00000231624';
$fam = $famadtor->get_Family_of_Ensembl_pep_id($id);
if (defined($fam)) {
    print "ok 9\n";
} else  {
    print "not ok 9\n";
    warn "didn't find pepid $id\n";
}

$id='ENSG000001067592';
$fam = $famadtor->get_Family_of_Ensembl_gene_id($id);
if (defined($fam)){
    print "ok 10\n";
} else  {
    print "not ok 10\n";
    warn "didn't find family of gene id $id\n";
}

@pair = ('SPTR', 'O15520');
$fam = $famadtor->get_Family_of_db_id(@pair);
if (defined($fam)){
    print "ok 11\n";
} else  {
    print "not ok 11\n";
    warn "didn't find a family for @pair";
}
$id = 'growth factor';

@fams = $famadtor->get_Families_described_as($id);
$expected = 5;
if (@fams == $expected) {
    print "ok 12\n";
} else {
    print "not ok 12\n";
    warn "expected $expected families, found ",int(@fams),"\n";
}

# Test general SQL stuff:
$expected = 10;
my $q=$famadtor->prepare("select count(*) from family");
$q->execute();
my ( $row ) = $q->fetchrow_arrayref;
if ( defined($row) && int(@$row) == 1 
     && $$row[0] eq $expected) {
    print "ok 13\n";
} else { 
    print "not ok 13\n";
}


