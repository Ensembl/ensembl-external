#!/usr/local/bin/perl
#$Id$

# script to translate ens peptide ids; expects a file with lines
# ^OLD:NEW$ to do mapping.

# Note: after this, the original format bug has been removed from the input

$Usage = "$0 mapping-file < original > new";
die $Usage if (@ARGV <1);

$mapfile=shift(@ARGV);
open(MAP, "<$mapfile") || die $!;

%mapping = ();
while ( <MAP> ) {
    chomp;
    ($old,$new)=split "\t";
#warn $old, ":", $new;
    die "wrong format: '$_' ; expecting old<TAB>new" unless $old and $new;
    $mapping{$old}=$new;
}
die "no mappings !?!" unless %mapping;

my @id_prefixes = qw(ENSP COBP PGBP);

#warn "checking for all id with prefixes ", join(' ', @id_prefixes). "\n";

# now process file
while (<>) {
    chomp;
    $line = $_;
    my ($fam_id, $desc, $score, $mems, $dummy, $mems2)= split '\t';
    
    ### work around bug in format:
    if ( $mems !~ /^:/) {
        my $s = "$mems $dummy $mems2";
        ($mems) = ( $s =~ /(:.*)$/);
    }
    
    my @mems = split(':', $mems);
    shift @mems;                    # superfluous ':' at start.
    die "no members: $_" unless @mems;

    my @newmems=();
    my $new; 
    foreach $mem (@mems) {
#warn $mem;
        if ( grep $mem =~ /^$_/,@id_prefixes ) {

            $new = $mapping{$mem};
#warn $new;
            if (!$new) {
                die "didn't find mapping for $mem\n$line";
            }
        } else {
            $new=$mem;
        }
        push(@newmems, $new);
    }
#warn "old: @mems";
#warn "new: @newmems";

    print join("\t", $fam_id, $desc, $score, ":".join(":", @newmems)), "\n";
}                                       # while
