/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <ctype.h>
#include <math.h>

#include "matrix.h"

#include "util/compile.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/iomagic.h"


void mclMatrixInflate
(  mclMatrix*              mx
,  float                   power
)
   {  mclVector*     vecPtr          =     mx->vectors
   ;  mclVector*     vecPtrMax       =     vecPtr + mx->N_cols

   ;  while (vecPtr < vecPtrMax)
      {  mclVectorInflate(vecPtr, power)
      ;  vecPtr++
   ;  }
;  }


mclMatrix* mclMatrixAllocZero
(  int                     N_cols
,  int                     N_rows
)
   {  mclVector   *vec
   ;  mclMatrix   *dst     =  (mclMatrix*) mcxAlloc
                              (  sizeof(mclMatrix)
                              ,  EXIT_ON_FAIL
                              )
   ;  if (N_cols <= 0 || N_rows <= 0)
      {
         fprintf
         (  stderr
         ,  "[mclMatrixAllocZero PBD] invalid dimensions [%d,%d]\n"
         ,  N_rows
         ,  N_cols
         )
      ;  exit(1)
   ;  }

   ;  dst->vectors         =  (mclVector*) mcxAlloc
                              (  N_cols * sizeof(mclVector)
                              ,  RETURN_ON_FAIL
                              )
   ;  if (!dst->vectors)
         mcxMemDenied(stderr, "mclMatrixAllocZero", "mclVector", N_cols)
      ,  exit(1)

   ;  vec                  =  dst->vectors

   ;  dst->N_cols          =  N_cols
   ;  dst->N_rows          =  N_rows

   ;  while (--N_cols >= 0)
      {  mclVectorInit(vec)
      ;  vec++
   ;  }
   
   ;  return dst
;  }


mclMatrix* mclMatrixComplete
(  int                     N_cols
,  int                     N_rows
,  float                   val
)
   {  int i
   ;  mclMatrix*  rect  =  mclMatrixAllocZero(N_cols, N_rows)

   ;  for(i=0;i<rect->N_cols;i++)
      mclVectorComplete(rect->vectors+i, N_rows, val)

   ;  return rect
;  }


mclMatrix*  mclMatrixSub
(  const mclMatrix*  mx
,  const mclVector*  colSelect
,  const mclVector*  rowSelect
)
   {  mclIvp   *colIvp, *colIvpMax
   ;  mcxbool     ok    =  TRUE
   ;  mclMatrix*  sub   =  mclMatrixAllocZero
                           (  mx->N_cols
                           ,  mx->N_rows
                           )

   ;  colIvp            =  colSelect->ivps;
   ;  colIvpMax         =  colIvp+colSelect->n_ivps;

   ;  ok =  ok
            && mclVectorCheck(colSelect, mx->N_cols, RETURN_ON_FAIL)
               == STATUS_OK
   ;  ok =  ok
            && mclVectorCheck(rowSelect, mx->N_rows, RETURN_ON_FAIL)
               == STATUS_OK

   ;  if (!ok)
      {  mclMatrixFree(&sub)
      ;  return NULL
   ;  }

      while (colIvp<colIvpMax)
      {
         int   c  =  colIvp->idx
      ;  mclVectorSetMeet(mx->vectors+c, rowSelect, sub->vectors+c)
      ;  colIvp++
   ;  }
   ;  return sub
;  }


mclMatrix* mclMatrixConstDiag
(  int                     N_cols
,  float                   c
)
   {  mclMatrix*           m        =  mclMatrixAllocZero(N_cols, N_cols)
   ;  mclVector*           vec      =  m->vectors
   ;  int                  idx      =  0

   ;  while (idx < N_cols)
      {  if (!mclVectorResize(vec, 1))
         {  mclMatrixFree(&m)
         ;  break
      ;  }

      ;  mclIvpInstantiate(vec->ivps + 0, idx, c)

      ;  vec++
      ;  idx++
   ;  }

   ;  return m
;  }


