## Bioperl Test Harness Script for Modules
## $Id$

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.t'

#-----------------------------------------------------------------------
## perl test harness expects the following output syntax only!
## 1..3
## ok 1  [not ok 1 (if test fails)]
## 2..3
## ok 2  [not ok 2 (if test fails)]
## 3..3
## ok 3  [not ok 3 (if test fails)]
##
## etc. etc. etc. (continue on for each tested function in the .t file)
#-----------------------------------------------------------------------


## We start with some black magic to print on failure.
BEGIN { $| = 1; print "1..5\n"; 
	use vars qw($loaded); }
END {print "not ok 1\n" unless $loaded;}

#use lib '../';

use Bio::EnsEMBL::ExternalData::SNPSQL::Obj

$loaded = 1;
print "ok 1\n";    # 1st test passes.


## End of black magic.
##
## Insert additional test code below but remember to change
## the print "1..x\n" in the BEGIN block to reflect the
## total number of tests that will be run. 

#creating the object
$snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::Obj->new( -dbname=>'tsc', 
						       -user=>'root'
						       );
print "ok 2\n"; 

#doing a query
my $query =  qq{ select(2+3) };
my $sth = $snpdb->prepare($query);
my $res = $sth->execute();

if( $res) {
    print "ok 3\n"; 
} else {
   print "not ok 3\n";
}

while( (my $arr = $sth->fetchrow_arrayref()) ) {   
    my ($val) = @{$arr};
    
    if( $val == 5 ) {
	print "ok 4\n"; 
    } else {
	print "not ok 4\n";
    }
}

#accessing the method get_Ensembl_SeqFeatures_clone

#AC025148.1 AB000381.1  AB012922.1
#get_Ensembl_SeqFeatures_clone(AC025148.1, 1 ,$start,$end);
@variations = $snpdb->get_Ensembl_SeqFeatures_clone('AB000381', '1' );
if ( scalar @variations == 1 ) { 
    print "ok 5\n"; 
}  else {
    print "not ok 5\n";
}
