#!/usr/local/bin/perl
use POSIX;

open (FILE,$ARGV[0]);
while(<FILE>)
	{
	if (/^(\S+)\s+(\S+)/)
		{
		$protein1=$1;
		$protein2=$2;
		}
	if (/([\S+]?)e-(\d+)/)
		{
		chop($_);
		$first=$1;
		$second=$2;
		$text=join("e-","$first","$second");
		@rest=split(/$text/,$_);

		if ($first eq '')
			{
			$first=1;	
			}
		if (($last1 ne $protein1) || ($last2 ne $protein2))
			{
			print "$protein1\t$protein2\t$first\t$second\n";
			}

		$last1=$protein1;
		$last2=$protein2;
		}

	else
		{
		chop($_);
		/^(\S+)\s+(\S+)/;
		print "$1\t$2\t1\t200\n";
		}


	}