mclMatrix* mclMatrixDiag
(  int                     dimen
,  float                   f
,  mclIvp*                 ivps
,  int                     n_ivps
)
   {  mclMatrix*           m        =        NULL
   ;  if (ivps == NULL)
      {  m =  mclMatrixConstDiag(dimen, f)
   ;  }
      else if ((ivps != NULL) && (n_ivps >= 0))
      {  int i
      ;  m = mclMatrixConstDiag(dimen, 0.0)
      ;  qsort(ivps, n_ivps, sizeof(mclIvp), mclIvpIdxCmp)
      ;  for(i=0;i<n_ivps;i++)
         {  mclIvp   *ivp  =  ivps+i
         ;  if (ivp->idx < 0 || ivp->idx > m->N_cols)
            {  fprintf
               (  stdout
               ,  "[mclMatrixDiag fatal] Index %d out of bounds [0,%d]\n"
               ,  ivp->idx ,  m->N_cols
               )
            ;  exit(1)
         ;  }
         ;  ((m->vectors+ivp->idx)->ivps+0)->val =  ivp->val
      ;  }
   ;  }
   ;  return m
;  }


mclMatrix* mclMatrixCopy
(  const mclMatrix*           src
)
   {  int                  N_cols      =  src->N_cols
   ;  mclMatrix*              dst      =  mclMatrixAllocZero
                                          (  N_cols
                                          ,  src->N_rows
                                          )

   ;  const mclVector*     src_vec     =  src->vectors
   ;  mclVector*           dst_vec     =  dst->vectors

   ;  while (--N_cols >= 0)
      {  
         if (!mclVectorInstantiate(dst_vec, src_vec->n_ivps, src_vec->ivps))
         {  
            mclMatrixFree(&dst)
         ;  break
      ;  }
      ;  src_vec++
      ;  dst_vec++
   ;  }
   
   ;  return dst
;  }


void mclMatrixFree
(  mclMatrix**             m
)  {  if (*m)
      {  mclVector*        vec      =  (*m)->vectors
      ;  int               N_cols   =  (*m)->N_cols

      ;  while (--N_cols >= 0)
         {  mcxFree(vec->ivps)
         ;  vec++
      ;  }

      ;  mcxFree((*m)->vectors)
      ;  mcxFree(*m)

      ;  *m = NULL
   ;  }
;  }


void mclMatrixMakeStochastic
(  mclMatrix*                 mx
)  
   {  mclVector*        vecPtr             =     mx->vectors
   ;  mclVector*        vecPtrMax          =     vecPtr + mx->N_cols

   ;  while (vecPtr < vecPtrMax)
      {  mclVectorNormalize(vecPtr)
      ;  vecPtr++
   ;  }
;  }


void mclMatrixMakeSparse
(  mclMatrix*                 m
,  int                     maxDensity
)
   {  int                  k           =  m->N_cols
   ;  mclVector*           vec         =  m->vectors

   ;  while (--k >= 0)
      {  mclVectorSelectHighest(vec, maxDensity)
      ;  mclVectorSort(vec, NULL)
      ;  ++vec
   ;  }
;  }


void mclMatrixUnary
(  mclMatrix*                 src
,  float                   (*operation)(float, void*)
,  void*                   arg
)
   {  int                  N_cols   =  src->N_cols
   ;  mclVector*              vec         =  src->vectors

   ;  while (--N_cols >= 0)
      {  mclVectorUnary(vec, operation, arg)
      ;  vec++
   ;  }
;  }


