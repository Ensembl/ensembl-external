######################################################################
# This script is a part of SAGE mapping
# It was created by Lukasz Huminiecki and modified by Arek Kasprzyk
######################################################################
#
# the script prints out to the standard output
#
# In-files format:
# enst_locuslink.dat 
# ENST00000000027 1636
# ENST00000000089 5563
# ENST00000000233 381
# ENST00000000273 60312
# ENST00000000289 2672  
#
# unigene_locuslink.dat 
# 2       10
# 4       125
# 11      1084
# 12      1089
# 21      1990 
###


use strict;

open (EL, "enst_locuslink.dat") || die "cant open enst_locuslink.dat\n";

my %el_hash;
while (<EL>)  {
      chomp;
      my ($ensembl, $locuslink1) = split /\t/;
      $el_hash{$locuslink1}=$ensembl;
  }

open (UL, "unigene_locuslink.dat") || die "cant open unigene_locuslink.dat";
while (<UL>)
{
    chomp;
    my ($unigene1, $locuslink2) = split /\t/;
    
    if ($el_hash{$locuslink2}){
	print $el_hash{$locuslink2},"\t$locuslink2\t$unigene1\n";
    }       
}
close UL;







