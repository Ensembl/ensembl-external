use strict;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor;
use Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor;
my $obj= Bio::EnsEMBL::DBSQL::Obj->new(-dbname=>'ensembl080',-user=>'ensadmin',-host=>'ecs1c');

my $dbname='expression';
my $lib_ad=Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor->new($obj);
$lib_ad->dbname($dbname);

my $tag_ad= Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($obj);
$tag_ad->dbname($dbname);




#my @tags=$tag_ad->list_all_ids;
#foreach my $name (@tags){print "$name\n";}


#my @libs=$lib_ad->fetch_all;
#my @libs=$lib_ad->fetch_by_SeqTag_Name("AAAAAAAAAT");

my @libs=$lib_ad->fetch_by_SeqTag_Synonym("ENSG00000080561"); 

#my @tgs=("AAAAAAAAAA","AAAAAAAAAC");
#my @libs=$lib_ad->fetch_by_SeqTagList(@tgs);

#my @tgs=("ENSG00000080561","ENSG00000087370");
#my @libs=$lib_ad->fetch_by_SeqTag_SynonymList(@tgs);

foreach my $lib (@libs){
    print $lib->id,"\t",$lib->name,"\t",$lib->total_seqtags,"\n";
#    foreach my $tag($lib->fetch_all_SeqTags_above_relative_frequency(5000)){
#	foreach my $link ($tag->each_DBLink){
#	    if ($link->database eq 'enstrans'){
#		print $tag->name," ",$link->primary_id," ",$tag->relative_frequency,"\n";
		
#	    }    
#	}
#    }
}




my @tags=$tag_ad->fetch_by_Library_Name("SAGE_Duke_1273");

#my @ids=(1,2);
#my @tags=$tag_ad->fetch_by_LibraryList_dbIDs(@ids);
#my @tags=$tag_ad->fetch_by_Library_dbID(2);

#my @tags=$tag_ad->fetch_by_Library_dbID(1);

#my @tags=$tag_ad->fetch_all;

#my @tags=$tag_ad->fetch_by_dbID(10);
#my @tags=$tag_ad->fetch_by_Name("AAAAAAAAAA");

foreach my $tag(@tags){
   # print $tag->name," ",$tag->frequency,"\n";
    
    foreach my $link ($tag->each_DBLink){
	if ($link->database eq 'ensgene'){	    
	    print $link->primary_id," ",$tag->frequency,"\n";
	}	
    }
}




#my @tags=$tag_ad->list_all_ids;
#foreach my $name (@tags){print "$name\n";}




















