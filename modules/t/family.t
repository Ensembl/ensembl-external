# $Id$

# testing of family database.

## We start with some black magic to print on failure.
BEGIN { $| = 1; print "1..8\n";
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

my $testconf={
    'driver'        => 'mysql',
    'host'          => 'localhost',
    'user'          => 'root',
    'port'          => '3306',
    'password'      => undef,
    'schema_sql'    => ['../sql/family.sql'],
    'module'        => 'Bio::EnsEMBL::DBSQL::DBAdaptor'
};
    
my $testdb = EnsTestDB->new($testconf);

# Load some data into the db
$testdb->do_sql_file("t/family.dump");
# $testdb->pause;

my $ens_adtor =  $testdb->get_DBSQL_Obj;
my $famadtor = $ens_adtor->get_FamilyAdaptor;
### alternatively:
###   Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor($testdb); 
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

$id= 'ENSF00000000005';
my $fam = $famadtor->get_Family_by_id($id);
if (defined($fam)){
    print "ok 4\n";
} else  {
    print "not ok 4\n";
    warn "didn't find family $id";
};

$id='ENSP00000231624';
$fam = $famadtor->get_Family_of_Ensembl_pep_id($id);
if (defined($fam)) {
    print "ok 5\n";
} else  {
    print "not ok 5\n";
    warn "didn't find pepid $id\n";
}

$id='ENSG000001067592';
$fam = $famadtor->get_Family_of_Ensembl_gene_id($id);
if (defined($fam)){
    print "ok 6\n";
} else  {
    print "not ok 6\n";
    warn "didn't find family of gene id $id\n";
}

@pair = ('SPTR', 'O15520');
$fam = $famadtor->get_Family_of_db_id(@pair);
if (defined($fam)){
    print "ok 7\n";
} else  {
    print "not ok 7\n";
    warn "didn't find a family for @pair";
}
$id = 'growth factor';

@fams = $famadtor->get_Families_described_as($id);
$expected = 5;
if (@fams == $expected) {
    print "ok 8\n";
} else {
    print "not ok 8\n";
    warn "expected $expected families, found ",int(@fams),"\n";
}
