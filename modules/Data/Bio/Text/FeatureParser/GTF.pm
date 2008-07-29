package Data::Bio::Text::FeatureParser::GTF;

=head1 NAME

Data::Bio::Text::FeatureParser::GTF;

=head1 SYNOPSIS

This object parses data supplied by the user in BED format and identifies sequence locations for use by other Ensembl objects

=head1 DESCRIPTION

    my $parser = Data::Bio::Text::FeatureParser->new();
    $parser->init($data);
    $parser->parse($data);

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

=cut

use strict;
use warnings;
use Data::Bio::Text::FeatureParser;
use Data::Bio::Text::Feature::GTF;
use Data::Dumper;

our @ISA = qw(Data::Bio::Text::FeatureParser);

#----------------------------------------------------------------------

=head2 parse_row

    Arg [1]   :  
    Function  : Parses an individual row of data, i.e. a single feature
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub parse_row {
    my( $self, $row, $format ) = @_;
    return if ($row =~ /^\#/);
    $row =~ s/[\t\r\s]+$//g;


    if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
	$self->{'browser_switches'}{$1}=$2;     
    }   elsif ($row =~ s/^track\s+(.*)$/$1/i) {
	my %config;
	while( $row ne '' ) {
	    if( $row =~ s/^(\w+)\s*=\s*\"([^\"]+)\"// ) {  
                my $key   = $1;
                my $value = $2;
                while( $value =~ s/\\$// && $row ne '') {
		    if( $row =~ s/^([^\"]+)\"\s*// ) {
			$value .= "\"$1";
		    } else {
			$value .= "\"$row"; 
			$row = '';
		    }
		}
		$row =~ s/^\s*//;
                $config{$key} = $value;
	    } elsif( $row =~ s/(\w+)\s*=\s*(\S+)\s*// ) {
                $config{$1} = $2;
            } else {
                $row ='';
            }
	}
	$config{'name'} ||= 'default';
        my $current_key = $config{'name'}; # || 'default';
        $self->{'tracks'}{ $current_key } = { 'features' => [], 'config' => \%config };
        $self->{'_current_key'} = $current_key;
    } else {
	return unless $row =~ /\d+/g ;
	my @tab_delimited = split /(\t|  +)/, $row;
	my $current_key = $self->{'_current_key'} ;
	$self->store_feature( $current_key, Data::Bio::Text::Feature::GTF->new( \@tab_delimited ) ) 
	    if $self->filter($tab_delimited[0],$tab_delimited[6],$tab_delimited[8]);
    } 
}

1;
