use strict;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::DBSQL::StaticGoldenPathAdaptor;

my $db=Bio::EnsEMBL::DBSQL::Obj->new(-dbname=>"simon_dec12",-user=>"ensro",-host=>"ecs1b");

$db->static_golden_path_type('UCSC');

my $stadaptor = $db->get_StaticGoldenPathAdaptor();
my $file="chr.dat";
my $output_file=">ENSUmapper.dat";

open (FH,$file) || die "cant open $file";
open (OUT,$output_file) || die "cant open $output_file";

while (<FH>){
    
    chomp;
    /^\#/ && next;
    print STDERR "chromosome ",$_,"\n";
    my $contig=$stadaptor->fetch_VirtualContig_by_chr_name("$_");
    print STDERR "fetched vc\n";

    my @transcripts=sort {$a->start <=> $b->start}$contig->get_all_VirtualTranscripts_startend();
    print STDERR "sorted transcripts ",$#transcripts,"\n";

    my @features=sort {$a->start <=> $b->start}$contig->get_all_SimilarityFeatures_above_score('unigene.seq',1);
    print STDERR "sorted features\n";
    
    my $transcript_counter;
    my $index_pos=0;
    my %scores;

  TRANSCRIPT:foreach my $transcript (@transcripts){
      
      my $counter=0;
      my $i;
      $transcript_counter++;
      
      print STDERR $_,"\t",$transcript->id,"\t",$transcript_counter,"\t",$#transcripts,"\n";
      
    FEATURE:for($i=$index_pos;$i<=$#features;$i++){
	my $seen=0;
	
	my $feature=$features[$i];
	
	if ($feature->id =~/^Hs/){
	    
	    my $id=$feature->id;
	    my $score=$feature->score; 	
	    $id=~s/^Hs//;
	    $id=~s/\.//;
	    
	    if ($feature->start>=$transcript->start && $feature->end<=$transcript->end){
		$counter++;
		$seen=1;		    
		$scores{$score} = $id;
	    }
	    if ($counter>0 && $seen==0)
	    {
		my @keys = (sort {$b <=> $a} keys %scores);
		print OUT $transcript->id,"\t", $scores{$keys[0]}, "\t", $keys[0],"\n";
		%scores = ();
		next TRANSCRIPT; 
	    }
	}    
    }
  }
}

print STDERR "I have finished!!!!!!!!!!!!!!!!!!!!!\n";





