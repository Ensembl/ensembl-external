#!/usr/local/bin/perl
use lib "/nfs/acari/ae1/bin/"; 

use Algorithm::Diff qw(diff LCS traverse_sequences);

$|=1;

$test="cat $ARGV[0] | tr \'-\' \' \' | tr \'\.\' \' \'|\n";
open (FILE,"cat $ARGV[0] | tr \'-\' \' \' | tr \'\.\' \' \'| tr \'\(\' \' \' | tr \'\)\' \' \' |");
while (<FILE>)
	{
	/^\S+\s+(\d+)\s+(\S+)\s+>(.*)/;
	$protein=$2;
	$cluster=$1;
	$rest=$3;
	@temp=split(" ",$rest);
	pop(@temp);
	$rest=join(" ",@temp);

	if ( /SPTREMBL/ )
		{
		push(@{$hash{$cluster}},$rest);
		}
	}

foreach $cluster (sort sort_num(keys(%hash)))
	{
	print "$cluster\t";
	undef %lcshash;
	@array=@{$hash{$cluster}};

	$total_members=$#array+1;
	$temp=join("\n",@array);

	if ($total_members==1)
                {
                $final_annotation=${hash{$cluster}}[0];
                }

	while ($#array > 0)
		{
		$temp=$#array+1;
		for ($i=0;$i<$#array+1;$i++)
			{
			for ($j=$i+1;$j<$#array+1;$j++)
				{
				@list1=split(" ",$array[$i]);
				@list2=split(" ",$array[$j]);
				@lcs=LCS(\@list1,\@list2);
                        	$lcs=join(" ",@lcs);
				$lcshash{$lcs}=1;
				$lcnext{$lcs}=1;
				}
			}
		$j=0;
		undef(@array);
		foreach $newthing (keys(%lcnext))
			{
			$array[$j]=$newthing;
			$j++;
			}
		undef %lcnext;
		}

	$best=0;
	$best_lcs=0;
	foreach $final (sort sort_len(keys(%lcshash)))
		{
		@temp=split(" ",$final);
		$length=$#temp+1;
		$lcs_count=0;
	
		foreach $check (@{$hash{$cluster}})
			{
			@list1=split(" ",$final);
			@list2=split(" ",$check);
			@lcs=LCS(\@list1,\@list2);
                        $lcs=join(" ",@lcs);  
		
			if ($lcs eq $final)
				{
				$lcs_count++;
				}
			}	

		$lcs_count=($lcs_count/$total_members)*100;
		$score=$lcs_count+($length*14);
		if (($lcs_count >= 40) && ($length >= 1))
			{
			if ($score > $best)
				{
				$best=$score;
				$best_lcs=$lcs_count;
				$final_annotation=$final;
				}
			}
		}
	if ($best_lcs==0)
		{
		$best_lcs=100;
		}
	print ">>>$final_annotation<<<\t$best_lcs\n";
	$final_annotation="";
	}


sub sort_num { $a <=> $b };

sub sort_len { length($b) <=> length($a) };
