

#ifndef NONEMA_COMPOSE_H
#define NONEMA_COMPOSE_H

#include "nonema/matrix.h"

/*
 *
*/

mcxVector* mcxMatrixVectorDenseCompose
(  
   const mcxMatrix*        mx
,  const mcxVector*        vecs
,  mcxVector*              vecd
)  ;


mcxVector* mcxMatrixVectorCompose
(  
   const mcxMatrix*        mx
,  const mcxVector*        vecs
,  mcxVector*              vecd
,  mcxVector*              ivpVec
)  ;


mcxMatrix* mcxMatrixCompose
(  
   const mcxMatrix*        m2
,  const mcxMatrix*        m1
,  int                     maxDensity
)  ;


#endif
