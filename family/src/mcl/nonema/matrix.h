

#ifndef NONEMA_MATRIX_H
#define NONEMA_MATRIX_H

#include <stdio.h>
#include "nonema/ivp.h"
#include "nonema/vector.h"


/*
 *
 *
*/


typedef struct
{  
   mcxVector*     vectors
;  int            N_cols
;  int            N_rows
;
}  mcxMatrix      ;



/*
 *
 *
*/


mcxMatrix* mcxMatrixAllocZero
(  
   int            N_cols
,  int            N_rows
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixComplete
(  
   int            N_cols
,  int            N_rows
,  float          val
)  ;


/*
 *
 *
*/


mcxMatrix*  mcxSubmatrix
(  
   const mcxMatrix*     mx
,  const mcxVector*     colSelect
,  const mcxVector*     rowSelect
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixIdentity
(  
   int            N_cols
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixConstDiag
(  
   int            N_cols
,  float          c
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixCopy
(  
   const mcxMatrix*        mx
)  ;



/*
 *
 *
*/


void mcxMatrixFree
(  
   mcxMatrix**    mx
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixDiag
(  
   int                     dimen
,  float                   f
,  mcxIvp*                 ivps
,  int                     n_ivps
)  ;


/*
 *
 *
*/


extern __inline__ mcxMatrix* mcxMatrixIdentity
(  int                     n_rows
)  
   {  
      return mcxMatrixConstDiag(n_rows, 1.0)
;  }


/*
 *
 *
*/


void mcxMatrixMakeSparse
(  
   mcxMatrix*              mtx
,  int                     maxDensity
)  ;


/*
 *
 *
*/


void mcxMatrixMakeStochastic
(  
   mcxMatrix*              mx
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixTranspose
(  
   const mcxMatrix*        src
)  ;


/*
 *
 *
*/


void mcxMatrixMakeCharacteristic
(  
   mcxMatrix*              mtx
)  ;


/*
 *
 *
*/


int mcxSubmatrixNrofEntries
(  
   const mcxMatrix*        m
,  const mcxVector*        colSelect
,  const mcxVector*        rowSelect
)  ;


/*
 *
 *
*/


int mcxMatrixNrofEntries
(  
   const mcxMatrix*        m
)  ;


/*
 *
 *
*/


float mcxSubmatrixMass
(  
   const mcxMatrix*        m
,  const mcxVector*        colSelect
,  const mcxVector*        rowSelect
)  ;


/*
 *
 *
*/


float mcxMatrixMass
(  
   const mcxMatrix*        m
)  ;


/*
 *
 *
*/


void mcxMatrixUnary
(  
   mcxMatrix*              m1
,  float                   (*operation)(float, void*)
,  void*                   arg
)  ;


/*
 *
 *
*/


extern __inline__ void mcxMatrixMakeCharacteristic
(  mcxMatrix*              mx
)  
   {
      float                one         =  1.0
   ;  mcxMatrixUnary(mx, fltConstant, &one)
;  }




/*
 *
 *
*/


mcxMatrix* mcxMatrixMax
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixAdd
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixHadamard
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  ;


/*
 *
 *
*/


mcxMatrix* mcxMatrixBinary
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
,  float                   (*operation)(float, float)
)  ;


/*
 *
 *
*/


extern __inline__ mcxMatrix* mcxMatrixMax
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  
   {  
      return mcxMatrixBinary(m1, m2, fltMax)
;  }


/*
 *
 *
*/


extern __inline__ mcxMatrix* mcxMatrixAdd
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  
   {  
      return mcxMatrixBinary(m1, m2, fltAdd)
;  }


/*
 *
 *
*/


extern __inline__ mcxMatrix* mcxMatrixHadamard
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  {  
      return mcxMatrixBinary(m1, m2, fltMultiply)
;  }



/*
 *
 *
*/


int mcxMatrixEqualMatrices
(  
   const mcxMatrix*        m1
,  const mcxMatrix*        m2
)  ;


/*
 *
 *
*/


float mcxMatrixMaxValue
(  
   const mcxMatrix*        m
)  ;


/*
 *
 *
*/


extern __inline__ float mcxMatrixMaxValue
(  
   const mcxMatrix*        mx
)  
   {  
      float                max_val  =  0.0
   ;  mcxMatrixUnary((mcxMatrix*)mx, fltPropagateMax, &max_val)
   ;  return max_val
;  }


/*
 *
 *
*/


mcxVector* mcxMatrixVectorSums
(  
   mcxMatrix*     m
)  ;


/*
 *
 *
*/


void  mcxMatrixRealignVectors
(  
   mcxMatrix*     m
,  int            (*cmp) (const void *, const void *)
)  ;



#endif /* NONEMA_MATRIX_H */

