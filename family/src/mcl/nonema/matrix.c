/*
*/

#include <ctype.h>
#include <math.h>

#include "nonema/matrix.h"

#include "util/alloc.h"
#include "util/types.h"
#include "util/iomagic.h"


/*
*/

mcxMatrix* mcxMatrixAllocZero
(  int                     N_cols
,  int                     N_rows
)  {  
      mcxVector   *vec
   ;  mcxMatrix   *dst     =  (mcxMatrix*) rqAlloc
                              (  sizeof(mcxMatrix)
                              ,  EXIT_ON_FAIL
                              )
   ;  if (N_cols <= 0 || N_rows <= 0)
      {
         fprintf
         (  stderr
         ,  "[mcxMatrixAllocZero PBD] invalid dimensions [%d,%d]\n"
         ,  N_rows
         ,  N_cols
         )
      ;  exit(1)
   ;  }

   ;  dst->vectors         =  (mcxVector*) rqAlloc
                              (  N_cols * sizeof(mcxVector)
                              ,  RETURN_ON_FAIL
                              )
   ;  if (!dst->vectors)
         mcxMemDenied(stderr, "mcxMatrixAllocZero", "mcxVector", N_cols)
      ,  exit(1)

   ;  vec                  =  dst->vectors

   ;  dst->N_cols          =  N_cols
   ;  dst->N_rows          =  N_rows

   ;  while (--N_cols >= 0)
      {  mcxVectorInit(vec)
      ;  vec++
   ;  }
   
   ;  return dst
;  }


mcxMatrix* mcxMatrixComplete
(  int                     N_cols
,  int                     N_rows
,  float                   val
)  {  
      int i
   ;  mcxMatrix*  rect  =  mcxMatrixAllocZero(N_cols, N_rows)

   ;  for(i=0;i<rect->N_cols;i++)
      mcxVectorComplete(rect->vectors+i, N_rows, val)

   ;  return rect
;  }


mcxMatrix*  mcxSubmatrix
(  const mcxMatrix*  mx
,  const mcxVector*  colSelect
,  const mcxVector*  rowSelect
)  {  mcxIvp   *colIvp, *colIvpMax
   ;  mcxMatrix*  sub   =  mcxMatrixAllocZero
                           (  mx->N_cols
                           ,  mx->N_rows
                           )

   ;  colIvp            =  colSelect->ivps;
   ;  colIvpMax         =  colIvp+colSelect->n_ivps;

   ;  mcxVectorCheck(colSelect, mx->N_cols, "mcxSubmatrix", RETURN_ON_FAIL)
   ;  mcxVectorCheck(rowSelect, mx->N_rows, "mcxSubmatrix", RETURN_ON_FAIL)

   ;  while (colIvp<colIvpMax)
      {
         int   c  =  colIvp->idx
      ;  mcxVectorSetMeet(mx->vectors+c, rowSelect, sub->vectors+c)
      ;  colIvp++
   ;  }
   ;  return sub
;  }


mcxMatrix* mcxMatrixConstDiag
(  int                     N_cols
,  float                   c
)  {  
      mcxMatrix*           m        =  mcxMatrixAllocZero(N_cols, N_cols)
   ;  mcxVector*           vec      =  m->vectors
   ;  int                  idx      =  0

   ;  while (idx < N_cols)
      {  if (!mcxVectorResize(vec, 1))
         {  mcxMatrixFree(&m)
         ;  break
      ;  }

      ;  mcxIvpInstantiate(vec->ivps + 0, idx, c)

      ;  vec++
      ;  idx++
   ;  }

   ;  return m
;  }


mcxMatrix* mcxMatrixDiag
(  int                     dimen
,  float                   f
,  mcxIvp*                 ivps
,  int                     n_ivps
)  {  
      mcxMatrix*           m        =        NULL
   ;  if (ivps == NULL)
      {  m =  mcxMatrixConstDiag(dimen, f)
   ;  }
      else if ((ivps != NULL) && (n_ivps >= 0))
      {  int i
      ;  m = mcxMatrixConstDiag(dimen, 0.0)
      ;  qsort(ivps, n_ivps, sizeof(mcxIvp), mcxIvpIdxCmp)
      ;  for(i=0;i<n_ivps;i++)
         {  mcxIvp   *ivp  =  ivps+i
         ;  if (ivp->idx < 0 || ivp->idx > m->N_cols)
            {  fprintf
               (  stdout
               ,  "[mcxMatrixDiag fatal] Index %d out of bounds [0,%d]\n"
               ,  ivp->idx ,  m->N_cols
               )
            ;  exit(1)
         ;  }
         ;  ((m->vectors+ivp->idx)->ivps+0)->val =  ivp->val
      ;  }
   ;  }
   ;  return m
;  }


