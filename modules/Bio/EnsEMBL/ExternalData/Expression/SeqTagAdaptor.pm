#
# EnsEMBL module for Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

    my $da= Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($obj);
    my $clone=$da->fetch($id);

    @contig = $clone->get_all_Contigs();
    @genes    = $clone->get_all_Genes();

=head1 DESCRIPTION

Represents information on one Clone

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor;
use Bio::EnsEMBL::ExternalData::BaseAdaptor;
use Bio::EnsEMBL::ExternalData::Expression::SeqTag;
use Bio::Annotation::DBLink;
use vars qw(@ISA);
use strict;

@ISA = qw(Bio::EnsEMBL::ExternalData::BaseAdaptor);




sub list_all_names {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select name from $dbname.seqtag";

    return $self->_list($statement);   

}



sub list_all_ids {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select seqtag_id from $dbname.seqtag";

    return $self->_list($statement);   

}


sub fetch_all {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier;    

    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa 
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id";

    return $self->_fetch($statement);  


}




sub fetch_by_dbID {

    my ($self,$id)=@_;
 

    $self->throw("need a db id") unless defined $id;

    my $dbname=$self->dbname; 
    my $multiplier=$self->multiplier; 

    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa 
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id
                   and    s.seqtag_id=$id";

    return $self->_fetch($statement);  



}



sub fetch_by_Library_dbID 
{
    my ($self,$id)=@_;

    $self->throw("need a library id") unless defined $id;

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 
    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency, 
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa 
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id 
                   and    f.library_id='$id'";

    return $self->_fetch($statement);  

}



sub fetch_by_Library_dbID_above_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless defined $id;
    $self->throw("need a frequency value") unless defined $frequency;

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 

    my $statement="select s.seqtag_id,s.source,s.name,sa.db_name,sa.external_name,f.frequency,
                   ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa 
                   where  s.seqtag_id=f.seqtag_id 
                   and    sa.seqtag_id=s.seqtag_id 
                   and    f.library_id='$id' and f.frequency>$frequency";


    return $self->_fetch($statement);  


}




sub fetch_by_Library_dbID_above_relative_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless defined $id;
    $self->throw("need a frequency value") unless defined $frequency;
    
    my $multiplier=$self->multiplier; 
    my $dbname=$self->dbname;

    my $statement="select   s.seqtag_id,s.source,s.name,sa.db_name,sa.external_name,f.frequency,  
                            ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from     $dbname.seqtag s,$dbname.frequency f,$dbname.library l,$dbname.seqtag_alias sa  
                   where    s.seqtag_id=f.seqtag_id                                    
                   and      l.library_id=f.library_id 
                   and      sa.seqtag_id=s.seqtag_id 
                   and      f.library_id='$id' and  
                            ceiling((f.frequency*$multiplier/l.total_seqtags) -1)>$frequency
                   order by relative_frequency desc";


    return $self->_fetch($statement);  

}


sub fetch_by_Library_Name 
{
    my ($self,$name)=@_;

  $self->throw("need a library name") unless defined $name;

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 
    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,    
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa,
                          $dbname.library l  
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id 
                   and    l.library_id=f.library_id and l.name='$name'";

    return $self->_fetch($statement);

}


sub fetch_by_LibraryList_dbIDs 
{
    my ($self,@ids)=@_;
}



sub fetch_by_LibraryList_Name 
{
    my ($self,@ids)=@_;
}





=head2 dbname

 Title   : dbname
 Usage   : $obj->dbname($newval)
 Function: 
 Example : 
 Returns : value of dbname
 Args    : newvalue (optional)


=cut

sub dbname {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_dbname'} = $value;
    }
    return $obj->{'_dbname'};

}


=head2 multiplier

 Title   : multiplier
 Usage   : $obj->multiplier($newval)
 Function: 
 Example : 
 Returns : value of multiplier
 Args    : newvalue (optional)


=cut

sub multiplier {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_multiplier'} = $value;
  } elsif (!defined$obj->{'_multiplier'})  {
      $obj->{'_multiplier'}=1000000;
  }
    return $obj->{'_multiplier'};
}



sub _list {
 my ($self,$statement)=@_;
 my @tag_ids;
 my $sth = $self->prepare($statement);    
 $sth->execute();

 while (my $nm=$sth->fetchrow_array){
     push @tag_ids,$nm;
 }

 return @tag_ids;
}



sub _fetch {

    my ($self,$statement)=@_;

    my @tags;
    my $sth = $self->prepare($statement);    
    $sth->execute();
    
    my ($library_id,$source,$name,$db,$external_name,$frequency,$relative_frequency);

    $sth->bind_columns(undef,\$library_id,\$source,\$name,\$db,\$external_name,\$frequency,\$relative_frequency);

    while ($sth->fetch){	
	my @args=($library_id,$source,$name,$frequency,$relative_frequency);	
	my $tg=Bio::EnsEMBL::ExternalData::Expression::SeqTag->new($self,@args);
	push @tags,$tg;
	
	my $link = new Bio::Annotation::DBLink;
	$link->database($db);
	$link->primary_id($external_name);
	$tg->add_DBLink($link);
	
    }    
    return @tags;    
}



















