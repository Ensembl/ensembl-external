#!/bin/sh -x
# -*- mode: sh; -*-
# $Id$
#
# Concatenates all the raw pre-parsed BLAST output into one big file, then
# pre-parses it a bit more to remove further cruft.
#
# (the 'raw pre-parsed BLAST output' parsing was done with scripts/parse,
# as part of the lsf job on the farm. It basically removes the alignments)
#

if [ $# -lt 1 ]  ; then
    echo "Usage: $0 *.gz > outputfile 2>logfile" >&2
    exit 2
fi

clean_blast=clean-blast.pl
gunzip -c "$@" | $clean_blast
