#!/bin/sh -x
# -*- mode: sh; -*-
# $Id$

if [ $# -lt 1 ]  ; then
    echo "Usage: $0 *.gz > outputfile 2>logfile" >&2
    exit 2
fi

clean_blast=clean-blast.pl
gunzip -c "$@" | $clean_blast
