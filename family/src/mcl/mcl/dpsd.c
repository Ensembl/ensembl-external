
/*
// dpsd.c                  Interpretation of clusterings 
*/

#include <math.h>
#include <float.h>
#include <stdlib.h>

#include "nonema/ivp.h"
#include "util/minmax.h"
#include "util/alloc.h"
#include "util/types.h"
#include "mcl/dpsd.h"
#include "mcl/interpret.h"

float    dpsd_delta            =     12 * FLT_EPSILON;

mcxMatrix* mcxDiagOrdering
(  const mcxMatrix*     M
,  mcxVector**          vecp_attr
)  {
      int         N_cols      =  M->N_cols
   ;  mcxMatrix*  diago       =  mcxMatrixAllocZero(N_cols, N_cols)  
   ;  mcxVector*  mask        =  mcxVectorCreate(1)  
   ;  int         col

   ;  (mask->ivps+0)->val     =  1.0
   ;  if (*vecp_attr != NULL)
      {  mcxVectorFree(vecp_attr)
   ;  }

   ;  *vecp_attr = mcxVectorInstantiate(*vecp_attr, N_cols, NULL)

   ;  for (col=0;col<N_cols;col++)
      {  int      offset      =  -1
      ;  float    selfval     =  mcxVectorIdxVal(M->vectors+col, col, &offset)
      ;  float    center      =  mcxVectorPowSum(M->vectors+col, 2.0)
     /*  float    maxval      =  mcxVectorMaxValue(M->vectors+col)
      */
      ;  float    bar         =  float_MAX(center, selfval) - dpsd_delta
      ;  mcxIvp*  ivp         =  (*vecp_attr)->ivps+col

      ;  ivp->idx             =  col
      ;  ivp->val             =  center ? selfval / center : 0

      ;  (mask->ivps+0)->idx  =  col      /* no diagonal values in diago */
#if 0
                                          /* 0 == negative mask */
      ;  mcxVectorMaskedCopy(diago->vectors+col, M->vectors+col, mask, 1)
#endif
                                          /* loop exists */
      ;  if (offset >= 0)                 /* take only higher valued entries */
         {  mcxVectorSelectGqBar(diago->vectors+col, bar)
      ;  }
   ;  }
   ;  return diago
;  }



