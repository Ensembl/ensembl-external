#!/usr/local/ensembl/bin/perl

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Conf;

use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -port port_number
   -dbname ensembl_database
   -chr_names \"20,21,22\" (default = \"all\")
   -path assembly_type (e.g. NCBI_30)
   -file fasta_file_name
   -taxon_file taxon_file_name

";

my $host;
my $user = 'ensro';
my $port = "";
my $dbname;
my $chr_names = "all"; # usage -chr_names "21,22"
my $file;
my $taxon_file;
my $path;
my $help = 0;

$| = 1;

&GetOptions(
  'help'     => \$help,
  'host=s'   => \$host,
  'port=i' => \$port,
  'user=s'   => \$user,
  'dbname=s' => \$dbname,
  'path=s'   => \$path,
  'chr_names=s' => \$chr_names,
  'file=s' => \$file,
  'taxon_file=s' => \$taxon_file
);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
					    -host   => $host,
					    -user   => $user,
					    -dbname => $dbname,
					    -port => $port
);

$db->assembly_type($path);

my $ChromosomeAdaptor = $db->get_ChromosomeAdaptor;
my @chromosomes;

my $taxon_id = $db->get_MetaContainer->get_taxonomy_id;
my %TaxonConf = %Bio::EnsEMBL::ExternalData::Family::Conf::TaxonConf;

if (defined $chr_names and $chr_names ne "all") {
  my @chr_names = split /,/, $chr_names;
  foreach my $chr_name (@chr_names) {
    push @chromosomes, $ChromosomeAdaptor->fetch_by_chr_name($chr_name);
  }
} else {
  @chromosomes = @{$ChromosomeAdaptor->fetch_all}
}

if (defined $file) {
  open FP,">$file";
} else {
  open FP,">$dbname.pep";
}

if (defined $taxon_file) {
  open TX,">$taxon_file";
} else {
  open TX,">$dbname.tax";
}

my %failedgenes;
my %already_printed_genes;
my $slice_length = 5000000;

my $SliceAdaptor = $db->get_SliceAdaptor;

foreach my $chr (reverse sort  bychrnum @chromosomes) {
  print "Chr ",$chr->chr_name,"\n";

  my $chrstart = 1;
  my $chrend   = $chr->length;
  
  for (my $start = $chrstart ; $start <= $chrend ; $start += $slice_length) {
    my $end = $start + $slice_length - 1;
    
    if ($end > $chrend) { $end = $chrend; }
    
    print STDERR "Slice = " . $chr->chr_name . " " . $start . " " . $end . "\n";
    
    my $Slice = $SliceAdaptor->fetch_by_chr_start_end($chr->chr_name, $start, $end);
    
    my @genes = @{$Slice->get_all_Genes};
    
    foreach my $gene (@genes) {
      if (check_gene_is_on_vc($gene, $Slice)) {
	foreach my $trans (@{$gene->get_all_Transcripts}) { 
	  if (defined $trans->stable_id) {
	    next if ($already_printed_genes{$trans->stable_id});
	  } else {
	    next if ($already_printed_genes{$trans->dbID});
	  }
	  my ($gene_start, $gene_end) = get_Gene_Extents($gene);
	  
	  $gene_start += ($Slice->chr_start - 1);
	  $gene_end   += ($Slice->chr_start - 1);
	  
	  my $seq = $trans->translate->seq;

	  if ($seq =~ /^X+$/) {
	    if (defined $trans->stable_id) {
	      $already_printed_genes{$trans->stable_id} = 1;
	    } else {
	      $already_printed_genes{$trans->dbID} = 1; 
	    }
	    print STDERR "X+ Translation:" . $trans->translation->stable_id .
              " Transcript:" . $trans->stable_id .
              " Gene:" . $gene->stable_id . "\n";
	    next;
	  }
	  
	  if (defined $trans->translation->stable_id) {
	    print TX "ensemblpep\t" . $trans->translation->stable_id . "\t\t" .$TaxonConf{$taxon_id} ."\n";
	    print FP ">" . $trans->translation->stable_id . 
              " Transcript:" . $trans->stable_id . 
	      " Gene:" . $gene->stable_id;
	  } else {
	    print TX "ensemblpep\t" . $trans->translation->dbID . "\t\t" .$TaxonConf{$taxon_id} ."\n";
	    print FP ">" . $trans->translation->dbID .
              " Transcript:" . $trans->dbID .
              " Gene:" . $gene->dbID; 
	  }
	  print FP " Chr:" . $Slice->chr_name .
	    " Start:" . $gene_start .
	      " End:" . $gene_end . "\n";
	  
	  $seq =~ s/(.{72})/$1\n/g;
	  
	  print FP $seq . "\n";
	  if (defined $trans->stable_id) {
	    $already_printed_genes{$trans->stable_id} = 1;
	  } else {
	    $already_printed_genes{$trans->dbID} = 1; 
	  }
	}
      } else {
	if (defined $gene->stable_id) {
	  print STDERR "Failed gene " . $gene->stable_id . "\n";
	  $failedgenes{$gene->stable_id} = 1;
	} else {
	  print STDERR "Failed gene " . $gene->dbID . "\n";
	  $failedgenes{$gene->dbID} = 1;
	}
	
      }
    }
  }
}
    
