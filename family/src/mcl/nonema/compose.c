/*
// compose.c               Compose matrix/vector
*/

#include <math.h>

#include "nonema/compose.h"

#include "util/alloc.h"
#include "util/types.h"

#include <unistd.h>


static mcxIvp* rqIvpStorage
(  
   int                     n_ivps
)  ;


mcxVector* mcxMatrixVectorDenseCompose
(  const mcxMatrix*           mx
,  const mcxVector*           vecs
,  mcxVector*                 vecd
)  {
      int                     n_vecs_ivps
   ;  mcxIvp*                 vecs_ivp

#ifdef RUNTIME_VECTOR_INTEGRITY
   ;  mcxVectorCheck
      (  vecs
      ,  mx->N_cols
      ,  "mcxMatrixVectorDenseCompose"
      ,  EXIT_ON_FAIL
      )
#endif

   ;  n_vecs_ivps                =  vecs->n_ivps
   ;  vecs_ivp                   =  vecs->ivps + n_vecs_ivps

   ;  vecd                       =  mcxVectorComplete
                                    (  vecd
                                    ,  mx->N_rows
                                    ,  0.0
                                    )

   ;  while (--vecs_ivp, --n_vecs_ivps >= 0)
      {  int         vecsidx     =  vecs_ivp->idx;
         float       vecsval     =  vecs_ivp->val;
         int         n_col_ivps  =  mx->vectors[vecsidx].n_ivps;
         mcxIvp*     col_ivp     =  mx->vectors[vecsidx].ivps + n_col_ivps;

      ;  while (--col_ivp, --n_col_ivps >= 0)
         {  (vecd->ivps+col_ivp->idx)->val += col_ivp->val * vecsval
      ;  }
   ;  }
   ;  return vecd
;  }


mcxVector* mcxMatrixVectorCompose
(  
   const mcxMatrix*        mx
,  const mcxVector*        vecs
,  mcxVector*              vecd
,  mcxVector*              ivpVec
)  
   {  
      int                  range       =  mx->N_rows
   ;  int                  n_vecs_ivps =  vecs->n_ivps
   ;  mcxIvp*              vecs_ivp    =  vecs->ivps + n_vecs_ivps

   ;  mcxIvp*              prevs
   ;  int                  n_prevs     =  0

#ifdef RUNTIME_VECTOR_INTEGRITY
   ;  mcxVectorCheck(vecs, mx->N_cols, "mcxMatrixVectorCompose", EXIT_ON_FAIL)
#endif


   ;  {  if (ivpVec)
         {  if (ivpVec->n_ivps < range+1)
            {  fprintf
               (  stderr
               ,  "[mcxMatrixVectorCompose PBD] insufficient storage\n"
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
         mcxIvp*        col_ivp     =  mx->vectors[vecsidx].ivps + n_col_ivps;
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

   ;  vecd = mcxVectorResize(vecd, n_prevs)

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


mcxMatrix* mcxMatrixCompose
(  const mcxMatrix*           m1
,  const mcxMatrix*           m2
,  int                        maxDensity
)  {  int                     n_m2_vectors   =  m2->N_cols
   ;  mcxMatrix*              pr             =  0

   ;  if (m1->N_cols != m2->N_rows)
      {  fprintf(stderr, "Incompatible sizes of matrices\n")
      ;  exit(1)
   ;  }
      else
      {  pr = mcxMatrixAllocZero(m2->N_cols, m1->N_rows)

      ;  if (pr)
         {  while (--n_m2_vectors >= 0)
            {  mcxMatrixVectorCompose
               (  m1
               ,  m2->vectors + n_m2_vectors
               ,  pr->vectors + n_m2_vectors
               ,  NULL
               )
            ;  if (maxDensity)
                  mcxVectorSelectHighest
                  (  pr->vectors + n_m2_vectors
                  ,  maxDensity
                  )
         ;  }
      ;  }
   ;  }

   ;  return pr
;  }
      

static mcxIvp* ivpStorage =  NULL;

static mcxIvp* rqIvpStorage
(  
   int         n_ivps
)  
   {  
      ivpStorage
      =  (mcxIvp*) rqRealloc
         (  ivpStorage
         ,  n_ivps * sizeof(mcxIvp)
         ,  RETURN_ON_FAIL
         )

      ;  if (!ivpStorage)
            mcxMemDenied(stderr, "rqIvpStorage", "mcxIvp", n_ivps)
         ,  exit(1)

   ;  return ivpStorage
;  }


