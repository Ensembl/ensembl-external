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
BEGIN { $| = 1; print "1..16\n"; 
	use vars qw($loaded); }
END {print "not ok 1\n" unless $loaded;}

#use lib '../';
use Bio::EnsEMBL::ExternalData::Variation;
use Bio::Annotation::DBLink;

$loaded = 1;
print "ok 1\n";    # 1st test passes.


## End of black magic.
##
## Insert additional test code below but remember to change
## the print "1..x\n" in the BEGIN block to reflect the
## total number of tests that will be run. 



$obj = Bio::EnsEMBL::ExternalData::Variation -> new;

print "ok 2\n";  

 
$obj->start(3);
if ($obj->start == 3 ) {
    print "ok 3\n";
} else {
    print "not ok 3\n";
}
 
 
$obj->end(3);
if ($obj->end == 3 ) {
    print "ok 4\n";
} else {
    print "not ok 4\n";
}                

$obj->strand('1');
if ($obj->strand eq '1' ) {
    print "ok 5\n";
} else {
    print "not ok 5\n";
}
 
if ($obj->primary_tag eq 'Variation' ) {
    print "ok 6\n";
} else {
    print "not ok 6\n";
}              


$obj->source_tag('source');
if ($obj->source_tag eq 'source' ) {
    print "ok 7\n";
} else {
    print "not ok 7\n";
}
 
$obj->frame(2);
if ($obj->frame ==2 ) {
    print "ok 8\n";
} else {
    print "not ok 8\n";
}
 
$obj->score(2);
if ($obj->score ==2 ) {
    print "ok 9\n";
} else {
    print "not ok 9\n";
}
                

$obj->status('proven'); 
if ($obj->status eq 'proven' ) {
    print "ok 10\n";  
} else {
    print "not ok 10\n";
} 


$obj->alleles('alleles'); 
if ($obj->alleles eq 'alleles' ) {
    print "ok 11\n";  
} else {
    print "not ok 11\n";
} 


$obj->upStreamSeq('tgctacgtacgatcgatcga'); 
if ($obj->upStreamSeq eq 'tgctacgtacgatcgatcga' ) {
    print "ok 12\n";  
} else {
    print "not ok 12\n";
} 

$obj->dnStreamSeq('tgctacgtacgatcgatcga'); 
if ($obj->dnStreamSeq eq 'tgctacgtacgatcgatcga' ) {
    print "ok 13\n";  
} else {
    print "not ok 13\n";
}

$link1 = new Bio::Annotation::DBLink;
print   "ok 14\n";
$link1->database('TSC');
print   "ok 15\n";
$link1->primary_id('TSC0000030');
print   "ok 16\n";  


$obj->add_DBLink($link1);

print   "ok 17\n";  

foreach $link ( $obj->each_DBLink ) {
    $link->database;
    $link->primary_id;
}
print  "ok 18\n";       

if ($obj->id eq 'TSC::TSC0000030') {
    print "ok 19\n"; 
} else {
    print "not ok 19\n"; 
}
