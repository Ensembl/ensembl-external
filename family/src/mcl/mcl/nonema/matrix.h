/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef nonema_matrix_h
#define nonema_matrix_h

#include <stdio.h>

#include "ivp.h"
#include "vector.h"
#include "floatops.h"


typedef struct
{  
   mclVector*     vectors
;  int            N_cols
;  int            N_rows
;
}  mclMatrix      ;


mclMatrix* mclMatrixAllocZero
(  int            N_cols
,  int            N_rows
)  ;


mclMatrix* mclMatrixComplete
(  int            N_cols
,  int            N_rows
,  float          val
)  ;


mclMatrix*  mclMatrixSub
(  const mclMatrix*     mx
,  const mclVector*     colSelect
,  const mclVector*     rowSelect
)  ;


mclMatrix* mclMatrixIdentity
(  int            N_cols
)  ;


mclMatrix* mclMatrixConstDiag
(  int            N_cols
,  float          c
)  ;


mclMatrix* mclMatrixCopy
(  const mclMatrix*        mx
)  ;


void mclMatrixFree
(  mclMatrix**    mx
)  ;


mclMatrix* mclMatrixDiag
(  int                     dimen
,  float                   f
,  mclIvp*                 ivps
,  int                     n_ivps
)  ;


int mclMatrixEqualMatrices
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  ;


void mclMatrixMakeSparse
(  mclMatrix*              mtx
,  int                     maxDensity
)  ;


void mclMatrixMakeStochastic
(  mclMatrix*              mx
)  ;


mclMatrix* mclMatrixTranspose
(  const mclMatrix*        src
)  ;


void mclMatrixMakeCharacteristic
(  mclMatrix*              mtx
)  ;

void mclMatrixHdp
(  mclMatrix*              mx
,  float                   power
)  ; 


int mclMatrixSubNrofEntries
(  const mclMatrix*        m
,  const mclVector*        colSelect
,  const mclVector*        rowSelect
)  ;


int mclMatrixNrofEntries
(  const mclMatrix*        m
)  ;


float mclMatrixSubMass
(  const mclMatrix*        m
,  const mclVector*        colSelect
,  const mclVector*        rowSelect
)  ;


float mclMatrixMass
(  const mclMatrix*        m
)  ;


void mclMatrixUnary
(  mclMatrix*              m1
,  float                   (*operation)(float, void*)
,  void*                   arg
)  ;


mclMatrix* mclMatrixMax
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  ;


mclMatrix* mclMatrixAdd
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  ;


mclMatrix* mclMatrixHadamard
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  ;



void mclMatrixInflate
(  mclMatrix*           mx
,  float             power
)  ;


mclMatrix* mclMatrixBinary
(  const mclMatrix*        m1
,  const mclMatrix*        m2
,  float                   (*operation)(float, float)
)  ;


float mclMatrixMaxValue
(  const mclMatrix*        m
)  ;


void mclMatrixScale
(  const mclMatrix*        m
,  float                   f
)  ;



mclVector* mclMatrixVectorSums
(  mclMatrix*     m
)  ;


void  mclMatrixRealignVectors
(  mclMatrix*     m
,  int            (*cmp) (const void *, const void *)
)  ;



#endif /* NONEMA_MATRIX_H */

