#!/usr/bin/env bash
# $Id$

# Some statistics on families

usage="Usage: $0 family-input.log -h host -u user database "
if [ $# -lt 4  ]; then
     echo $usage; exit 1;
fi

file=$1
shift;
# host=$1
# dbname=$2
# user=$3

echo -n Totals:
grep "^inserted" $file

echo -n 'Total number of "one gene, several family" conflicts':
grep "^### assigning" $file| wc -l

echo -n "conflicts resolved by choosing second (or later) assignment:"
grep "^### replacing " $file | wc -l

leaving=`grep "^### leaving " $file | wc -l`
notbetter=`grep "^### alternative " $file | wc -l`
echo "conflicts resolved by choosing first assignment:" $notbetter
echo "undecided conflicts (first assignment kept):" $[leaving - notbetter]

echo

brackets="0-0 1-1 2-10 11-100 101-1000 1001-10000"

echo "Histogram of family sizes (as far as ensembl peptides are concerned):"
for b in $brackets; do
    echo -n "$b: "
    echo $b | awk -F'-' \
     '{print "select sum(occurrences) from cumulative_distrib where family_size between ",$1," and ",$2}' |\
        mysql "$@" | grep -v 'sum'
done

max=`echo 'select max(num_ens_pepts) from family' |\
    mysql -N --batch "$@"`
echo "Largest family has  $max ensembl members. Row is:"
echo "select * from family where num_ens_pepts = $max;" |\
    mysql "$@"

