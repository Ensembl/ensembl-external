/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef intalg_ilist_h__
#define intalg_ilist_h__

#include <stdlib.h>
#include <stdio.h>

#include "util/equate.h"

typedef struct
{  int*  list
;  int   n
;
}  Ilist ;


Ilist*   ilInit
(  Ilist*   il
)  ;


Ilist*   ilInstantiate
(  Ilist*   il
,  int      n
,  int*     ints
,  int      c
)  ;


Ilist*   ilVA
(  Ilist*   il
,  int      k
,  ...
)  ;


Ilist*   ilNew
(  int   n
,  int*  ints
,  int   c
)  ;


Ilist*   ilComplete
(  Ilist*   il
,  int      n
)  ;


int ilWriteFile
(  const Ilist*   il
,  FILE*          f_out
)  ;


Ilist*   ilReadFile
(  Ilist*         dst_il
,  FILE*          f_in
)  ;


Ilist*   ilStore
(  Ilist*   dst
,  int*     ints
,  int      n
)  ;


Ilist*   ilInvert
(  Ilist*   src
)  ;


Ilist*   ilCon
(  Ilist*   dst
,  int*     list
,  int      n
)  ;

int   ilIsOneOne
(  Ilist*   src
)  ;

int   ilIsNonDescending
(  Ilist*   src
)  ;

int   ilIsAscending
(  Ilist*   src
)  ;

int   ilIsNonAscending
(  Ilist*   src
)  ;

int   ilIsDescending
(  Ilist*   src
)  ;

int   ilIsMonotone
(  Ilist*   src
,  int      gradient
,  int      min_diff
)  ;

void     ilResize
(  Ilist*   il
,  int      n
)  ;


void    ilPrint
(  Ilist*   il
,  const char msg[]
)  ;


void   ilAccumulate
(  Ilist*   il
)  ;


int      ilSqum
(  Ilist*   il
)  ;

int      ilSum
(  Ilist*   il
)  ;


void     ilTranslate
(  Ilist*   il
,  int      dist
)  ;


Ilist*     ilRandPermutation
(  int      lb
,  int      rb
)  ;


/*
// these three do not belong here,
// should rather be part of revised stats package
// or something alike.
*/

float      ilAverage
(  Ilist*   il
)  ;

float   ilCenter
(  Ilist*   il
)  ;

float      ilDeviation
(  Ilist*   il
)  ;


void     ilFree
(  Ilist**  ilp
)  ;

void  ilSort
(  Ilist*   il
)  ;

void  ilRevSort
(  Ilist*   il
)  ;

Ilist* ilLottery
(  int      lb
,  int      rb
,  float    p
,  int      times
)  ;


int ilSelectRltBar
(  Ilist*   il
,  int      i1
,  int      i2
,  int      (*rlt1)(const void*, const void*)
,  int      (*rlt2)(const void*, const void*)
,  int      onlyCount
)  ;



int ilSelectGqBar
(  Ilist*   il
,  int      ilft
)  ;


int ilSelectLtBar
(  Ilist*   il
,  int      irgt
)  ;


int ilCountLtBar
(  Ilist*   il
,  int      ilft
)  ;


                               /* create random partitions at grid--level */
Ilist*  ilGridRandPartitionSizes
(  int      w
,  int      gridsize
)  ;

                               /* create random partition */
Ilist*     ilRandPartitionSizes
(  int      w
)  ;

#endif

