# $Id$

# testing of family database.

## We start with some black magic to print on failure.
use strict;
BEGIN {
    eval { require Test; };
    if( $@ ) { 
	use lib 't';
    }
    use Test;
    use vars qw($NTESTS);
    $NTESTS = 15;
    plan tests => $NTESTS;
}




#BEGIN { $| = 1; print "1..13\n";
#	use vars qw($loaded); }

#END {print "not ok 1\n" unless $loaded;}

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;
use lib '../../ensembl/modules/t';
use EnsTestDB;

END {     
    for ( $Test::ntest..$NTESTS ) {
	skip("Could not get past module loading, skipping test",1);
    }
}
ok(1);

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
ok(1);

my @expected = qw(ENSEMBLPEP ENSEMBLGENE SPTR);

my %dbs=undef;
foreach my $ex (@expected) {
    $dbs{$ex}++;
}

my @found = $famadtor->known_databases;
ok $found[0],'ENSEMBLGENE',"Unexpected db in database";
ok $found[1],'ENSEMBLPEP',"Unexpected db in database";
ok $found[2],'SPTR',"Unexpected db in database";

my $id= 'ENSF00000000002';
my $fam = $famadtor->fetch_by_stable_id($id);
ok $fam->isa('Bio::EnsEMBL::ExternalData::Family::Family'),1,"Did not find family $id";
ok $fam->size,15,"Got unexpected family size";
ok $fam->size('ENSEMBLGENE'),5,"Unexpected family size by database name";


my $got = length($fam->get_alignment_string());
my $expected = 1911;
ok $got == $expected, 1, "expected alignment length $expected, got $got";

## now same for one without an alignment; should fail gracefully
$id= 'ENSF00000000005';
my $ali;
eval {
    $ali=$famadtor->fetch_by_stable_id($id)->get_alignment_string();
};

ok $@ || defined($ali),'',"got: $@ and/or $ali";

ok $fam->isa('Bio::EnsEMBL::ExternalData::Family::Family'),1,"Could not fetch family $id";


# not finding given family should fail gracefully:
$id= 'all your base are belong to us';
eval { 
    $fam = $famadtor->fetch_by_stable_id($id);
};
$@ || $fam,'',"got: $@ and/or $fam\n";

my @pair = ('SPTR', 'O15520');
$fam = $famadtor->fetch_by_dbname_id(@pair);

ok $fam->isa('Bio::EnsEMBL::ExternalData::Family::Family'),1,"Could not fetch family for @pair";

$id = 'growth factor';
my @fams = $famadtor->fetch_by_description_with_wildcards($id,1);
$expected = 5;
ok @fams == $expected,1,"expected $expected families, found ".int(@fams);

$id='fgf 21';
@fams = $famadtor->fetch_by_description_with_wildcards($id);
$expected = 1;

ok @fams == $expected,1,"expected $expected families, found ".int(@fams);

# Test general SQL stuff:
$expected = 10;
my $q=$famadtor->prepare("select count(*) from family");
$q->execute();
my ( $row ) = $q->fetchrow_arrayref;

ok (defined($row) &&int(@$row) == 1 && $$row[0] eq $expected),1,"Something wrong at SQL level";



