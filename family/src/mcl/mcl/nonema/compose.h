/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef nonema_compose_h__
#define nonema_compose_h__

#include "matrix.h"

mclVector* mclMatrixVectorDenseCompose
(  
   const mclMatrix*        mx
,  const mclVector*        vecs
,  mclVector*              vecd
)  ;


mclVector* mclMatrixVectorCompose
(  
   const mclMatrix*        mx
,  const mclVector*        vecs
,  mclVector*              vecd
,  mclVector*              ivpVec
)  ;


mclMatrix* mclMatrixCompose
(  
   const mclMatrix*        m2
,  const mclMatrix*        m1
,  int                     maxDensity
)  ;


#endif
