# $Id$
## Little test script for the family stuff

my $m = "This test script goes with scripts/family-cob.dat, which is loaded by
scripts/family-input.pl [ stuff (try -h) ] family-test.dat It does _not_
adhere to the Geneva test ban conventions!!; will ratify this later :-P)
";

warn $m;

use strict;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;

# do ...;

my $db = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new(
                                        -dbname=>'family_test', 
                                         -host=>'localhost', 
                                         -user=>'root');

my $fam = $db->get_Family_by_id('ENSF00000000009');
if (defined($fam)){
    print "ok\n";
    _print_fam($fam);
} else  {
    print "not ok\n";
    warn "didn't find a family";
}

# $fam = $db->get_Family_of_Ensembl_pep_id('ENSP00000204233');
$fam = $db->get_Family_of_Ensembl_pep_id('COBP00000002080');
if (defined($fam)){
    print "ok\n";
    _print_fam($fam);
} else  {
    print "not ok\n";
    warn "didn't find a family";
}

# $fam = $db->get_Family_of_Ensembl_gene_id('ENSG00000042607');
$fam = $db->get_Family_of_Ensembl_gene_id('COBG00000002080');
if (defined($fam)){
    print "ok\n";
    _print_fam($fam);
} else  {
    print "not ok\n";
    warn "didn't find a family";
}


$fam = $db->get_Family_of_db_id('SWISSPROT', 'DECR_HUMAN');
if (defined($fam)){
    print "ok\n";
    _print_fam($fam);
} else  {
    print "not ok\n";
    warn "didn't find a family";
}

my @fams = $db->get_Families_described_as('reductase');
foreach $fam (@fams) {
    if (defined($fam)){
        print "ok\n";
        _print_fam($fam);
    } else  {
        print "not ok\n";
        warn "didn't find a family";
    }
}
exit 0;

@fams = $db->all_Families();
foreach $fam (@fams) {
    if (defined($fam)){
        print "ok\n";
        _print_fam($fam);
    } else  {
        print "not ok\n";
        warn "didn't find a family";
    }
}

sub _print_fam {
  my ($fam) = @_;
$\ = "\n"; $"=" : ";

  print "id: ", $fam->id;
  print "internal_id: ", $fam->internal_id;
  print "substr(descr,0,40): ", substr($fam->description, 0,40);
  print "release: ", $fam->release;
  print "score: ", $fam->annotation_confidence_score ;
  print "size: ", $fam->size;

  print "ENS PEP members:\n";
  _print_mem( $fam->each_ens_pep_member() );

  print "ENS GENE members:\n";
  _print_mem( $fam->each_ens_gene_member() );

  print "SP members:\n";
  _print_mem( $fam->each_member_of_db('SWISSPROT') );

#   print "All members:\n";
#  _print_mem($fam->each_DBLink() );
  print "\n";
}  

sub _print_mem {
 my (@mems) = @_;
 
 foreach my $mem (@mems) {
     print "\t", $mem->database, ":", $mem->primary_id;
 }
}
