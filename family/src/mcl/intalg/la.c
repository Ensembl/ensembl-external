
#include "la.h"
#include "util/buf.h"
#include "util/types.h"
#include "util/alloc.h"
#include "intalg/ilist.h"
#include "nonema/io.h"

#include <stdlib.h>
#include <math.h>
#include <limits.h>
#include <stdio.h>


int   idxShare
(  const   mcxVector*   v1
,  const   mcxVector*   v2
,  mcxVector*           m
)  {  m  =  mcxVectorSetMeet(v1, v2, m)
   ;  if (m->n_ivps)
         return (m->ivps+0)->idx
   ;  return -1
;  }


mcxVector*   mcxVectorFromIlist
(  mcxVector*  vec
,  Ilist*      il
,  float       f
)  {  
      int   i

   ;  if (!il)
      return   mcxVectorInstantiate(vec, 0, NULL)

   ;  vec   =  mcxVectorInstantiate(vec, il->n, NULL)

   ;  for (i=0;i<il->n;i++)
      {  mcxIvp*  ivp   =  vec->ivps+i
      ;  ivp->idx       =  *(il->list+i)
      ;  ivp->val       =  f
   ;  }  

   ;  mcxVectorSort(vec, NULL)
   ;  mcxVectorUniqueIdx(vec)

   ;  return vec
;  }


mcxMatrix*     genClustering
(  Ilist*   il
)  {  int      dimension   =  *(il->list+il->n -1)
   ;  int      i, j,  prev_offset, n_seen
   ;  mcxMatrix*  cl

   ;  if (!ilIsAscending(il) || *(il->list+0) <= 0)
      {  fprintf
         (  stderr
         ,  "[genMatrix] ilist argument not strictly ascending and positive\n"
         )
      ;  ilPrint(il, "offending list")
      ;  exit(1)
   ;  }
                                  /* one garbage vector, that will be empty */
   ;  cl             =  mcxMatrixAllocZero(il->n + 1, dimension)
   ;  prev_offset    =  0
   ;  n_seen         =  0

   ;  for (i=0;i<il->n;i++)
      {  mcxVector*  vec      =  cl->vectors+i
      ;  int      vecsize  =  *(il->list+i) - prev_offset
      ;  mcxVectorInstantiate(vec, vecsize, NULL)

      ;  for (j=0;j< vecsize; j++)
         {  (vec->ivps+j)->idx  =   n_seen++
         ;  (vec->ivps+j)->val  =   1.0
      ;  }
      ;  prev_offset =  *(il->list+i)
   ;  }
   ;  return cl
;  }


mcxMatrix*     genMatrix
(  Ilist*   il_part
,  float    p
,  float    q
,  double   ppower
,  double   qpower
)  {  int      dimension   =  *(il_part->list+il_part->n -1)
   ;  int      c, r
   ;  long     t
   ;  mcxMatrix   *mx, *mxt, *mxs
   ;  int      c_p         =  0              /* c belongs to partition c_p */

   ;  long     pbar        =  (long) (p * LONG_MAX)
   ;  long     qbar        =  (long) (q * LONG_MAX)
   ;  int      c_clustersize, r_clustersize
   ;  float    qfactor, pfactor

   ;  mcxBuf     ivpbuf

   ;  if (!ilIsAscending(il_part) || *(il_part->list+0) <= 0)
      {  fprintf
         (  stderr
         ,  "[genMatrix] ilist argument not strictly ascending and positive\n"
         )
      ;  ilPrint(il_part, "offending list")
      ;  exit(1)
   ;  }

   ;  mx                =  mcxMatrixAllocZero(dimension, dimension)

   ;  c_clustersize     =  *(il_part->list+0)
   ;  r_clustersize     =  *(il_part->list+0)
   ;  qfactor           =  qpower && (c_clustersize < dimension)
                           ?  pow   (  (double) c_clustersize
                                    /  (dimension - c_clustersize)
                                    ,  qpower
                                    )
                           :  1.0
   ;  pfactor           =  ppower && (c_clustersize < dimension)
                           ?  pow   (  (double) c_clustersize
                                    /  (dimension - c_clustersize)
                                    ,  ppower
                                    )
                           :  1.0

   ;  for (c=0;c<dimension;c++)
      {  
         mcxVector*  vec   =  (mx->vectors+c)
      ;  int      r_p      =  c_p          /* do only sub diagonal part     */

      ;  mcxBufInit(&ivpbuf, &(vec->ivps), sizeof(mcxIvp), 30)

      ;  if (c >= *(il_part->list+c_p))
         {  c_p++
         ;  c_clustersize  =  *(il_part->list+c_p) - *(il_part->list+c_p-1)
         ;  qfactor        =     qpower
                              && (c_clustersize + r_clustersize < dimension)
                              ?  pow(  (double) (c_clustersize + r_clustersize)
                                             /
                                       (dimension-c_clustersize-r_clustersize)
                                    ,  qpower
                                    )
                              :  1.0
         ;  pfactor        =     ppower
                              && (c_clustersize < dimension)
                              ?  pow(  (double) c_clustersize
                                             /
                                       (dimension - c_clustersize)
                                    ,  ppower
                                    )
                              :  1.0
      ;  }

      ;  for (r=c+1;r<dimension;r++)
         {  
         ;  if (r >= *(il_part->list+r_p))
            {  r_p++
            ;  r_clustersize  =  *(il_part->list+r_p) - *(il_part->list+r_p-1)
         ;  }

         ;  t     =  rand()

         ;  if
            (  (c_p == r_p && t <= (long) (pbar / pfactor))
            || (t <= (long) (qbar * qfactor))
            )
            {  
               mcxIvp* ivp    =  (mcxIvp*) mcxBufExtend(&ivpbuf, 1)
            ;  ivp->idx       =  r
            ;  ivp->val       =  1.0
         ;  }
      ;  }

      ;  vec->n_ivps   =  mcxBufFinalize(&ivpbuf)
   ;  }

   ;  mxt   =  mcxMatrixTranspose(mx)
   ;  mxs   =  mcxMatrixAdd(mx, mxt)
   ;  mcxMatrixMakeCharacteristic(mxs)
   ;  mcxMatrixFree(&mx)
   ;  mcxMatrixFree(&mxt)
   ;  return mxs
;  }