mclMatrix* mclMatrixBinary
(  const mclMatrix*           m1
,  const mclMatrix*           m2
,  float                   (*operation)(float, float)
)
   {  int                  N_cols   =  m1->N_cols
   ;  mclMatrix*              m3

   ;  if
      (  m1->N_rows != m2->N_rows
      || m1->N_cols != m2->N_cols
      )
      {  fprintf
         (  stderr
         ,  "[mclMatrixBinary PBD] dimensions [%dx%d] X [%dx%d] do not match\n"
         ,  m1->N_rows, m1->N_cols
         ,  m2->N_rows, m2->N_cols
         )
      ;  exit(1)
   ;  }

   ;  m3 = mclMatrixAllocZero(N_cols, m1->N_rows)

   ;  while (--N_cols >= 0)
      {  if 
         (  !mclVectorBinary
            (  m1->vectors + N_cols
            ,  m2->vectors + N_cols
            ,  m3->vectors + N_cols
            ,  operation
            )  
         )
         {  mclMatrixFree(&m3)
         ;  break
      ;  }
      }

   ;  return m3
;  }


mclMatrix* mclMatrixTranspose
(  const mclMatrix*           src
)
   {  mclMatrix*              dst      =  mclMatrixAllocZero
                                          (  src->N_rows
                                          ,  src->N_cols
                                          )

   ;  const mclVector*     src_vec     =  src->vectors
   ;  mclVector*           dst_vec     =  dst->vectors
   ;  int               vec_idx        =  src->N_cols

      /*
      // Pre-calculate sizes of destination columns
      //
      */
   ;  while (--vec_idx >= 0)
      {  int            src_n_ivps     =  src_vec->n_ivps
      ;  mclIvp*           src_ivp     =  src_vec->ivps

      ;  while (--src_n_ivps >= 0)
            dst_vec[(src_ivp++)->idx].n_ivps++

      ;  src_vec++
   ;  }

      /*
      // Allocate
      //
      */
   ;  dst_vec     =  dst->vectors
   ;  vec_idx     =  dst->N_cols
   ;  while (--vec_idx >= 0)
      {  if (!mclVectorResize(dst_vec, dst_vec->n_ivps))
         {  mclMatrixFree(&dst)
         ;  return 0
      ;  }
      ;  dst_vec->n_ivps = 0    /* dirty: start over for write */
      ;  dst_vec++
   ;  }

      /*
      // Write
      //
      */
   ;  src_vec     =  src->vectors
   ;  vec_idx     =  0
   ;  while (vec_idx < src->N_cols)
      {  int            src_n_ivps  =  src_vec->n_ivps
      ;  mclIvp*           src_ivp     =  src_vec->ivps

      ;  while (--src_n_ivps >= 0)
         {  dst_vec = dst->vectors + (src_ivp->idx)
         ;  dst_vec->ivps[dst_vec->n_ivps].idx = vec_idx
         ;  dst_vec->ivps[dst_vec->n_ivps].val = src_ivp->val
         ;  dst_vec->n_ivps++
         ;  src_ivp++
      ;  }
      ;  src_vec++
      ;  vec_idx++
   ;  }

   ;  return dst
;  }


int mclMatrixEqualMatrices
(  const mclMatrix*           m1
,  const mclMatrix*           m2
)
   {  int                  N_cols   =  m1->N_cols
   ;  const mclVector*        m1vec       =  m1->vectors
   ;  const mclVector*        m2vec       =  m2->vectors

   ;  if (N_cols != m2->N_cols) return 0

   ;  while (--N_cols >= 0)
         if ((m1vec++)->n_ivps != (m2vec++)->n_ivps) return 0

   ;  N_cols   =  m1->N_cols
   ;  m1vec       =  m1->vectors
   ;  m2vec       =  m2->vectors

   ;  while (--N_cols >= 0)
      {  mclIvp*           ivp1        =  m1vec->ivps
      ;  mclIvp*           ivp2        =  m2vec->ivps
      ;  int               k           =  m1vec->n_ivps

      ;  while (--k >= 0)
         {  if
            (  ivp1->idx != ivp2->idx
            || ivp1->val != ivp2->val
            )  return 0
         ;  ivp1++
         ;  ivp2++
      ;  }
      ;  m1vec++
      ;  m2vec++
   ;  }
   
   ;  return 1
;  }


