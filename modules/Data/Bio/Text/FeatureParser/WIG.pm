package Data::Bio::Text::FeatureParser::WIG;

=head1 NAME

Data::Bio::Text::FeatureParser::WIG;

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
use Data::Bio::Text::Feature::WIG;
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
	my $current_key = $self->{'_current_key'} ; 

        if ($row =~ /variableStep\s+chrom=([^\s]+)(\s+span=)?(\d+)?/i) {
	    my $wigConfig = {
		'format' => 'v',
		'region' => $1,
		'span' => $3 || 1,
	    };
	    $self->{'tracks'}{ $current_key }->{'mode'} = $wigConfig;
        } elsif ($row =~ /fixedStep\s+chrom=(.+)\s+start=(\d+)\s+step=(\d+)(\s+span=)?(\d+)?/i) {
	    my $wigConfig = {
		'format' => 'f',
		'region' => $1,
		'span' => $5 || 1,
		'start' => $2,
		'step' => $3,
	    };
	    $self->{'tracks'}{ $current_key }->{'mode'} = $wigConfig;
	} else {
	    my @ws_delimited = split /\s+/, $row;
	    push @ws_delimited, $ws_delimited[0];

	    my $wigConfig = $self->{'tracks'}{ $current_key }->{'mode'};
	    if ($wigConfig->{format}) {
		if ($wigConfig->{format} eq 'v') {
		    $self->store_feature( $current_key , Data::Bio::Text::Feature::WIG->new( [$wigConfig->{'region'}, $ws_delimited[0], $ws_delimited[0] + $wigConfig->{span} - 1, $ws_delimited[1], $ws_delimited[2]] ));
		    
		}elsif ($wigConfig->{format} eq 'f') {
		    $self->store_feature( $current_key , Data::Bio::Text::Feature::WIG->new( [$wigConfig->{'region'}, $wigConfig->{start}, $wigConfig->{start} + $wigConfig->{span} - 1, $ws_delimited[0], $ws_delimited[1]] ));
		    $self->{'tracks'}{ $current_key }->{'mode'}->{'start'} += $wigConfig->{step};
		}
	    } else {
		$self->store_feature( $current_key , Data::Bio::Text::Feature::WIG->new( \@ws_delimited ));
	    }
	}
    } 
}

1;