mcxMatrix*     mcxMatrixPermute
(  mcxMatrix*  src
,  mcxMatrix*  dst
,  Ilist*   pm_col
,  Ilist*   pm_row
)  {
      mcxVector*  vectors  =  NULL
   ;  int      i
   ;  Ilist*   pmi

   ;  int      n_col    =  src->N_cols
   ;  int      n_row    =  src->N_rows

   ;  if ((pm_col && pm_col->n != n_col) || (pm_row && pm_row->n != n_row))
      {  fprintf
         (  stderr
         ,  "[mcxMatrixPermute] mcxMatrix dimensions (%d, %d)\n"
            "  do not fit permutation dimensions (%d, %d)\n"
         ,  n_col, n_row
         ,  pm_col->n, pm_row->n
         )
      ;  exit(1)
   ;  }

   ;  if (dst == src)
   ;  else
      {  if (dst)
         {  mcxMatrixFree(&dst)
      ;  }
      ;  dst = mcxMatrixCopy(src)
   ;  }

   ;  if (pm_col)
      {  pmi      =  ilInvert(pm_col)

      ;  vectors  =  (mcxVector*) rqRealloc
                     (  vectors
                     ,  n_col * sizeof(mcxVector)
                     ,  RETURN_ON_FAIL
                     )
      ;  if (n_col && !vectors)
            mcxMemDenied(stderr, "mcxMatrixPermute", "mcxVector", n_col)
         ,  exit(1)

      ;  memcpy(vectors, dst->vectors, n_col * sizeof(mcxVector))

      ;  for (i=0;i<n_col;i++)
         {  *(dst->vectors+i) = *(vectors + *(pmi->list+i))
      ;  }
      ;  ilFree(&pmi)
   ;  }

   ;  if (pm_row)
      {  mcxMatrix*  dst_tp   =  mcxMatrixTranspose(dst)
      ;  pmi                  =  ilInvert(pm_row)

      ;  vectors  =  (mcxVector*) rqRealloc
                     (  vectors
                     ,  n_row * sizeof(mcxVector)
                     ,  RETURN_ON_FAIL
                     )

      ;  if (n_row && !vectors)
            mcxMemDenied(stderr, "mcxMatrixPermute", "mcxVector", n_row)
         ,  exit(1)

      ;  memcpy(vectors, dst_tp->vectors, n_row * sizeof(mcxVector))

      ;  for (i=0;i<n_row;i++)
         *(dst_tp->vectors+i) = *(vectors + *(pmi->list+i))

      ;  mcxMatrixFree(&dst)
      ;  dst   =  mcxMatrixTranspose(dst_tp)
      ;  mcxMatrixFree(&dst_tp)
      ;  ilFree(&pmi)
   ;  }

   ;  rqFree(vectors)
   ;  return dst
;  }