print STDERR "Fetching failures individually\n";

foreach my $gene_stable_id (keys %failedgenes) {

  my $gene = $db->get_GeneAdaptor->fetch_by_stable_id($gene_stable_id);
  my $Slice   = $SliceAdaptor->fetch_by_gene_stable_id($gene_stable_id);
  
  foreach my $trans (@{$gene->get_all_Transcripts}) {
    if (defined $trans->stable_id) { 
      next if ($already_printed_genes{$trans->stable_id}); 
    } else { 
      next if ($already_printed_genes{$trans->dbID}); 
    }  

    my $seq = $trans->translate->seq;

    if ($seq =~ /^X+$/) {
      if (defined $trans->stable_id) {
	$already_printed_genes{$trans->stable_id} = 1;
      } else {
	$already_printed_genes{$trans->dbID} = 1; 
      }
      next;
    }
    
    if (defined $trans->translation->stable_id) { 
      print FP ">" . $trans->translation->stable_id .  
	" Transcript:" . $trans->stable_id .  
	  " Gene:" . $gene->stable_id; 
    } else { 
      print FP ">" . $trans->translation->dbID . 
	" Transcript:" . $trans->dbID . 
	  " Gene:" . $gene->dbID;  
    } 
    
    print FP " Chr:" . $Slice->chr_name .
      " Start:" .  $Slice->chr_start .
	" End:" . $Slice->chr_end . "\n";
    
#    my $seq = $trans->translate->seq;
    
    $seq =~ s/(.{72})/$1\n/g;
    print FP $seq . "\n";
 
    if (defined $trans->stable_id) { 
      $already_printed_genes{$trans->stable_id} = 1; 
    } else { 
      $already_printed_genes{$trans->dbID} = 1;  
    } 
  }
}

close FP;

sub get_Gene_Extents {
  my ($gene) = @_;

  my $low  = undef;
  my $high = undef;

  foreach my $trans (@{$gene->get_all_Transcripts}) {
    if ($trans->start_Exon->strand == 1) {
      if (!defined($low) || ($trans->start_Exon->start < $low)) {
        $low = $trans->start_Exon->start;
      }
      if (!defined($high) || ($trans->end_Exon->end > $high)) {
        $high = $trans->end_Exon->end;
      }
    } else {
      if (!defined($low) || ($trans->end_Exon->start < $low)) {
        $low = $trans->end_Exon->start;
      }
      if (!defined($high) || ($trans->start_Exon->end > $high)) {
        $high = $trans->start_Exon->end;
      }
    }
  }
  return ($low, $high);
}

sub bychrnum {

  my @awords = split /_/, $a->chr_name;
  my @bwords = split /_/, $b->chr_name;

  my $anum = $awords[0];
  my $bnum = $bwords[0];

#  $anum =~ s/chr//;
#  $bnum =~ s/chr//;

  if ($anum !~ /^[0-9]*$/) {
    if ($bnum !~ /^[0-9]*$/) {
      return $anum cmp $bnum;
    } else {
      return 1;
    }
  }
  if ($bnum !~ /^[0-9]*$/) {
    return -1;
  }

  if ($anum <=> $bnum) {
    return $anum <=> $bnum;
  } else {
    if ($#awords == 0) {
      return -1;
    } elsif ($#bwords == 0) {
      return 1;
    } else {
      return $awords[1] cmp $bwords[1];
    }
  }
}

sub check_gene_is_on_vc {
  my ($gene, $Slice) = @_;
  my $failed = 0;
  my $id     = $Slice->id;
  foreach my $trans (@{$gene->get_all_Transcripts}) {
    my @trans_exons = @{$trans->get_all_Exons};
    foreach my $exon (@trans_exons) {
      if ($exon->seqname ne $id) {
        print STDERR "ERR ERR ERR Unmapped exon "
          . $exon->stable_id
          . " coords "
          . $exon->start . " to "
          . $exon->end
          . " in gene "
          . $gene->stable_id . "\n";
        $failed = 1;
      }
    }
  }
  return !$failed;
}
