#!/usr/local/bin/perl
$|=1;

open (PIPE,'grep -c ">" seq/*.pep.*|');
while (<PIPE>)
	{
	chop($_);
	/\.(\d+)\:.*$/;
	$id=$1;
	$count=(split(":",$_))[-1];
	print "$id $count\n";
	$hash{$id}=$count;
	}
close PIPE;

foreach $thing(sort numeric(keys(%hash)))
	{

	print "$thing\n";
	$count=`gunzip -c ./results/$thing.out.gz | tail -1`;
	$_=$count;
	/(\d+)$/;
	$count=$1;
	print "$thing ($count):";
	if ($hash{$thing} != $count)
		{
		print "Not Consistent: $count $hash{$thing}\n";
		system("rm -r ./results/$thing.*");
		system("run.pl $thing $ARGV[-1]");
		}
	else
		{
		print "Consistent $count\n";
		}
	}

sub numeric { $a <=> $b };
