#!/bin/sh
# $Id$

# script producing file suitable for Tony's AltaVista indexing
# Used by wrapper script fam-fulltext.sh

usage="Usage: $0 mysql-args >  file.txt"

if [ $# -lt 1 ] ; then
    echo $usage
    exit 1
fi

sql=./fam-fulltext.sql
mysql=mysql

$mysql "$@" < $sql
exit 0
