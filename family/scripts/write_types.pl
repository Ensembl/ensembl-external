#Usage perl write_types.pl swissprot.pep trembl.pep

use Bio::SeqIO;
my $swissfile = shift (@ARGV);

my $swin  = Bio::SeqIO->new(-file => $swissfile , '-format' => 'Fasta');
while (my $seq = $swin->next_seq) {
    print "SWISSPROT: ".$seq->display_id."\n";
}

my $tremblfile = shift(@ARGV);
my $trin  = Bio::SeqIO->new(-file => $swissfile , '-format' => 'Fasta');
while (my $seq = $trin->next_seq) {
    print "TREMBL: ".$seq->display_id."\n";
}
