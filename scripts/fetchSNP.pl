#!/usr/local/bin/perl -w

use Bio::EnsEMBL::ExternalData::SNPSQL::FullSNPAdaptor;
use Bio::EnsEMBL::ExternalData::Variation;
#use strict;

#creating the object
my $snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::FullSNPAdaptor
    ->new( -dbname=>'snp110', 
	   -user=>'ensro',
	   -host=>'ecs1a.sanger.ac.uk'
	   );

# using the method get_SeqFeature_by_id

my $id = shift;

$id = "4" unless defined $id;

my (@snps, $snp);

eval {
    @snps = $snpdb->get_SeqFeature_by_id($id);
    $snp = pop @snps;
};
die "SNP with id '$id' not found\n$@\n" if $@;

my $het = '';
$het = $snp->het if  $snp->het;


my $hetse = '';
$hetse = $snp->hetse if  $snp->hetse;

print 
"\nID             : ",        $snp->id,
"\nseqname        : ",        $snp->seqname,
"\nstart          : ",        $snp->start,
"\nend            : ",        $snp->end,
"\nstrand         : ",        $snp->strand,
"\nsource_tag     : ",        $snp->source_tag,
"\nscore          : ",        $snp->score,
"\nstatus         : ",        $snp->status,
"\nheterozygozity : ",        $het,
"\nstd.err. hes   : ",        $hetse,
"\nupStreamSeq    : ",        $snp->upStreamSeq,
"\nalleles        : ",        $snp->alleles,
"\ndnStreamSeq    : ",        $snp->dnStreamSeq,
"\n";

foreach my $link ( $snp->each_DBLink ) {

print 
"  DBLink       : ",        $link->database, "::", $link->primary_id,
"\n";

}
undef $snpdb;
