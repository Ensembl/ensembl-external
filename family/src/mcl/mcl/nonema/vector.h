/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef nonema_vector_h__
#define nonema_vector_h__

#include <stdio.h>
#include <stdlib.h>
#include <float.h>

#include "floatops.h"
#include "ivp.h"
#include "iface.h"

#include "util/iomagic.h"
#include "util/equate.h"
#include "util/types.h"


enum
{
   KBAR_SELECT_SMALL =  10000
,  KBAR_SELECT_LARGE
}  ;


typedef struct
{
   int                  n_ivps
;  mclIvp*              ivps
;
}  mclVector            ;


void mclVectorAlert
(  const char*          caller
)  ;


mcxstatus mclVectorCheck
(  const mclVector*        vec
,  int                     range
,  mcxOnFail               ON_FAIL
)  ;


mclVector* mclVectorInstantiate
(  mclVector*              dst
,  int                     n_ivps
,  const mclIvp*           ivps
)  ;


mclVector* mclVectorInit
(  mclVector*              vec
)  ;


mclVector* mclVectorCreate
(  int                     nr
)  ;


mclVector* mclVectorResize
(  mclVector*              vec
,  int                     n_ivps
)  ;


mclVector* mclVectorCopy
(  const mclVector*        src
)  ;


void mclVectorFree
(  mclVector**             vec_p
)  ;


mclVector* mclVectorFromData
(  float*                  vals
,  int                     n_vals
)  ;


mclVector* mclVectorComplete
(  mclVector*              dst_vec
,  int                     nr
,  float                   val
)  ;


mclVector* mclVectorMaskedCopy
(  mclVector*              dst
,  const mclVector*        src
,  const mclVector*        msk
,  int                     mask_mode
)  ;


void mclVectorSort
(  mclVector*              vec
,  int                     (*mclIvpCmp)(const void*, const void*)
)  ;


void mclVectorUniqueIdx
(  mclVector*              vec
)  ;


void mclVectorSelectHighest
(  mclVector*              vec
,  int                     max_n_ivps
)  ;


/*
 *    ignore:     when searching k large elements, consider only those elements
 *                that are < ignore. case mode = KBAR_SELECT_LARGE
 *                when searching k small elements, consider only those elements
 *                that are >= ignore. case mode = KBAR_SELECT_SMALL
*/


float mclVectorKBar
(  mclVector               *vec
,  int                     k
,  float                   ignore
,  int                     mode
)  ;


float mclVectorSelectGqBar
(  mclVector*              vec
,  float                   bar
)  ;


float mclVectorSelectNeedsBar
(  mclVector*              vec
,  int                     dest_n_ivps
)  ;


void mclVectorUnary
(  mclVector*              vec
,  float                   (*operation)(float val, void* argument)
,  void*                   argument
)  ;


void mclVectorScale
(  mclVector*              vec
,  float                   fac
)  ;


float mclVectorNormalize
(  mclVector*              vec
)  ;


float mclVectorInflate
(  mclVector*              vec
,  double                  power
)  ;


void mclVectorMakeCharacteristic
(  mclVector*              vec
)  ;


void mclVectorHdp
(  mclVector*              vec
,  float                   pow
)  ;


void mclVectorRemoveIdx
(  mclVector*              vec
,  int                     idx
)  ;


mclVector* mclVectorBinary
(  const mclVector*        src1
,  const mclVector*        src2
,  mclVector*              dst
,  float                   (*operation)(float val1, float val2)
)  ;


mclVector* mclVectorSetMinus
(  const mclVector*           vecl
,  const mclVector*           vecr
,  mclVector*                 dst
)  ;


mclVector* mclVectorSetMerge
(  const mclVector*           lft
,  const mclVector*           rgt
,  mclVector*                 dst
)  ;


mclVector* mclVectorSetMeet
(  const mclVector*           lft
,  const mclVector*           rgt
,  mclVector*                 dst
)  ;


float mclVectorSum
(  const mclVector*           vec
)  ;


float mclVectorPowSum
(  const mclVector*           vec
,  double                     power
)  ;


float mclVectorNorm
(  const mclVector*           vec
,  double                     power
)  ;


float mclVectorMaxValue
(  const mclVector*           vec
)  ;


float mclVectorIdxVal
(  mclVector*                 vec
,  int                        idx
,  int*                       p_offset
)  ;


int mclVectorIdxOffset
(  mclVector*                 vec
,  int                        idx
)  ;


int mclVectorIdxCmp
(  const void*                p1
,  const void*                p2
)  ;


int mclVectorSumCmp
(  const void*                p1
,  const void*                p2
)  ;


int mclVectorIdxRevCmp
(  const void*                p1
,  const void*                p2
)  ;


int mclVectorSumRevCmp
(  const void*                p1
,  const void*                p2
)  ;



#if 0
void mclVectorSelectHighestWithHint
(  mclVector*              vec
,  int                     max_n_ivps
,  float                   hint
,  int                     hint_n_ivps
)  ;


int mclVectorSelectRltBar
(  mclVector*              vec
,  int                     ibar
,  float                   fbar
,  int                   (*irlt)(const void*, const void*)
,  int                   (*frlt)(const void*, const void*)
,  int                     onlyCount
)  ;


int mclVectorSelectGtBar
(  mclVector*              vec
,  float                   bar
)  ;


int mclVectorCountGqBar
(  mclVector*              vec
,  float                   bar
)  ;
#endif

#endif /* NONEMA_VECTOR_H */

