#$Id$
#
# BioPerl module for Bio::EnsEMBL::ExternalData::Variation
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Variation - Variation SeqFeature

=head1 SYNOPSIS

    $feat = new Bio::EnsEMBL::ExternalData::Variation
                (-start => 10, -end => 10,
		 -strand => 1,
		 -source => 'The SNP Consortium',
		 -score  => 99,           #new meaning
		 -status = > 'suspected', #new
		 -alleles => 't|c'        #new
		 );

   # add it to an annotated sequence

   $annseq->add_SeqFeature($feat);



=head1 DESCRIPTION

Bio::EnsEMBL::ExternalData::Variation redifines and extends
L<Bio::SeqFeature::Generic> for (genomic) sequence variations.

Attribute 'source' is used to give the source database string.
Attribute 'score' is used to give the code number for uniquesness of
the SNP. Lower values are better. 1 is best.  'status' has two values:
'suspected' or 'proven'. 'alleles' lists all known, typically two,
allelic variants in the given position.

This class has methods to store and return database cross references
(L<Bio::Annotation::DBLink>).

This class is designed to provide light weight objects for sequence
annotation. Classes implementing L<Bio::Variation::SeqChangeI> interface
facilitate full description of mutation events at DNA, RNA and AA
levels. A collection of SeqChangeI compliant objects can be linked together by
L<Bio::Variation::Haplotype> or L<Bio::Variation::Genotype>objects.

The attibute 'primary_tag' is set to "Variation" by the
constructor. It is recommended that it is not changed although
inherited method primary_tag can be used.

=head1 CONTACT

Heikki Lehvaslaiho <heikki@ebi.ac.uk>

Address:

     EMBL Outstation, European Bioinformatics Institute
     Wellcome Trust Genome Campus, Hinxton
     Cambs. CB10 1SD, United Kingdom

=cut

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Variation;
use vars qw(@ISA);
use strict;

# Object preamble - inheritance

use Bio::SeqFeature::Generic;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;
use Bio::SeqIO::FTHelper;

@ISA = qw( Bio::SeqFeature::Generic  Bio::DBLinkContainerI);


sub new {
    my($class,@args) = @_;
    my $self;
    $self = Bio::SeqFeature::Generic->new();

    # rebless into own class
    bless $self, $class;
    

#sub _initialize {
#    my($self,@args) = @_;
#    
# my $make = $self->SUPER::_initialize;
#
#    #my $self;
#    #$self = {};
#    #bless $self, $class;

    my ($start, $end, $strand, $primary_tag, $source,
	$frame, $score, $gff_string, $status, $alleles,
	$upstreamseq, $dnstreamseq,$subsnpid,$handle,$original_strand) =
	    $self->_rearrange([qw(START
				  END
				  STRAND
				  PRIMARY_TAG
				  SOURCE
				  FRAME
				  SCORE
				  GFF_STRING
				  STATUS
				  ALLELES
				  UPSTREAMSEQ
				  DNSTREAMSEQ
				  SUBSNPID
				  HANDLE
				  ORIGINAL_STRAND
				)],@args);

    $self->primary_tag("Variation");

    $start && $self->SUPER::start($start);
    $end   && $self->SUPER::end($end);
    $start && $self->start_in_clone_coord($start);
    $end   && $self->end_in_clone_coord($end);
    if (defined $strand) {$self->strand($strand);}
    $primary_tag && $self->SUPER::primary_tag($primary_tag);
    $source  && $self->SUPER::source_tag($source);
    $frame   && $self->SUPER::frame($frame);
    $score   && $self->SUPER::score($score);
    ##$gff_string && $self->SUPER::_from_gff_string($gff_string);
    $status  && $self->status($status);
    $alleles && $self->alleles($alleles);
    $upstreamseq  && $self->upStreamSeq($upstreamseq);
    $dnstreamseq  && $self->dnStreamSeq($dnstreamseq);
    $subsnpid  && $self->sub_snp_id($subsnpid);
    $handle  && $self->handle($handle);
    if (defined $original_strand) {$self->original_strand($original_strand);}
    $self->{ 'link' } = [];

    # set stuff in self from @args
    return $self; # success - we hope!
}


