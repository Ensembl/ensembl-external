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

    # $obj is Bio::EnsEMBL::DB::Obj 

    my $dbname='expression';
    my $tag_ad= Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($obj);
    $tag_ad->dbname($dbname);
    my $tag=$sta->fetch_by_Name("AAAAAAAAAA");


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



=head2 list_all_names

 Title   : list_all_names
 Usage   : $obj->list_all_names($newval)
 Function: 
 Example : 
 Returns : array of seqtag names
 Args    :


=cut


sub list_all_names {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select name from $dbname.seqtag";

    return $self->_list($statement);   

}



=head2 list_all_ids

 Title   : list_all_ids
 Usage   : $obj->list_all_ids($newval)
 Function: 
 Example : 
 Returns : array of seqtag db ids
 Args    :


=cut



sub list_all_ids {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select seqtag_id from $dbname.seqtag";

    return $self->_list($statement);   

}




=head2 fetch_all

 Title   : fetch_all
 Usage   : $obj->fetch_all
 Function: 
 Example : 
 Returns : array of seqtag objects
 Args    :


=cut





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



=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   : $obj->fetch_by_dbID
 Function: 
 Example : 
 Returns :seqtag object
 Args    :db id


=cut




sub fetch_by_dbID {

    my ($self,$id)=@_;
 

    $self->throw("need a db id") unless  $id;

    my $dbname=$self->dbname; 
    my $multiplier=$self->multiplier; 

    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa, 
                          $dbname.library l 
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id
                   and    l.library_id=f.library_id and s.seqtag_id=$id";

    my @tags=$self->_fetch($statement);  
    if ($#tags>=0){
	return shift @tags;
    }else {return;}
    
}




=head2 fetch_by_Name

 Title   : fetch_by_Name
 Usage   : $obj->fetch_by_Name
 Function: 
 Example : 
 Returns :seqtag object
 Args    :db id


=cut




sub fetch_by_Name {

    my ($self,$name)=@_;
 

    $self->throw("need a tag name") unless  $name;

    my $dbname=$self->dbname; 
    my $multiplier=$self->multiplier; 

    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa, 
                          $dbname.library l 
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id
                   and    l.library_id=f.library_id and s.name='$name'";

    my @tags=$self->_fetch($statement);  
    if ($#tags>=0){
	return shift @tags;
    }else {return;}
    
}



=head2 fetch_by_Library_dbID

 Title   : fetch_by_Library_dbID
 Usage   : $obj->fetch_by_Library_dbID
 Function: 
 Example : 
 Returns : array of seqtag objects
 Args    : library id


=cut


sub fetch_by_Library_dbID 
{
    my ($self,$id)=@_;

    $self->throw("need a library id") unless  $id;

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 
    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency, 
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa,
                          $dbname.library l  
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id 
                   and    l.library_id=f.library_id and f.library_id='$id'";

    return $self->_fetch($statement); 
}



=head2 fetch_by_Library_Name

 Title   : fetch_by_Library_Name
 Usage   : $obj->fetch_by_Library_Name
 Function: 
 Example : 
 Returns : array of seqtag objects
 Args    : library name


=cut




sub fetch_by_Library_Name 
{
    my ($self,$name)=@_;

  $self->throw("need a library name") unless  $name;

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




=head2 fetch_by_LibraryList_dbID

 Title   : fetch_by_LibraryList_dbID
 Usage   : $obj->fetch_by_LibraryList_dbID
 Function: 
 Example : 
 Returns : array of seqtag objects
 Args    : array of library ids


=cut




sub fetch_by_LibraryList_dbIDs 
{
    my ($self,@ids)=@_;

    $self->throw("need a list of library ids") unless  @ids && $#ids>=0;
    
    my $list=$self->_prepare_list(@ids);

    unless ($list){
	return ();
    }
           
    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 
    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency, 
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa,
                          $dbname.library l  
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id 
                   and    l.library_id=f.library_id and f.library_id in $list";

   
    return $self->_fetch($statement); 


}


=head2 fetch_by_LibraryList_Name

 Title   : fetch_by_LibraryList_Name
 Usage   : $obj->fetch_by_LibraryList_Name
 Function: 
 Example : 
 Returns : array of seqtag objects
 Args    : array of library names


=cut



sub fetch_by_LibraryList_Name 
{
    my ($self,@ids)=@_;

    $self->throw("need a list of library ids") unless  @ids && $#ids>=0;
    
    my $list=$self->_prepare_list(@ids);
    
    unless ($list){
	return ();
    }
    
    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 

    my $statement="select s.seqtag_id,s.source,s.name,
                          sa.db_name,sa.external_name,f.frequency,    
                          ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as relative_frequency
                   from   $dbname.seqtag s,$dbname.frequency f,$dbname.seqtag_alias sa,
                          $dbname.library l   
                   where  s.seqtag_id=f.seqtag_id and sa.seqtag_id=s.seqtag_id 
                   and    l.library_id=f.library_id and l.name in $list";
    
    return $self->_fetch($statement);


}


=head2  fetch_by_Library_dbID_above_frequency

 Title   : fetch_by_Library_dbID_above_frequency
 Usage   : $obj->fetch_by_Library_dbID_above_frequency
 Function: this method is supposed to be used from LibraryAdaptor
 Example : 
 Returns : array of seqtag objects above absolute frequency
 Args    : libray id, frequency


=cut


sub fetch_by_Library_dbID_above_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless  $id;
    $self->throw("need a frequency value") unless  $frequency;

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



=head2  fetch_by_Library_dbID_above_relative_frequency

 Title   : fetch_by_Library_dbID_above_relative_frequency
 Usage   : $obj->fetch_by_Library_dbID_above_relative_frequency
 Function: this method is supposed to be used from LibraryAdaptor
 Example : 
 Returns : array of seqtag objects above relative frequency
 Args    : libray id, frequency


=cut


sub fetch_by_Library_dbID_above_relative_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless  $id;
    $self->throw("need a frequency value") unless  $frequency;
    
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



sub _prepare_list {
    my ($self,@ids)=@_;
    
    my $string;
    foreach my $id(@ids){
	$string .= $id . ","; 
    }
    chop $string;
    
    if ($string) { $string = "($string)";} 

    return $string;
    
}















