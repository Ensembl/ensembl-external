
#ifndef INTALG_LA__
#define INTALG_LA__

#include "intalg/ilist.h"
#include "nonema/matrix.h"

mcxMatrix*     genMatrix
(  Ilist*   pblock
,  float    p
,  float    q
,  double   ppower
,  double   qpower
)  ;


mcxMatrix*     mcxMatrixPermute
(  mcxMatrix*  src
,  mcxMatrix*  dst
,  Ilist*   il_col
,  Ilist*   il_row
)  ;


mcxVector*   mcxVectorFromIlist
(  mcxVector*  vec
,  Ilist*      il
,  float       f
)  ;  


mcxMatrix*     genClustering
(  Ilist*   pblock
)  ;


int   idxShare
(  const   mcxVector*   v1
,  const   mcxVector*   v2
,  mcxVector*           m
)  ;

#endif


