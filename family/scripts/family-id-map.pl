#!/usr/local/bin/perl
#
# Usage: 
#
#   family-id-map.pl -old 'dbname=foo_110;host=bar;user=jsmith;pass=secret' \
#                    -new 'dbname=foo_120;host=bar;user=jsmith;pass=secret' \
#                     > ids.map
# can leave out the password and host if mysql doesn't need them.
#
#
# Prints real mappings (newly assigned ENSF, "\t", existing ENSF), and
# profuse statistics to stderr
#

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;

use strict;
use Carp;
use Bio::EnsEMBL::DBLoader;
use Getopt::Long;

my $olddb;
my $newdb;

my $minperc = 10;                       # default

die "couldn't parse arguments; see source code for valid options" unless
&GetOptions( 
            'old:s' => \$olddb, # to map from
            'new:s' => \$newdb, # to map to
            'minperc:s' => \$minperc # a max. overlap of less than this N
                                     # percent isn't good enough
           );

die "need both -old and -new options" unless ($olddb && $newdb);

$olddb = Bio::EnsEMBL::DBSQL::DBAdaptor->new( db_parse_connect($olddb));
$olddb = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($olddb);
warn "connected to olddb\n";

$newdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new( db_parse_connect($newdb));
$newdb = Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($newdb);
warn "connected to newdb\n";

my @oldfams = $olddb->all_Families();
my $old_n=@oldfams;
warn "got $old_n old families\n";

my @newfams = $newdb->all_Families();
my $new_n=@newfams;
warn "got $new_n new families\n";

@oldfams = sort by_decr_size @oldfams;  # start with biggest, for speed
@newfams = sort by_decr_size @newfams;

sub by_decr_size {
    return $b->size <=> $a->size;
}

my %overlap;                            # cache for the overlap matrix


# Do it in a greedy way: find best match between old and new, tick
# them off, then go on.
my @unmapped_old=();
my $current=0;
while( my $old = shift @oldfams ) {
    print STDERR "$current/$old_n "; $current++;
#    warn "working on old ", $old->id, "\n";
    my ($bestfam, $bestn, $perc)  = find_best($old, \@newfams);
    if ($perc > $minperc) {                   # overlap percentage

        if ($perc < $minperc + 10) {
            my ($old, $new)=($old->id, $bestfam->id);
            warn "low overlap: $new -> $old: $perc %\n";
        }

        my $removed = splice (@newfams, $bestn, 1);
        unless ($removed == $bestfam) {
            die "can't be" ;
        }

        # announce the mapping:
        print $bestfam->id, "\t", $old->id, "\n";
        ### maybe make this:
        ###   print $bestfam->internal_id, "\t", $old->id, "\n";
        ### later on.
        
        ### if you're curious about the annotations themselves:
        my ($newd, $news, $oldd, $olds) = 
          (substr($bestfam->description, 0, 30), 
           $bestfam->annotation_confidence_score, 
           substr($old->description, 0, 30), $old->annotation_confidence_score);
        print STDERR " ", $bestfam->id, "\t", $old->id, "($newd [$news] $oldd [$olds])\n";
        # (this completes the line start at top of while loop)
    } else { 
        # these are the loosers, won't map them, sniff.
        push @unmapped_old, $old->id;
    }
}                                       # end main loop
# remainder is unmapped new:
my @unmapped_new=grep($_ = $_->id, @newfams);

# assign them continuing from the max:
my $new_id = $olddb->get_max_id; $new_id++;
foreach (@unmapped_new) {
    print "$_\t$new_id\n";
    $new_id++;
}

# some blurps:
printf STDERR  "# No mapping for old ids: (%d/%d=%.2g %%)\n", 
  int(@unmapped_old),  $old_n,    100*int(@unmapped_old)/$old_n;
warn join("\n", @unmapped_old), "\n";

printf STDERR  "# No mapping for new ids: (%d/%d=%.2g %%)\n", 
  int(@unmapped_new),  $new_n,    100*int(@unmapped_new)/$new_n;
warn join("\n", @unmapped_new), "\n";


1;

sub find_best { 
# returns the best match + index for easy removal
    my ($oldfam, $new_listref)=@_;

    my ($i, $besti, $bestoverlap) = (0, 0, -999);
    my $bestfam;

  FAM:
    foreach my $fam ( @$new_listref ) { 
        my $overlap=calc_overlap($oldfam, $fam);
        if ($overlap  > $bestoverlap) {
            $bestoverlap=$overlap;
            $bestfam=$fam;
            $besti=$i;
        }
        if ($overlap >= 50) {           # can't be bettered; 3 x speedup
#            warn "found > 50\n";
            last FAM;
        }
        $i++;
    }
    return ($bestfam, $besti, $bestoverlap);
}

# returns the percentage overlap (as (A intersect B) / (A union B)).
sub calc_overlap {
    my ($oldfam, $newfam) = @_;

#    warn "DEBUG: ", $oldfam->id, "->", $newfam->id, "\n";

    my @set_sizes = overlap_per_db($oldfam, $newfam, 'SPTR');
    my ($old, $new, $union, $intersect, $perc ) = @set_sizes;

#    printf STDERR "\tSPTR: old:$old new:$new union:$union intersect:$intersect perc:%.3g\n"
#      , $perc;

    if ($perc >= 50) {                 # can't be bettered
#        warn "SPTR>50\n";
        return $perc;
    } # can't be bettered
    
    my ($perc2);

    @set_sizes = overlap_per_db($oldfam, $newfam, 'ENSEMBLPEP');
    ($old, $new, $union, $intersect, $perc2 ) = @set_sizes;

#    printf STDERR  "\tENS: old:$old new:$new union:$union intersect:$intersect perc:%.3g\n"
#      , $perc2;
    
    return ($perc2 > $perc)? $perc2 : $perc;
}

sub overlap_per_db {
    my($oldfam, $newfam, $db) = @_;

    my @old_ones = map { $_->primary_id } $oldfam->each_member_of_db($db);
    my @new_ones = map { $_->primary_id } $newfam->each_member_of_db($db);

    my ( $old, $new, $union, $intersect, $perc) 
      = set_sizes(\@old_ones, \@new_ones);
    if ($union > 0) {
        $perc = 100*($intersect/$union);
    } else { 
        $perc=0;
    }
    return ( $old, $new, $union, $intersect, $perc);
}

# sizes of sets contained in listrefs $a, $b, union($a, $b), intersection($a,$b)
sub set_sizes {
    my ($a, $b) = @_;
    my (%h);

    foreach  ( @$a ) {
        $h{$_}++;
        die "$_: duplicates" if $h{$_} > 1;
    }

    foreach  ( @$b ) {
        $h{$_}--;
        die "$_: duplicates" if $h{$_} < -1;
    }
    my @union=keys %h;
    my @intersect = grep( $h{$_} == 0, @union);
    return ( int(@$a), int(@$b), int(@union), int(@intersect));
}

## Parse string that looks like
## "dbname=foo;host=bar;user=jsmith;pass=secret", into something
## useable for passing to Bio::EnsEMBL::DBSQL::DBAdaptor->new();
sub db_parse_connect { 
    my ($connect) = @_;

    croak "`$connect': should look like \"dbname=foo;host=bar;user=jsmith;pass=secret\"" 
      unless ($connect  =~ /dbname=/ && $connect =~ /user=/);

    my %keyvals= split('[=;]', $connect);
    $keyvals{'-driver'}='mysql';
    %keyvals;
}    

