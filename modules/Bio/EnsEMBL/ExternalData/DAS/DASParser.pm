# BioPerl module for DAS
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

DAS - DESCRIPTION of Object

=head1 DESCRIPTION

Internal DAS XML parser specialized for feature getting. Needed becasue
Expat keep crashing our web servers...

Create a new event parser object that will return a list of DasSeqFeatures (I hope).

=head1 CONTACT

 Tony Cox <avc@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::ExternalData::DAS::DASParser;

use strict;
use vars qw(@ISA);
use XML::Parser;
use XML::Parser::Lite;
use Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::Root::RootI);

# yuck - but is there any other way?
my $CURRENT_ELEMENT = undef;
my $CURRENT_FEATURE = undef;
my @FEATURE_LIST    = ();
my $SEGMENT_ID      = undef;
my $SEGMENT_START   = undef;
my $SEGMENT_STOP    = undef;
my $SEGMENT_VERSION = undef;
my $SEGMENT_LABEL   = undef;
my $DSN             = undef;

sub new {
	my($class,$adaptor) = @_;
	my $self;
	$self = {};
	bless $self, $class;

	my $parser = new XML::Parser::Lite;
    
    $parser->setHandlers(
        Start => \&Bio::EnsEMBL::ExternalData::DAS::DASParser::handleStart,
        Char  => \&Bio::EnsEMBL::ExternalData::DAS::DASParser::handleChar,
        End   => \&Bio::EnsEMBL::ExternalData::DAS::DASParser::handleEnd,
    );
        
    $self->parser($parser);
    
	return $self; # success - we hope!

}

sub parser {
    my ($self, $p) = @_;
    if (defined $p){
    	$self->{'_parser'} = $p;
    }
    return ($self->{'_parser'});
}

sub parse {
    my ($self, $xml, $dsn) = @_;
	@FEATURE_LIST =();
    $DSN = $dsn;
    my $p = $self->parser();
    $p->parse($xml);
    return(@FEATURE_LIST);
}

sub handleStart {
    my ($p,$element,%attr) = @_;
    
    $CURRENT_ELEMENT = $element;
    
    if ($element eq "SEGMENT"){
        $SEGMENT_ID      = $attr{'id'};
        $SEGMENT_START   = $attr{'start'};
        $SEGMENT_STOP    = $attr{'stop'};
        $SEGMENT_VERSION = $attr{'version'};
        $SEGMENT_LABEL   = $attr{'label'};
    }
    if ($element eq "FEATURE"){
        $CURRENT_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
        $CURRENT_FEATURE->das_feature_id($attr{'id'});
        $CURRENT_FEATURE->das_feature_label($attr{'label'});
        
        $CURRENT_FEATURE->das_segment_id($SEGMENT_ID);
        $CURRENT_FEATURE->das_segment_start($SEGMENT_START);
        $CURRENT_FEATURE->das_segment_stop($SEGMENT_STOP);
        $CURRENT_FEATURE->das_segment_version($SEGMENT_VERSION);
        $CURRENT_FEATURE->das_segment_label($SEGMENT_LABEL);
        # compatibility methods...
        $CURRENT_FEATURE->das_id($attr{'id'});
        $CURRENT_FEATURE->das_dsn($DSN);
        $CURRENT_FEATURE->source_tag($DSN);
        $CURRENT_FEATURE->primary_tag('das');
#        print STDERR "Storing $CURRENT_FEATURE (", $CURRENT_FEATURE->das_id(), ")\n";
    }
    if ($element eq "TYPE"){
        $CURRENT_FEATURE->das_type_id($attr{'id'});
        $CURRENT_FEATURE->das_type_category($attr{'category'});
        $CURRENT_FEATURE->das_type_reference($attr{'reference'});
        $CURRENT_FEATURE->das_type_subparts($attr{'subparts'});
        $CURRENT_FEATURE->das_type_superparts($attr{'superparts'});
        # compatibility methods...
        $CURRENT_FEATURE->das_name($attr{'id'});
    }
    if ($element eq "METHOD"){
        $CURRENT_FEATURE->das_method_id($attr{'id'});
    }
    if ($element eq "LINK"){
        $CURRENT_FEATURE->das_link_href($attr{'href'});
    }
    if ($element eq "GROUP"){
        $CURRENT_FEATURE->das_group_id($attr{'id'});
        $CURRENT_FEATURE->das_group_label($attr{'label'});
        $CURRENT_FEATURE->das_group_type($attr{'type'});
    }
    if ($element eq "TARGET"){
        $CURRENT_FEATURE->das_target_id($attr{'id'});
        $CURRENT_FEATURE->das_target_start($attr{'start'});
        $CURRENT_FEATURE->das_target_stop($attr{'stop'});
    }
    #if ($element eq "START"){
    #}
    #if ($element eq "END"){
    #}
    #if ($element eq "SCORE"){
    #}
    #if ($element eq "ORIENTATION"){
    #}
    #if ($element eq "PHASE"){
    #}
}

sub handleChar {
    my ($p,$text) = @_;
    
    if ($CURRENT_ELEMENT eq "TYPE"){ 
        $CURRENT_FEATURE->das_type($text);
    } elsif ($CURRENT_ELEMENT eq "METHOD") { 
        $CURRENT_FEATURE->das_method($text);
    } elsif ($CURRENT_ELEMENT eq "START") {
#		print STDERR "start: $text "; 
        $CURRENT_FEATURE->das_start($text);
    } elsif ($CURRENT_ELEMENT eq "END") { 
#		print STDERR "end: $text "; 
        $CURRENT_FEATURE->das_end($text);
    } elsif ($CURRENT_ELEMENT eq "SCORE") {
        $CURRENT_FEATURE->das_score($text);
    } elsif ($CURRENT_ELEMENT eq "ORIENTATION") { 
#		print STDERR "ori: $text\n"; 
		$CURRENT_FEATURE->das_orientation($text);    
    } elsif ($CURRENT_ELEMENT eq "PHASE") {
        $CURRENT_FEATURE->das_phase($text);
    } elsif ($CURRENT_ELEMENT eq "NOTE") {
        $CURRENT_FEATURE->das_note($text);
    } elsif ($CURRENT_ELEMENT eq "LINK") {
        $CURRENT_FEATURE->das_link($text);
    } elsif ($CURRENT_ELEMENT eq "TARGET") {
        $CURRENT_FEATURE->das_target($text);
    } elsif ($CURRENT_ELEMENT eq undef) {
        # we throw away any text...
    }  
}

sub handleEnd {
    my ($p,$element) = @_;
    if ($element eq "FEATURE"){
        ## finished with this feature, so save it....
        #print STDERR "Saving $CURRENT_FEATURE (", $CURRENT_FEATURE->das_segment_id(), ")\n";
        #print STDERR "Saving $CURRENT_FEATURE (", $CURRENT_FEATURE->das_feature_id(), ")\n";
        #print STDERR "Saving $CURRENT_FEATURE (", $CURRENT_FEATURE->das_type_id(), ")\n";
        push(@FEATURE_LIST, $CURRENT_FEATURE);
    }
    $CURRENT_ELEMENT = undef;
}

1;
