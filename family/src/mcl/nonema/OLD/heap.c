

#include "nonema/heap.h"
#include <float.h>


static float*     heap           =  NULL;
static int        heapSize       =  0;


float mcxVectorKBar
(
   mcxVector   *vec
,  int         k
,  float       ignore            /*    ignore elements relative to this  */
,  float*      Heap              /*    if != NULL set Heap to heap       */
,  mcxBoolean  bLargest
)  
   {
      int      x
   ;  int      bEven       =  (k+1) % 2

   ;  mcxIvp*  vecIvp      =  vec->ivps
   ;  mcxIvp*  vecMaxIvp   =  vecIvp + vec->n_ivps

   ;  if (k >= vec->n_ivps)
      return(-1.0)

   ;  heap                 =  (float*) rqRealloc
                              (  heap
                              ,  (k+bEven)*sizeof(float)
                              ,  EXIT_ON_FAIL
                              )
   ;  heapSize             =  k


   ;  if (bLargest)
      {  
         for (x=0;x<heapSize;x++)
         *(heap+x)         =  -FLT_MAX

      ;  if (bEven)
         *(heap+heapSize)  =  FLT_MAX

      ;  while(vecIvp < vecMaxIvp)
         {
            float val      =  vecIvp->val

         ;  if ((val > *heap) && (val < ignore ))
            {
               int   root  =  0

            ;  while(1)
               {
                  int   l  =  2*root+1
               ;  int   r  =  l+1
               
               ;  if (l >= heapSize)
                  {
                     *(heap+root)   =  val
                  ;  break
               ;  }
                  else
                  {
                     int d =  *(heap+l) <= *(heap+r)
                           ?  l
                           :  r

                  ;  if (val > *(heap+d))
                     {  *(heap+root)   =  *(heap+d)
                     ;  root           =  d
                  ;  }
                     else
                     {
                        *(heap+root)   =  val
                     ;  break
                  ;  }
                  }
               }
            }

            vecIvp++
      ;  }
   ;  }

      else
      {  
         for (x=0;x<heapSize;x++)
         *(heap+x)         =  FLT_MAX

      ;  if (bEven)
         *(heap+heapSize)  =  -FLT_MAX

      ;  while(vecIvp < vecMaxIvp)
         {
            float val      =  vecIvp->val

         ;  if ((val < *heap) && (val >= ignore))
            {
               int   root  =  0

            ;  while(1)
               {
                  int   l  =  2*root+1
               ;  int   r  =  l+1

               ;  if (l >= heapSize)
                  {  
                     *(heap+root)    =  val
                  ;  break
               ;  }
                  else
                  {
                     int d =  *(heap+l) >= *(heap+r)
                           ?  l
                           :  r
                  ;  if (val < *(heap+d))
                     {
                        *(heap+root) =  *(heap+d)
                     ;  root         =  d
                  ;  }
                     else
                     {
                        *(heap+root) =  val
                     ;  break
                  ;  }
               ;  }
               
            ;  }

         ;  }

         ;  vecIvp++
      ;  }
   ;  }

   ;  if (Heap)
      Heap  =  heap

   ;  return *heap
;  }