mcxMatrix* mcxMatrixCopy
(  const mcxMatrix*           src
)  {  
      int                  N_cols      =  src->N_cols
   ;  mcxMatrix*              dst      =  mcxMatrixAllocZero
                                          (  N_cols
                                          ,  src->N_rows
                                          )

   ;  const mcxVector*     src_vec     =  src->vectors
   ;  mcxVector*           dst_vec     =  dst->vectors

   ;  while (--N_cols >= 0)
      {  
         if (!mcxVectorInstantiate(dst_vec, src_vec->n_ivps, src_vec->ivps))
         {  
            mcxMatrixFree(&dst)
         ;  break
      ;  }
      ;  src_vec++
      ;  dst_vec++
   ;  }
   
   ;  return dst
;  }


void mcxMatrixFree
(  mcxMatrix**             m
)  {  if (*m)
      {  mcxVector*        vec      =  (*m)->vectors
      ;  int               N_cols   =  (*m)->N_cols

      ;  while (--N_cols >= 0)
         {  rqFree(vec->ivps)
         ;  vec++
      ;  }

      ;  rqFree((*m)->vectors)
      ;  rqFree(*m)

      ;  *m = NULL
   ;  }
;  }

/*
////////////////////////////////////////////////////////////////////////
//
// Dedicated in-place matrix operations
//
*/


void mcxMatrixMakeStochastic
(  mcxMatrix*                 mx
)  
   {  mcxVector*        vecPtr             =     mx->vectors
   ;  mcxVector*        vecPtrMax          =     vecPtr + mx->N_cols

   ;  while (vecPtr < vecPtrMax)
      {  mcxVectorNormalize(vecPtr)
      ;  vecPtr++
   ;  }
   }

void mcxMatrixMakeSparse
(  mcxMatrix*                 m
,  int                     maxDensity
)  {  int                  k           =  m->N_cols
   ;  mcxVector*           vec         =  m->vectors

   ;  while (--k >= 0)
      {  mcxVectorSelectHighest(vec, maxDensity)
      ;  mcxVectorSort(vec, NULL)
      ;  ++vec
;  }  }


/*
////////////////////////////////////////////////////////////////////////
//
// Elementwise defined callback operations
//
*/

void mcxMatrixUnary
(  mcxMatrix*                 src
,  float                   (*operation)(float, void*)
,  void*                   arg
)  {  int                  N_cols   =  src->N_cols
   ;  mcxVector*              vec         =  src->vectors

   ;  while (--N_cols >= 0)
      {  mcxVectorUnary(vec, operation, arg)
      ;  vec++
;  }  }


mcxMatrix* mcxMatrixBinary
(  const mcxMatrix*           m1
,  const mcxMatrix*           m2
,  float                   (*operation)(float, float)
)  {  
      int                  N_cols   =  m1->N_cols
   ;  mcxMatrix*              m3

   ;  if
      (  m1->N_rows != m2->N_rows
      || m1->N_cols != m2->N_cols
      )
      {  fprintf
         (  stderr
         ,  "[mcxMatrixBinary PBD] dimensions [%dx%d] X [%dx%d] do not match\n"
         ,  m1->N_rows, m1->N_cols
         ,  m2->N_rows, m2->N_cols
         )
      ;  exit(1)
   ;  }

   ;  m3 = mcxMatrixAllocZero(N_cols, m1->N_rows)

   ;  while (--N_cols >= 0)
      {  if 
         (  !mcxVectorBinary
            (  m1->vectors + N_cols
            ,  m2->vectors + N_cols
            ,  m3->vectors + N_cols
            ,  operation
            )  
         )
         {  mcxMatrixFree(&m3)
         ;  break
      ;  }
      }

   ;  return m3
;  }


