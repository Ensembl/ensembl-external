#!/usr/bin/env bash
# $Id$
### do statistics on the conflicts found when loading TRIBE families:

usage="Usage: $0 file-with-log-output-from-family-input.pl"
if [ $# -ne 1  ]; then
     echo $usage; exit 1;
fi

file=$1

echo -n Totals:
grep "^inserted" $file

echo -n 'Total number of "one gene, several family" conflicts':
grep "^### assigning" $file| wc -l

echo -n "conflicts resolved by choosing second (or later) assignment:"
grep "^### replacing " $file | wc -l

leaving=`grep "^### leaving " $file | wc -l`
notbetter=`grep "^### alternative " $file | wc -l`
echo "conflicts resolved by choosing first assignment:" $notbetter
echo "undecided conflicts (first assignment kept)" $[leaving - notbetter]

echo

user=ensro
dbname=family100
host=ecs1b

brackets="1-1 2-10 11-100 101-1000 1001-10000"

echo "Histogram of family sizes:"
for b in $brackets; do
    echo -n "$b: "
    echo $b | awk -F'-' \
     '{print "select sum(occurrences) from cumulative_distrib where family_size between ",$1," and ",$2}' |\
        mysql -u $user -h $host $dbname | grep -v 'sum'
done

