

#ifndef NONEMA_VECTOR_H__
#define NONEMA_VECTOR_H__

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <float.h>

#include "nonema/float.h"
#include "nonema/ivp.h"
#include "nonema/iface.h"
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
;  mcxIvp*              ivps
;
}  mcxVector            ;


void mcxVectorAlert
(
   const char*          caller
)  ;


/*
 *
 *  
*/

mcxstatus mcxVectorCheck
(
   const mcxVector*        vec
,  int                     range
,  const char*             caller
,  mcxOnFail               ON_FAIL
)  ;


mcxVector* mcxVectorInstantiate
(
   mcxVector*              dst
,  int                     n_ivps
,  const mcxIvp*           ivps
)  ;


mcxVector* mcxVectorInit
(
   mcxVector*              vec
)  ;


mcxVector* mcxVectorCreate
(
   int                     nr
)  ;


mcxVector* mcxVectorResize
(
   mcxVector*              vec
,  int                     n_ivps
)  ;


mcxVector* mcxVectorCopy
(
   const mcxVector*        src
)  ;


void mcxVectorFree
(
   mcxVector**             vec_p
)  ;


mcxVector* mcxVectorComplete
(
   mcxVector*              dst_vec
,  int                     nr
,  float                   val
)  ;


mcxVector* mcxVectorMaskedCopy
(
   mcxVector*              dst
,  const mcxVector*        src
,  const mcxVector*        msk
,  int                     mask_mode
)  ;


extern __inline__ mcxVector* mcxVectorCreate
(
   int                     n_ivps
)  
   {
      return mcxVectorInstantiate(NULL, n_ivps, NULL)
;  }


extern __inline__ mcxVector*  mcxVectorResize
(
   mcxVector*              vec
,  int                     n_ivps
)  
   {
      return mcxVectorInstantiate(vec, n_ivps, NULL)
;  }


extern __inline__ mcxVector* mcxVectorCopy
(
   const mcxVector*        src
)  
   {
      return mcxVectorInstantiate(NULL, src->n_ivps, src->ivps)
;  }


void mcxVectorSort
(
   mcxVector*              vec
,  int                     (*mcxIvpCmp)(const void*, const void*)
);


void mcxVectorUniqueIdx
(
   mcxVector*              vec
)  ;


void mcxVectorSelectHighest
(
   mcxVector*              vec
,  int                     max_n_ivps
)  ;


/*
 *    ignore:     when searching k large elements, consider only those elements
 *                that are < ignore. case mode = KBAR_SELECT_LARGE
 *                when searching k small elements, consider only those elements
 *                that are >= ignore. case mode = KBAR_SELECT_SMALL
*/


float mcxVectorKBar
(  
   mcxVector               *vec
,  int                     k
,  float                   ignore
,  int                     mode
)  ;


float mcxVectorSelectGqBar
(
   mcxVector*              vec
,  float                   bar
)  ;


extern __inline__ void mcxVectorSelectHighest
(
   mcxVector*              vec
,  int                     max_n_ivps
)  
   {
      float f =
      (vec->n_ivps >= 2 * max_n_ivps) 
      ?  mcxVectorKBar
         (vec, max_n_ivps, FLT_MAX, KBAR_SELECT_LARGE)
      :  mcxVectorKBar
         (vec, vec->n_ivps - max_n_ivps + 1, -FLT_MAX, KBAR_SELECT_SMALL)

   ;  mcxVectorSelectGqBar(vec, f)
;  }


float mcxVectorSelectNeedsBar
(
   mcxVector*              vec
,  int                     dest_n_ivps
)  ;


void mcxVectorUnary
(
   mcxVector*              vec
,  float                   (*operation)(float val, void* argument)
,  void*                   argument
)  ;


void mcxVectorScale
(  
   mcxVector*              vec
,  float                   fac
)  ;


float mcxVectorNormalize
(
   mcxVector*              vec
)  ;


float mcxVectorInflate
(
   mcxVector*              vec
,  double                  power
)  ;


void mcxVectorMakeCharacteristic
(
   mcxVector*              vec
)  ;


void mcxVectorRemoveIdx
(
   mcxVector*              vec
,  int                     idx
)  ;


extern __inline__ void mcxVectorMakeCharacteristic
(
   mcxVector*              vec
)  
   {
      float                one      =  1.0
   ;  mcxVectorUnary(vec, fltConstant, &one)
;  }