/*
////////////////////////////////////////////////////////////////////////
//
// Constructive matrix operations
//
*/

mcxMatrix* mcxMatrixTranspose
(  const mcxMatrix*           src
)  {  
      mcxMatrix*              dst      =  mcxMatrixAllocZero
                                          (  src->N_rows
                                          ,  src->N_cols
                                          )

   ;  const mcxVector*     src_vec     =  src->vectors
   ;  mcxVector*           dst_vec     =  dst->vectors
   ;  int               vec_idx        =  src->N_cols

      /*
      // Pre-calculate sizes of destination columns
      //
      */
   ;  while (--vec_idx >= 0)
      {  int            src_n_ivps     =  src_vec->n_ivps
      ;  mcxIvp*           src_ivp     =  src_vec->ivps

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
      {  if (!mcxVectorResize(dst_vec, dst_vec->n_ivps))
         {  mcxMatrixFree(&dst)
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
      ;  mcxIvp*           src_ivp     =  src_vec->ivps

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


/*
////////////////////////////////////////////////////////////////////////
//
// Inquiry: Comparison, map and ordering
//
*/

int mcxMatrixEqualMatrices
(  const mcxMatrix*           m1
,  const mcxMatrix*           m2
)  {  int                  N_cols   =  m1->N_cols
   ;  const mcxVector*        m1vec       =  m1->vectors
   ;  const mcxVector*        m2vec       =  m2->vectors

   ;  if (N_cols != m2->N_cols) return 0

   ;  while (--N_cols >= 0)
         if ((m1vec++)->n_ivps != (m2vec++)->n_ivps) return 0

   ;  N_cols   =  m1->N_cols
   ;  m1vec       =  m1->vectors
   ;  m2vec       =  m2->vectors

   ;  while (--N_cols >= 0)
      {  mcxIvp*              ivp1        =  m1vec->ivps
      ;  mcxIvp*              ivp2        =  m2vec->ivps
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


mcxVector* mcxMatrixVectorSums
(  mcxMatrix*                 m
)  {  mcxVector*              sums        =  mcxVectorCreate(m->N_cols)
   ;  int                  vec_idx     =  0
   ;  int                  ivp_idx     =  0
   
   ;  if (sums)
      {  while (vec_idx < m->N_cols)
         {  float          weight      =  mcxVectorSum(m->vectors + vec_idx)

         ;  if (weight)
               mcxIvpInstantiate(sums->ivps + (ivp_idx++), vec_idx, weight)

         ;  vec_idx++
      ;  }

      ;  mcxVectorResize(sums, ivp_idx)
   ;  }

   ;  return sums
;  }


float mcxSubmatrixMass
(  const mcxMatrix*     m
,  const mcxVector*     colSelect
,  const mcxVector*     rowSelect
)  {  mcxMatrix   *sub  =  mcxSubmatrix(m, colSelect, rowSelect)
   ;  float       mass  =  mcxMatrixMass(sub)
   ;  mcxMatrixFree(&sub)
   ;  return mass
;  }


float mcxMatrixMass
(  const mcxMatrix*     m
)  {  int                  c
   ;  float                mass  =  0
   ;  for (c=0;c<m->N_cols;c++)
      {  mass += mcxVectorSum(m->vectors+c)
   ;  }
   ;  return mass
;  }


int mcxSubmatrixNrofEntries
(  const mcxMatrix*     m
,  const mcxVector*     colSelect
,  const mcxVector*     rowSelect
)  {  mcxMatrix   *sub  =  mcxSubmatrix(m, colSelect, rowSelect)
   ;  int         nr    =  mcxMatrixNrofEntries(sub)
   ;  mcxMatrixFree(&sub)
   ;  return nr
;  }

int mcxMatrixNrofEntries
(  const mcxMatrix*     m
)  {  int                  c
   ;  int                  nr    =  0
   ;  for (c=0;c<m->N_cols;c++)
      {  nr += (m->vectors+c)->n_ivps
   ;  }
   ;  return nr
;  }

void  mcxMatrixRealignVectors
(  mcxMatrix*                 m
,  int                     (*cmp) (const void *, const void *)
)  {  qsort(m->vectors, m->N_cols, sizeof(mcxVector), cmp)
;  }


