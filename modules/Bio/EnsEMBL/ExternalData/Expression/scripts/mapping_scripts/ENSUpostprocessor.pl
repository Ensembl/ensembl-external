
use strict;
use English;

my %hash = ();


# filter 1: $score has to be above 300

open (ENSU, "input_data/ENSUmapper.dat") || die "cannot open ENSUmapper.dat\n";
while (<ENSU>)  
      {
      chomp;
      my ($enst, $unigene, $score) = split /\t/;
      push (@{$hash{$unigene}}, $enst) if $score > 300
      }


# filter 2: unigenes that map to more than 15 ENSTs are filtered out


foreach my $unigene (keys %hash) {
if (@{$hash{$unigene}} < 6)
   {
   while (@{$hash{$unigene}}) 
         {
         my $enst = shift @{$hash{$unigene}}; 
         print $enst, "\t", $unigene, "\n";
         }
   } 
} 


