#!/usr/local/bin/perl
$|=1;
use POSIX;

if (!$ARGV[0] || !$ARGV[1] || !$ARGV[2])
	{
	print "assembl.pl\n\nUsage: assembl.pl annotationfile swissprot-consensus sptrembl-consensus\n";
	exit(1);
	}

open (FILEOUT,">annotations.discarded"); 

open (FILE1,$ARGV[0]);
while (<FILE1>)
	{
	chop($_);
	@temp=split(" ",$_);
	$cluster=$temp[1];
	$name=$temp[2];
	push(@{$hash{$cluster}},$name);
	}

close FILE1;
open (FILE,$ARGV[1]);
while (<FILE>)
	{
	/^(\d+)\s+>>>(.*)<<<\s+(\d+)/;
	$swisshash{$1}=$2;
	$swissscore{$1}=$3;
	}
close FILE;

open (FILE,$ARGV[2]);
while (<FILE>)
        {
        /^(\d+)\s+>>>(.*)<<<\s+(\d+)/;
        $tremblhash{$1}=$2;
        $tremblscore{$1}=$3;
        }


foreach $thing (sort numeric (keys(%hash)))
	{
	$members="";

	$annotation="UNKNOWN";
	$score=0;

	if ($swisshash{$clusters})
		{
		$annotation=$swisshash{$clusters};
		$score=$swissscore{$clusters};
		if ($score==0)
			{
			$score=1;
			}
		}

	elsif ($tremblhash{$clusters})
		{
		$annotation=$tremblhash{$clusters};
		$score=$tremblscore{$clusters};
		if ($score==0)
                        {
                        $score=1;
                        }
		}

	# Do Some Annotation Checking

	@array=split(" ",$annotation);

	$total=$#array+1;
	$discard=0;	

	foreach $element (@array)
		{
		$_=$element;
	if ((/^PROTEIN$/) || (/^FRAGMENT$/) ||(/^\d+$/) || (/^HSPC\d+/) || (/^FACTOR$/) || (/^HYPOTHETICAL$/) || (/^KIAA\d+/) || (/^PRECURSOR$/) || (/^EST$/) || (/\S+RIK/) || (/IMAGE:\d+/)) 
			{
			$discard++;
			}
		}
	
		$_=$annotation;
	#Global Fixes;
		if (/CDNA/ && /FIS/ && /CLONE/ && !/WEAKLY SIMILAR/ && !/MODERATELY SIMILAR/) 
                        {
                        $total=0;
                        }

		$_=$annotation;
		$annotation=~ s/EC (\d+) (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.$4/;
		$annotation=~ s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.-/;
		$annotation=~ s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.-\.-/;
		$annotation=~ s/(\d+) (\d+) KDA/$1\.$2 KDA/;
		
	if (($total-$discard) <= 0)
		{
		print FILEOUT "$clusters\t$annotation\t$score\t:$members\n";
		$annotation="UNKNOWN"; 
		$score=0;
		}

	$final_total=$final_total+($#{$hash{$thing}}+1);
	$members=join(":",@{$hash{$thing}});
	print "ENSF";
	printf("%011.0d",$clusters+1);
	print "\t$annotation\t$score\t:$members\n";
	$clusters++;
	}

print STDERR "FINAL TOTAL: $final_total\n";

sub numeric { $a <=> $b}

