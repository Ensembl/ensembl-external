use strict;
#use English;
my $counter = 0;
#my $positive = 0;


my $known_file="input_data_known/ELUSmapper.dat";
my $all_file="input_data_known/ENSUpostprocessor.dat";
my $temp_file=">input_data/ELUS_ENSUjoiner.dat";


my %known_hash;
open(TEMP,$temp_file) || die "cant open $temp_file";
open (ELUS, $known_file) || die "cannot open $known_file";
while (<ELUS>)
{
    chomp;
    my ($enst, $locuslink, $unigene, $tag) = split /\t/;          
    $known_hash{$enst}=$unigene;
    print TEMP "$enst\t$unigene\n";

}
close ELUS; 


open (ENSU, $all_file) || die "cannot open $all_file\n";
while (<ENSU>)  
      {
      chomp;
      my ($enst, $unigene, $score) = split /\t/;
   
      if (exists $known_hash{$enst}){
#	  print $enst,"\t",$known_hash{$enst}," printing known\n";
	  next; 
     }else {
	  print TEMP "$enst\t$unigene\n";
      }
  }
close ENSU;








   #$unigene =~ s/unigene Hs.//;
      #$unigene_line =~ m/(Hs.\d+)/;
      #my $unigene = $1;
      #print "heyhey $unigene\n";
   #   my $seen = 0;    
   #   open (ELUS, $known_file) || die "cannot open $known_file\n";
   #   while (<ELUS>)
   #	 {
   #	 chomp;
   #	 my ($enst2, $locuslink, $unigene2, $tag) = split /\t/;
   #	 if ($enst2 eq $enst) 
   #	    {
   #	    $seen = 1;
   #	    print "from elus $enst2\t$unigene2\n";
   #	    }
   # }
   #   if ($seen == 0)
   #   {
   #	   #open (SAGE, "SAGEmap_ug_tag-rel-Nla3-Hs") || die "cannot open SAGEmap_ug_tag-rel-Nla3-Hs";
   #	   #while (<SAGE>) 
   #	   #{
   #	   #     chomp;
   #	   #    my ($unigene3, $comment, $tag) = split /\t/;
   #	   #   if ($unigene3 eq $unigene) 
   #	   #     {
   #	   #print "not seen "
   #	   print "from ensu $enst\t$unigene\n";
   #   }
      
      # }       
      
  #}
      
      #$seen = 0;
      #close ELUS; 
#}
#close ENSU; 
    
















































