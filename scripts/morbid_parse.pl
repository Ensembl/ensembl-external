


use DBI;
use strict;


my $dsn = "DBI:mysql:database=disease;host=sol28";
my $db = DBI->connect("$dsn",'ensembl');
open(FH,"morbidmap"); 

my $entry_counter;
    
while (<FH>){
    $entry_counter++;

    my ($disease,$genes,$omim_id,$location)=split(/\|/,$_);
    $location =~s/^\s+//;
    $location =~s/\s+$//;
    $disease =~s/^\s+//;
    $disease =~s/\s+$//;
   





    print $omim_id,"\n";
    my ($chromosome,$arm,$band_start,$sub_band_start,$band_end,$sub_band_end)=&prepare_locus_entry($location);
    print $location," ",$chromosome," ",$arm," ",$band_start," ",$sub_band_start," ",$band_end," ",$sub_band_end,"\n";
    my $start=$arm.$band_start;
    if (defined $sub_band_start){$start=$start.'.'.$sub_band_start;}
    my $end=$arm.$band_end;
    if (defined $sub_band_end){$end=$end.'.'.$sub_band_end;}
    my $marker_ins = $db->prepare
	("insert into disease (disease) values ('$disease')");
    $marker_ins->execute();
    
    my $sth = $db->prepare("select id,disease from disease where disease = '$disease'");    
    $sth->execute();

	while( my $rowhash = $sth->fetchrow_hashref) {		

		my @array=split (/,/,$genes);

		foreach my $gene(@array){
		    $gene =~s/^\s+//;
		    $gene =~s/\s+$//;

		    my $marker_ins = $db->prepare
			("insert into gene (id,gene_symbol,omim_id,start_cyto,end_cyto,chromosome) 
                         values (' $rowhash->{'id'}','$gene','$omim_id','$start','$end','$chromosome')");
		    $marker_ins->execute();
		}				
	    }







sub prepare_locus_entry
	    
	{
	    my ($map_locus)=@_;
	    
	    my $chromosome;
	    my $arm;
	    my $band_start;
	    my $sub_band_start;
	    my $band_end;
	    my $sub_band_end;

	    
	    my $status=0;
	    
	    if ($map_locus =~/(.+)[-](.+)/)
	    {
		#print "map locus: $map_locus\n";	
		
		my $from=$1;
		my $to =$2;
		
		$status=1;  
		#print "from: $from to: $to\n";
		
		if ($from =~ /(\d+|[X,Y])(\w)(\d+)[.](\d+)$/)
		{
		    
		    $chromosome =$1;
		    $arm =$2;
		    $band_start=$3;
		    $sub_band_start=$4;   
		    #print "map locus: $map_locus\n";	       
		    
		    #print "$chromosome $arm $band_start $sub_band_start\n";
		}
		
		
		
		if ($from =~ /(\d+|[X,Y])(\w)(\d+)$/)
		{
		
		    $chromosome =$1;
		    $arm =$2;
		    $band_start=$3;
		    
		    #       print "map locus: $map_locus\n";
		    #print "$chromosome $arm $band_start \n";	    
		}
	    
		
		
		if ($to =~ /(\d+|[X,Y])(\w)(\d+)[.](\d+)$/)
		{
		    $band_end=$3;
		    $sub_band_end=$4;   
		    #        print "map locus: $map_locus\n"; 
		    #print "$band_end $sub_band_end\n";
		}
		
		
		
		if ($to =~ /(\d+|[X,Y])(\w)(\d+)$/)
		{
		    $band_end=$3;  
		    #  print "map locus: $map_locus\n"; 
		    #print "$band_end \n";
		}
		
		if ($to =~ /^(\d+)[.](\d+)/)
		{
		    $band_end=$1;
		    $sub_band_end=$2;   
		    # print "map locus: $map_locus\n"; 
		    
		    #print "$band_end $sub_band_end\n";
		}
		
		
		
		if ($to =~ /^(\d+)$/)
		{
		    $band_end=$1;  
		    # print "map locus: $map_locus\n";    
		    
		    #print "$band_end \n";
		}
		if ($to =~ /(\d+|[X,Y])(cent)$/)
		{
		    $band_end=0;  
		    # print "map locus: $map_locus\n";  
		    
		    #print "$band_end \n";
		}		   
		
	    }
	    
	    
	    else 
	    {
		
		#print "map locus: $map_locus\n";
		
		if ($map_locus =~ /(\d+|[X,Y])(\w)(\d+)[.](\d+)$/)
		{
		    
		    $chromosome =$1;
		    $arm =$2;
		    $band_start=$3;
		    $sub_band_start=$4;   
		    $status=1;
		    $band_end=$band_start;
		    $sub_band_end=$sub_band_start;


		    #print "map locus: $map_locus\n";
		    #print "$chromosome $arm $band_start $sub_band_start\n";
		}
		
		
		
		if ($map_locus =~ /(\d+|[X,Y])(\w)(\d+)$/)
		{
	   
		    $chromosome =$1;
		    $arm =$2;
		    $band_start=$3;   
		    $band_end=$band_start;


		    #print "map locus: $map_locus\n";
		    $status=1;
		    #print "$chromosome $arm $band_start\n";
		    
		    
	    }
		
		
		
		
		# all the rest
		elsif ( $status==0)
		{
		    # print "map locus: $map_locus\n";
		    
		    #print "weired NOT dONE\n";
		}
		
		
	    }	
	    
	    my @locus_list=($chromosome,$arm,$band_start,$sub_band_start,$band_end,$sub_band_end);
	    return @locus_list;
	}














	
    }
 
print "entry counter: $entry_counter\n";






