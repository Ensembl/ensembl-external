/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef intalg_la_h__
#define intalg_la_h__

#include "ilist.h"

#include "nonema/matrix.h"


mclMatrix*     genMatrix
(  Ilist*   pblock
,  float    p
,  float    q
,  double   ppower
,  double   qpower
)  ;


mclMatrix*     mclMatrixPermute
(  mclMatrix*  src
,  mclMatrix*  dst
,  Ilist*   il_col
,  Ilist*   il_row
)  ;


mclVector*   mclVectorFromIlist
(  mclVector*  vec
,  Ilist*      il
,  float       f
)  ;  


mclMatrix*     genClustering
(  Ilist*   pblock
)  ;


int   idxShare
(  const   mclVector*   v1
,  const   mclVector*   v2
,  mclVector*           m
)  ;

#endif


