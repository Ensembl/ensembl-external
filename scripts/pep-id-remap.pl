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
    ($old,$new)=split ':';
    die "wrong format: '$_' ; expecting old:new" unless $old and $new;
    $mapping{$old}=$new;
}
die "no mappings !?!" unless %mapping;

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
        if ($mem =~ /^ENSP/) { 
            $new = $mapping{$mem};
            if (!$new) {
                die "didn't find mapping for $mem\n$line";
            }
        } else {
            $new=$mem;
        }
        push(@newmems, $new);
    }

    print join("\t", $fam_id, $desc, $score, ":".join(":", @newmems)), "\n";
}                                       # while