mcxVector* mcxVectorBinary
(
   const mcxVector*        src1
,  const mcxVector*        src2
,  mcxVector*              dst
,  float                   (*operation)(float val1, float val2)
)  ;


extern __inline__ mcxVector* mcxVectorMaskedCopy
(
   mcxVector*              dst
,  const mcxVector*        src
,  const mcxVector*        msk
,  int                     mask_mode
)  
   {
      if   (mask_mode == 0)                              /* positive mask */
      return  mcxVectorBinary(src, msk, dst, fltLTrueAndRTrue)
   ;  else                                               /* negative mask */
      return mcxVectorBinary(src, msk, dst, fltLTrueAndRFalse)
;  }


mcxVector* mcxVectorSetMinus
(
   const mcxVector*           vecl
,  const mcxVector*           vecr
,  mcxVector*                 dst
)  ;


mcxVector* mcxVectorSetMerge
(
   const mcxVector*           lft
,  const mcxVector*           rgt
,  mcxVector*                 dst
)  ;


mcxVector* mcxVectorSetMeet
(
   const mcxVector*           lft
,  const mcxVector*           rgt
,  mcxVector*                 dst
)  ;


extern __inline__ mcxVector* mcxVectorSetMerge
(
   const mcxVector*  lft
,  const mcxVector*  rgt
,  mcxVector*  dst
)  {
      return mcxVectorBinary(lft, rgt, dst, fltLTrueOrRTrue)
;  }


extern __inline__ mcxVector* mcxVectorSetMinus
(
   const mcxVector*  lft
,  const mcxVector*  rgt
,  mcxVector*  dst
)  
   {
      return mcxVectorBinary(lft, rgt, dst, fltLTrueAndRFalse)
;  }


extern __inline__ mcxVector* mcxVectorSetMeet
(
   const mcxVector*  lft
,  const mcxVector*  rgt
,  mcxVector*  dst
)  
   {
      return mcxVectorBinary(lft, rgt, dst, fltLTrueAndRTrue)
;  }  


float mcxVectorSum
(
   const mcxVector*           vec
)  ;


float mcxVectorPowSum
(
   const mcxVector*           vec
,  double                     power
)  ;


float mcxVectorNorm
(
   const mcxVector*           vec
,  double                     power
)  ;


float mcxVectorMaxValue
(
   const mcxVector*           vec
)  ;


extern __inline__ float mcxVectorMaxValue
(
   const mcxVector*           vec
)  
   {
      float                   max_val  =  0.0
   ;  mcxVectorUnary((mcxVector*)vec, fltPropagateMax, &max_val)
   ;  return (float) max_val
;  }


float mcxVectorIdxVal
(
   mcxVector*                 vec
,  int                        idx
,  int*                       p_offset
)  ;


int mcxVectorIdxOffset
(
   mcxVector*                 vec
,  int                        idx
)  ;


int mcxVectorIdxCmp
(
   const void*                p1
,  const void*                p2
)  ;


int mcxVectorSumCmp
(
   const void*                p1
,  const void*                p2
)  ;


int mcxVectorIdxRevCmp
(
   const void*                p1
,  const void*                p2
)  ;


int mcxVectorSumRevCmp
(
   const void*                p1
,  const void*                p2
)  ;


#if 0
void mcxVectorSelectHighestWithHint
(
   mcxVector*              vec
,  int                     max_n_ivps
,  float                   hint
,  int                     hint_n_ivps
)  ;


int mcxVectorSelectRltBar
(
   mcxVector*              vec
,  int                     ibar
,  float                   fbar
,  int                   (*irlt)(const void*, const void*)
,  int                   (*frlt)(const void*, const void*)
,  int                     onlyCount
)  ;


int mcxVectorSelectGtBar
(
   mcxVector*              vec
,  float                   bar
)  ;


int mcxVectorCountGqBar
(
   mcxVector*              vec
,  float                   bar
)  ;


extern __inline__ int mcxVectorSelectGtBar
(
   mcxVector*              vec
,  float                   bar
)  
   {
      return mcxVectorSelectRltBar(vec, -1, bar, NULL, fltGt, 0)
;  }


extern __inline__ int mcxVectorCountGqBar
(
   mcxVector*              vec
,  float                   bar
)  
   {
      return mcxVectorSelectRltBar(vec, -1, bar, NULL, fltGq, 1)
;  }
#endif


#endif /* NONEMA_VECTOR_H */