sub strand {
    my ($self,$value) = @_;

    if( defined $value ) {
        $self->{'_snp_strand'} = $value;
    }
    return $self->{'_snp_strand'};
}


=head2 id

 Title   : id
 Usage   : $obj->id
 Function:

           Read only method. Returns the id of the variation object.
           The id is derived from the first DBLink object attached to
           this object.

 Example :
 Returns : scalar
 Args    : none

=cut


sub id {
    my ($obj) = @_;

    my @ids = $obj->each_DBLink;
    my $id = $ids[0];
    return  $id->primary_id;
}

=head2 clone_name

 Title   : clone_name
 Usage   : $obj->clone_name
 Function:

           Read only method.

 Example :
 Returns : scalar
 Args    : none

=cut

sub clone_name {
    my ($obj) = @_;

    my @names = $obj->each_DBLink;
    my $name = $names[0];
    return  $name->optional_id;
}

=head2 start_in_clone_coord

 Title   : start_in_clone_coord
 Usage   : $obj->start_in_clone_coord();
 Function:

            Sets and returns the start in the original coordinate
            system The start attribute will be reset to other
            cooerdiante systems. If value is not set, returns undef.

 Example :
 Returns : integer or undef
 Args    : integer

=cut

sub start_in_clone_coord {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'start_in_clone_coord'} = $value;
    }
   if( ! exists $obj->{'start_in_clone_coord'} ) {
       return undef;
   }
   return $obj->{'start_in_clone_coord'};

}

=head2 end_in_clone_coord

 Title   : end_in_clone_coord
 Usage   : $obj->end_in_clone_coord();
 Function:

            Sets and returns the end in the original coordinate
            system.  The end attribute will be reset to other
            cooerdiante systems.  If value is not set, returns undef.

 Example :
 Returns : integer or undef
 Args    : integer

=cut

sub end_in_clone_coord {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'end_in_clone_coord'} = $value;
    }
   if( ! exists $obj->{'end_in_clone_coord'} ) {
       return undef;
   }
   return $obj->{'end_in_clone_coord' };

}

=head2 status

 Title   : status
 Usage   : $obj->status()
 Function:

           Returns the status of the variation object.
           Valid values are: 'suspected' and 'proven [by XXX]'

 Example : $obj->status('proven by submitter');
 Returns : scalar
 Args    : valid string (optional, for setting)


=cut


sub status {
   my ($obj,$value) = @_;
   my %status = ('suspected' => 1,
		 'proven by submitter' => 1,
		 'proven by frequency' => 1,
		 'proven by cluster' => 1,
		 'proven ' => 1,
		 'proven' => 1
		 );

   if( defined $value) {
       $value = lc $value;
       if ($status{$value}) {
	   $obj->{'status'} = $value;
       }
       else {
	   $obj->throw("$value is not valid status value!");
       }
    }
   if( ! exists $obj->{'status'} ) {
       return undef;
   }
   return $obj->{'status'};
}


=head2 alleles

 Title   : alleles
 Usage   : @alleles = split ('|', $obj->alleles);
 Function:
           Returns the a string where all known alleles for this position
           are listed separated by '|' characters

 Returns : A string
 Args    : A string (optional, for setting)

=cut

sub alleles {
    my ($obj,$value) = @_;
    if( defined $value) { 
	$obj->{'alleles'} = $value;
    }
    if (   defined $obj->original_strand && $obj->original_strand == -1
        && defined $obj->_reversed       && $obj->_reversed != 1 )
    {             
	my $value=$obj->{'alleles'};
	$value=~tr/ATGCatgc/TACGtagc/; 
	$obj->{'alleles'} = $value;
	$obj->_reversed(1);
    }
    
    if( ! exists $obj->{'alleles'} ) {
	return undef;
    }
    return $obj->{'alleles'};
    
}

=head2 position_problem

 Title   : position_problem
 Usage   :
 Function:
           Returns a value if the there are known problems in mapping
	   the variation from internal coordinates to EMBL clone
	   coordinates.

 Returns : A string
 Args    : A string (optional, for setting)

=cut

