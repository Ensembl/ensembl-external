

#include "nonema/heap.h"
#include <float.h>


static mcxIvp**   ivpHeap        =  NULL;
static mcxIvp**   ivpHeapRoot    =  NULL;

static mcxIvp*    ivpHeapSup     =  NULL;
static mcxIvp*    ivpHeapInf     =  NULL;

static int        ivpHeapSize    =  0;


void ivpHeapInsertSmaller
(  mcxIvp* vecIvp
,  int rootidx
)  ;


void ivpHeapInsertLarger
(  mcxIvp* vecIvp
,  int rootidx
)  ;


float mcxVectorHeapSelect
(  mcxVector   *vec
,  int         k
,  float       threshold         /* ignore elements relative to threshold  */
,  mcxIvp      **heap            /* if NULL ignore                         */
,  mcxBoolean  bLargest
)  {
      int      x
   ;  int      bEven       =  (k+1) % 2

   ;  mcxIvp*  vecIvp      =  vec->ivps
   ;  mcxIvp*  vecMaxIvp   =  vecIvp + vec->n_ivps

   ;  ivpHeap           =  (mcxIvp**) rqRealloc
                           (  ivpHeap
                           ,  (k+bEven)*sizeof(mcxIvp*)
                           ,  EXIT_ON_FAIL
                           )
   ;  ivpHeapRoot       =  ivpHeap
   ;  ivpHeapSize       =  k
   ;  ivpHeapSup        =  mcxIvpInstantiate(ivpHeapSup, -1, FLT_MAX)
   ;  ivpHeapInf        =  mcxIvpInstantiate(ivpHeapInf, -1, -FLT_MAX)

   ;  if (k >= vec->n_ivps)
      return(-FLT_MAX)

   ;  if (bLargest)
      {  
         for (x=0;x<ivpHeapSize;x++)
         *(ivpHeap+x)      =  ivpHeapInf

      ;  if (bEven)
         *(ivpHeap+ivpHeapSize)
                           =  ivpHeapSup

      ;  while(vecIvp < vecMaxIvp)
         {
            if (vecIvp->val < threshold &&  vecIvp->val > (*ivpHeapRoot)->val)
            ivpHeapInsertLarger(vecIvp, 0)

         ;  vecIvp++
      ;  }
   ;  }

      else
      {  
         for (x=0;x<ivpHeapSize;x++)
         *(ivpHeap+x)      =  ivpHeapSup

      ;  if (bEven)
         *(ivpHeap+ivpHeapSize)
                           =  ivpHeapInf

      ;  while(vecIvp < vecMaxIvp)
         {
            if (vecIvp->val >= threshold && vecIvp->val < (*ivpHeapRoot)->val)
            ivpHeapInsertSmaller(vecIvp, 0)

         ;  vecIvp++
      ;  }
   ;  }

   ;  if (heap)
      heap  =  ivpHeap

   ;  if ((*ivpHeapRoot)->val < -10.0)
      fprintf
      (stderr, "%4d <- %4d, root value is sup\n", k, vec->n_ivps)

   ;  return (*ivpHeapRoot)->val
;  }


void ivpHeapInsertLarger
(  mcxIvp* vecIvp
,  int rootidx
)  {
      int   lftidx   =  2*rootidx+1

   ;  if (lftidx >= ivpHeapSize)          /* at leaf level */
      *(ivpHeap+rootidx)  =  vecIvp

   ;  else
      {  int dstidx  =  (*(ivpHeap+lftidx))->val <= (*(ivpHeap+lftidx+1))->val
                     ?  lftidx
                     :  lftidx + 1
      ;  if (vecIvp->val > (*(ivpHeap+dstidx))->val)
         {  *(ivpHeap+rootidx)   =  *(ivpHeap+dstidx)
         ;  ivpHeapInsertLarger(vecIvp, dstidx)
      ;  }
         else
         *(ivpHeap+rootidx)      =  vecIvp
   ;  }
;  }


void ivpHeapInsertSmaller
(  mcxIvp* vecIvp
,  int rootidx
)  {
      int   lftidx   =  2*rootidx+1

   ;  if (lftidx >= ivpHeapSize)          /* at leaf level */
      *(ivpHeap+rootidx)  =  vecIvp

   ;  else
      {  int dstidx  =  (*(ivpHeap+lftidx))->val >= (*(ivpHeap+lftidx+1))->val
                     ?  lftidx
                     :  lftidx + 1
      ;  if (vecIvp->val < (*(ivpHeap+dstidx))->val)
         {  *(ivpHeap+rootidx)   =  *(ivpHeap+dstidx)
         ;  ivpHeapInsertSmaller(vecIvp, dstidx)
      ;  }
         else
         *(ivpHeap+rootidx)      =  vecIvp
   ;  }
;  }


