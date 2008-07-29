package Data::Bio::Text::Feature::WIG;
use strict;
use Data::Bio::Text::Feature;
use vars qw(@ISA);
@ISA = qw(Data::Bio::Text::Feature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { return -1;}
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub score { my $self = shift; return $self->{'__raw__'}[3]; }
sub id { my $self = shift; return $self->{'__raw__'}[4]; }


1;