sub position_problem {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'position_problem'} = $value;
    }
   if( ! exists $obj->{'position_problem'} ) {
       return undef;
   }
   return $obj->{'position_problem'};
}


=head2 upStreamSeq

 Title   : upStreamSeq
 Usage   : $obj->upStreamSeq();
 Function:

            Sets and returns upstream flanking sequence string.
            If value is not set, returns undef.

 Example :
 Returns : string or undef
 Args    : string

=cut


sub upStreamSeq {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'upstreamseq'} = $value;
  }
   if( ! exists $obj->{'upstreamseq'} ) {
       return undef;
   }
   return $obj->{'upstreamseq'};

}


=head2 dnStreamSeq

 Title   : dnStreamSeq
 Usage   : $obj->dnStreamSeq();
 Function:

            Sets and returns dnstream flanking sequence string.
            If value is not set, returns undef.

 Example :
 Returns : string or undef
 Args    : string

=cut


sub dnStreamSeq {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'dnstreamseq'} = $value;
  }
   if( ! exists $obj->{'dnstreamseq'} ) {
       return undef;
   }
   return $obj->{'dnstreamseq'};

}

sub original_strand {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'original_strand'} = $value;
  }
   if( ! exists $obj->{'original_strand'} ) {
       return undef;
   }
   return $obj->{'original_strand'};

}





sub het {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'het'} = $value;
  }
   if( ! exists $obj->{'het'} ) {
       return undef;
   }
   return $obj->{'het'};

}

sub hetse {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'hetse'} = $value;
  }
   if( ! exists $obj->{'hetse'} ) {
       return undef;
   }
   return $obj->{'hetse'};

}










sub _reversed {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'reversed'} = $value;
  }
   if( ! exists $obj->{'reversed'} ) {
       return undef;
   }
   return $obj->{'reversed'};

}



=head2 add_DBLink

 Title   : add_DBLink
 Usage   : $self->add_DBLink($ref)
 Function: adds a link object
 Example :
 Returns :
 Args    :


=cut

sub add_DBLink{
   my ($self,$com) = @_;
   if( ! $com->isa('Bio::Annotation::DBLink') ) {
       $self->throw("Is not a link object but a  [$com]");
   }
   push(@{$self->{'link'}},$com);
}

=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBlink() )
 Function: gets an array of DBlink of objects
 Example :
 Returns :
 Args    :


=cut

sub each_DBLink{
   my ($self) = @_;

   return @{$self->{'link'}} if defined $self->{'link'};
}

=head2 to_FTHelper

 Title   : to_FTHelper
 Usage   :
 Function: creates a L<Bio::SeqIO::FTHelper> object for each allele
           for inclusion to EMBL/GenBank feature table.
 Example :
 Returns : array of Bio::SeqIO::FTHelper objects
 Args    : none


=cut

sub to_FTHelper{
   my ($self) = @_;

   my @fths;
   #foreach my $allele (split /\|/, $self->alleles) {

       # Make new FTHelper, and fill in the key
       my $fth = Bio::SeqIO::FTHelper->new;
       $fth->key('variation');
       # Add location line
       my $g_start = $self->start;
       my $g_end   = $self->end;
       my $loc = "$g_start..$g_end";
       if ($self->strand == -1) {
	   $loc = "complement($loc)";
       }
       $fth->loc($loc);
       #/replace="text" 
       $fth->add_field('replace', $self->alleles);
       #/db_xref="<database>:<identifier>"
       foreach my $link ($self->each_DBLink) {
	   if ($link->database eq 'dbSNP' or 
	       $link->database eq 'HGBASE' or 
	       $link->database eq 'TSC-CSHL' ) {
	       $fth->add_field('db_xref', $link->database.':'.$link->primary_id);
	   }
       }
       #/evidence=<evidence_value>
       my $evidence = 'not_experimental';
       $evidence = 'experimental' if $self->status eq 'proven';
       $fth->add_field('evidence', $evidence);
       if( $self->het ) { 
	   $fth->add_field('note',"heterozygosity=".$self->het);
	   $fth->add_field('note',"heterozygosity_std_error=".$self->hetse);
       }
       push @fths, $fth;
   #}

   return @fths;
}

1;
