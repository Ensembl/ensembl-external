/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <math.h>
#include <float.h>
#include <stdlib.h>

#include "dpsd.h"
#include "interpret.h"

#include "nonema/ivp.h"
#include "util/minmax.h"
#include "util/alloc.h"
#include "util/types.h"

float    dpsd_delta            =     12 * FLT_EPSILON;

mclMatrix* mcxDiagOrdering
(  const mclMatrix*     M
,  mclVector**          vecp_attr
)  {
      int         N_cols      =  M->N_cols
   ;  mclMatrix*  diago       =  mclMatrixAllocZero(N_cols, N_cols)  
   ;  mclVector*  mask        =  mclVectorCreate(1)  
   ;  int         col

   ;  (mask->ivps+0)->val     =  1.0
   ;  if (*vecp_attr != NULL)
      {  mclVectorFree(vecp_attr)
   ;  }

   ;  *vecp_attr = mclVectorInstantiate(*vecp_attr, N_cols, NULL)

   ;  for (col=0;col<N_cols;col++)
      {  int      offset      =  -1
      ;  float    selfval     =  mclVectorIdxVal(M->vectors+col, col, &offset)
      ;  float    center      =  mclVectorPowSum(M->vectors+col, 2.0)
     /*  float    maxval      =  mclVectorMaxValue(M->vectors+col)
      */
      ;  float    bar         =  MAX(center, selfval) - dpsd_delta
      ;  mclIvp*  ivp         =  (*vecp_attr)->ivps+col

      ;  ivp->idx             =  col
      ;  ivp->val             =  center ? selfval / center : 0

      ;  (mask->ivps+0)->idx  =  col      /* no diagonal values in diago */
#if 0
                                          /* 0 == negative mask */
      ;  mclVectorMaskedCopy(diago->vectors+col, M->vectors+col, mask, 1)
#endif
                                          /* loop exists */
      ;  if (offset >= 0)                 /* take only higher valued entries */
         {  mclVectorSelectGqBar(diago->vectors+col, bar)
      ;  }
   ;  }
   ;  return diago
;  }



