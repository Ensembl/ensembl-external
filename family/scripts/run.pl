#!/usr/local/bin/perl
$|=1;

$blastdir="/usr/local/ensembl/bin/";
$directory=`pwd`;
chop($directory);

print "$directory\n";

if ($ARGV[0] > 0)
	{
	$select=$ARGV[0];
	}
else
	{
	$select=-1;
	}
print "$select\n";
for ($i=1;$i<400;$i++)
	{
	if (($i==$select) || ($select == -1))
	{
	$command=join("","bsub -q acari -e $directory/results/$i.joberr -o $directory/results/$i.jobout -E \"ls -al /data/sync/families/august23.pep.phr\" \"$blastdir","blastall_2.0.11 -p blastp -i $directory/seq/august23.pep.$i -d /data/sync/families/august23.pep -e 0.00001 | /nfs/acari/ae1/bin/parse > /tmp/anton-$$-$i.out; gzip /tmp/anton-$$-$i.out; /usr/bin/rcp /tmp/anton-$$-$i.out.gz acari:$directory/results/$i.out.gz; rm -f /tmp/anton-$$-$i.* \"");
	print "$command\n";
	if ($ARGV[-1] eq 'go')
			{
			if (!-e "$directory/results/$i.out.gz")
				{
			$pants = system ($command);
			print "Result = $pants\n";
			#sleep 0.5;
				}
			}
	}
	}
