/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <math.h>

#include "compose.h"

#include "util/alloc.h"
#include "util/types.h"


static mclIvp* rqIvpStorage
(  
   int                     n_ivps
)  ;


mclVector* mclMatrixVectorDenseCompose
(  const mclMatrix*           mx
,  const mclVector*           vecs
,  mclVector*                 vecd
)  {
      int                     n_vecs_ivps
   ;  mclIvp*                 vecs_ivp

#ifdef RUNTIME_VECTOR_INTEGRITY
   ;  mclVectorCheck
      (  vecs
      ,  mx->N_cols
      ,  EXIT_ON_FAIL
      )
#endif

   ;  n_vecs_ivps                =  vecs->n_ivps
   ;  vecs_ivp                   =  vecs->ivps + n_vecs_ivps

   ;  vecd                       =  mclVectorComplete
                                    (  vecd
                                    ,  mx->N_rows
                                    ,  0.0
                                    )

   ;  while (--vecs_ivp, --n_vecs_ivps >= 0)
      {  int         vecsidx     =  vecs_ivp->idx;
         float       vecsval     =  vecs_ivp->val;
         int         n_col_ivps  =  mx->vectors[vecsidx].n_ivps;
         mclIvp*     col_ivp     =  mx->vectors[vecsidx].ivps + n_col_ivps;

      ;  while (--col_ivp, --n_col_ivps >= 0)
         {  (vecd->ivps+col_ivp->idx)->val += col_ivp->val * vecsval
      ;  }
   ;  }
   ;  return vecd
;  }


mclVector* mclMatrixVectorCompose
(  
   const mclMatrix*        mx
,  const mclVector*        vecs
,  mclVector*              vecd
,  mclVector*              ivpVec
)  
   {  
      int                  range       =  mx->N_rows
   ;  int                  n_vecs_ivps =  vecs->n_ivps
   ;  mclIvp*              vecs_ivp    =  vecs->ivps + n_vecs_ivps

   ;  mclIvp*              prevs
   ;  int                  n_prevs     =  0

#ifdef RUNTIME_VECTOR_INTEGRITY
   ;  mclVectorCheck(vecs, mx->N_cols, EXIT_ON_FAIL)
#endif


   ;  {  if (ivpVec)
         {  if (ivpVec->n_ivps < range+1)
            {  fprintf
               (  stderr
               ,  "[mclMatrixVectorCompose PBD] insufficient storage\n"
               )
            ;  exit(1)
         ;  }
            else
            prevs =  ivpVec->ivps
      ;  }
         else
         prevs    =  rqIvpStorage(range + 1)

      ;  prevs[range].idx = -1
   ;  }


     /*
      *     Fill  the ivp  array `prevs'  with a  descending indexed linked
      *     list of non-zero entries; i.e. `prevs[k].idx' is the next lower
      *     `l' such that `prevs[l]' is defined.
     */

   ;  while (--vecs_ivp, --n_vecs_ivps >= 0)
      {  int            vecsidx     =  vecs_ivp->idx;
         float          vecs_val    =  vecs_ivp->val;
         int            n_col_ivps  =  mx->vectors[vecsidx].n_ivps;
         mclIvp*        col_ivp     =  mx->vectors[vecsidx].ivps + n_col_ivps;
         int            lastidx     =  range;

      ;  while (--col_ivp, --n_col_ivps >= 0)
         {  int         fillidx     =  col_ivp->idx;
            float       mulval      =  vecs_val * col_ivp->val;
            int         runidx;

         ;  while
            (  runidx = prevs[lastidx].idx
            ,  runidx > fillidx
            )  
               lastidx = runidx          
            ;

           /*
            *     returns a runidx <= fillidx lastidx is the previous runidx,
            *     so lastidx > fillidx
           */

         ;  if (runidx != fillidx)
            {  
               prevs[fillidx].idx = runidx
            ;  prevs[lastidx].idx = fillidx
            ;  prevs[fillidx].val = 0.0
            ;  n_prevs++
         ;  }

         ;  prevs[fillidx].val += mulval
         ;  lastidx = fillidx
      ;  }
   ;  }


     /*
      *     If  there are  any elements to  write, construct  a regular ivp
      *     array.
     */

   ;  vecd = mclVectorResize(vecd, n_prevs)

   ;  if (n_prevs)
      {  int   idx   =  range

      ;  while (n_prevs > 0)
         {  idx = prevs[idx].idx

         ;  --n_prevs
         ;  vecd->ivps[n_prevs].idx = idx
         ;  vecd->ivps[n_prevs].val = prevs[idx].val
   ;  }  }
      
   ;  return vecd
;  }


mclMatrix* mclMatrixCompose
(  const mclMatrix*           m1
,  const mclMatrix*           m2
,  int                        maxDensity
)  {  int                     n_m2_vectors   =  m2->N_cols
   ;  mclMatrix*              pr             =  0

   ;  if (m1->N_cols != m2->N_rows)
      {  fprintf(stderr, "Incompatible sizes of matrices\n")
      ;  exit(1)
   ;  }
      else
      {  pr = mclMatrixAllocZero(m2->N_cols, m1->N_rows)

      ;  if (pr)
         {  while (--n_m2_vectors >= 0)
            {  mclMatrixVectorCompose
               (  m1
               ,  m2->vectors + n_m2_vectors
               ,  pr->vectors + n_m2_vectors
               ,  NULL
               )
            ;  if (maxDensity)
                  mclVectorSelectHighest
                  (  pr->vectors + n_m2_vectors
                  ,  maxDensity
                  )
         ;  }
      ;  }
   ;  }

   ;  return pr
;  }
      

static mclIvp* ivpStorage =  NULL;

static mclIvp* rqIvpStorage
(  
   int         n_ivps
)  
   {  
      ivpStorage
      =  (mclIvp*) mcxRealloc
         (  ivpStorage
         ,  n_ivps * sizeof(mclIvp)
         ,  RETURN_ON_FAIL
         )

      ;  if (!ivpStorage)
            mcxMemDenied(stderr, "rqIvpStorage", "mclIvp", n_ivps)
         ,  exit(1)

   ;  return ivpStorage
;  }