mclVector* mclMatrixVectorSums
(  mclMatrix*                 m
)
   {  mclVector*           sums        =  mclVectorCreate(m->N_cols)
   ;  int                  vec_idx     =  0
   ;  int                  ivp_idx     =  0
   
   ;  if (sums)
      {  while (vec_idx < m->N_cols)
         {  float          weight      =  mclVectorSum(m->vectors + vec_idx)

         ;  if (weight)
               mclIvpInstantiate(sums->ivps + (ivp_idx++), vec_idx, weight)

         ;  vec_idx++
      ;  }

      ;  mclVectorResize(sums, ivp_idx)
   ;  }

   ;  return sums
;  }


float mclMatrixSubMass
(  const mclMatrix*     m
,  const mclVector*     colSelect
,  const mclVector*     rowSelect
)
   {  mclMatrix   *sub  =  mclMatrixSub(m, colSelect, rowSelect)
   ;  float       mass  =  mclMatrixMass(sub)
   ;  mclMatrixFree(&sub)
   ;  return mass
;  }


float mclMatrixMass
(  const mclMatrix*     m
)
   {  int                  c
   ;  float                mass  =  0
   ;  for (c=0;c<m->N_cols;c++)
      {  mass += mclVectorSum(m->vectors+c)
   ;  }
   ;  return mass
;  }


int mclMatrixSubNrofEntries
(  const mclMatrix*     m
,  const mclVector*     colSelect
,  const mclVector*     rowSelect
)
   {  mclMatrix   *sub  =  mclMatrixSub(m, colSelect, rowSelect)
   ;  int         nr    =  sub ? mclMatrixNrofEntries(sub) : 0
   ;  mclMatrixFree(&sub)
   ;  return nr
;  }


int mclMatrixNrofEntries
(  const mclMatrix*     m
)
   {  int                  c
   ;  int                  nr    =  0
   ;  for (c=0;c<m->N_cols;c++)
      {  nr += (m->vectors+c)->n_ivps
   ;  }
   ;  return nr
;  }

void  mclMatrixRealignVectors
(  mclMatrix*                 m
,  int                     (*cmp) (const void *, const void *)
)
   {  qsort(m->vectors, m->N_cols, sizeof(mclVector), cmp)
;  }


my_inline float mclMatrixMaxValue
(  const mclMatrix*        mx
) 
   {  float                max_val  =  0.0
   ;  mclMatrixUnary((mclMatrix*)mx, fltPropagateMax, &max_val)
   ;  return max_val
;  }


my_inline mclMatrix* mclMatrixIdentity
(  int                     n_rows
)  
   {  return mclMatrixConstDiag(n_rows, 1.0)
;  }


my_inline void mclMatrixScale
(  const mclMatrix*        mx
,  float                   f
) 
   {  mclMatrixUnary((mclMatrix*)mx, fltScale, &f)
;  }


my_inline void mclMatrixHdp
(  mclMatrix*              mx
,  float                   power
)  
   {  mclMatrixUnary(mx, fltPower, &power)
;  }


my_inline void mclMatrixMakeCharacteristic
(  mclMatrix*              mx
)  
   {  float                one         =  1.0
   ;  mclMatrixUnary(mx, fltConstant, &one)
;  }


my_inline mclMatrix* mclMatrixMax
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  
   {  return mclMatrixBinary(m1, m2, fltMax)
;  }


my_inline mclMatrix* mclMatrixAdd
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)  
   {  return mclMatrixBinary(m1, m2, fltAdd)
;  }


my_inline mclMatrix* mclMatrixHadamard
(  const mclMatrix*        m1
,  const mclMatrix*        m2
)
   {  return mclMatrixBinary(m1, m2, fltMultiply)
;  }


