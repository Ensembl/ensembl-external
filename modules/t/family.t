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
use lib '../../ensembl/modules/t';
use EnsTestDB;

$loaded = 1;
print "ok 1\n";    # 1st test passes.

$" = ", ";                          # for easier list-printing

## configuration thing. Note: EnsTestDB.conf is always read (if available); this
## hash only overrides bits and pieces of that.
my $testconf={
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
my $fam = $famadtor->fetch_by_stable_id($id);
if (defined($fam)){
    print "ok 4\n";
} else  {
    print "not ok 4\n";
    warn "didn't find family $id";
};

if ($fam->size == 15) {
    print "ok 5\n";
}
else {
    print "not ok 5\n";
}
if ($fam->size('ENSEMBLGENE') == 5) {
    print "ok 6\n";
}
else {
    print "not ok 6\n";
}

my $got = length($fam->get_alignment_string());
$expected = 1911;
if ($got == $expected) {
    print "ok 7\n";
} else  {
    print "not ok 7\n";
    warn "expected alignment length $expected, got $got\n";
}
## now same for one without an alignment; should fail gracefully
$id= 'ENSF00000000005';
eval {
    $ali=$famadtor->fetch_by_stable_id($id)->get_alignment_string();
};

if ($@ || defined($ali) ) {
    print "not ok 8\n";
    warn "got: $@ and/or $ali\n";
} else {
    print "ok 8\n";
}

if (defined($fam)){
    print "ok 9\n";
} else  {
    print "not ok 9\n";
    warn "didn't find family $id";
};

# not finding given family should fail gracefully:
$id= 'all your base are belong to us';
eval { 
    $fam = $famadtor->fetch_by_stable_id($id);
};
if ($@ || $fam) {
    print "not ok 10\n";
    warn "got: $@ and/or $fam\n";
} else  {
    print "ok 10\n";
};

@pair = ('SPTR', 'O15520');
$fam = $famadtor->fetch_by_dbname_id(@pair);
if (defined($fam)){
    print "ok 11\n";
} else  {
    print "not ok 11\n";
    warn "didn't find a family for @pair";
}
$id = 'growth factor';

@fams = $famadtor->fetch_by_description($id,1);
$expected = 5;
if (@fams == $expected) {
    print "ok 12\n";
} else {
    print "not ok 12\n";
    warn "expected $expected families, found ",int(@fams),"\n";
}

$id='fgf 21';
@fams = $famadtor->fetch_by_description($id);
$expected = 1;
if (@fams == $expected) {
    print "ok 13\n";
} else {
    print "not ok 13\n";
    warn "expected $expected families, found ",int(@fams),"\n";
}

# Test general SQL stuff:
$expected = 10;
my $q=$famadtor->prepare("select count(*) from family");
$q->execute();
my ( $row ) = $q->fetchrow_arrayref;
if ( defined($row) && int(@$row) == 1 
     && $$row[0] eq $expected) {
    print "ok 14\n";
} else { 
    print "not ok 14\n";
}


