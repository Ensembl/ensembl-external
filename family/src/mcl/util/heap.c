

#include "util/heap.h"
#include "util/types.h"


mcxHeap* mcxHeapNew
(
   int         heapSize
,  int         elemSize
,  int (*cmp)  (const void* lft, const void* rgt)
,  int         type           /* MIN_HEAP or MAX_HEAP */
)
   {
      mcxHeap* heap     =  (mcxHeap*) rqAlloc(sizeof(mcxHeap), EXIT_ON_FAIL)
   ;  char*    base

   ;  heap->base        =  rqAlloc (heapSize*elemSize, EXIT_ON_FAIL)
   ;  heap->heapSize    =  heapSize
   ;  heap->elemSize    =  elemSize

   ;  heap->cmp         =  cmp
   ;  heap->type        =  type
   ;  heap->n_inserted  =  0

   ;  base              =  (char*) heap->base

   ;  if (type != MIN_HEAP && type != MAX_HEAP)
      {
         fprintf
         (  stderr
         ,  "[mcxHeapNew PBD] unknown heap type\n"
         )
      ;  exit(1)
   ;  }

   ;  return heap
;  }


void mcxHeapFree
(
   mcxHeap**   heap
)  
   {
      if (*heap)
      {  
         if ((*heap)->base)
         rqFree((*heap)->base)
         
      ;  rqFree(*heap)
      ;  *heap       =  NULL
   ;  }
;  }


void mcxHeapInsert
(
   mcxHeap* heap
,  void*    elem
)  
   {  
      char* heapRoot =  (heap->base)+0
   ;  char* elemch   =  (char *) elem
   ;  int   elsz     =  heap->elemSize
   ;  int   hpsz     =  heap->heapSize

   ;  int (*cmp)(const void *, const void*)
                     =  heap->cmp

   ;  if (heap->type == MIN_HEAP)
      {
         if (heap->n_inserted  < hpsz)
         {
            int   i  =  heap->n_inserted

         ;  while (i != 0 && (cmp)(heapRoot+elsz*((i-1)/2), elemch) > 0)
            {
               memcpy
               (  heapRoot + i*elsz
               ,  heapRoot + elsz*((i-1)/2)
               ,  elsz
               )
            ;  i     =  (i-1)/2
         ;  }

            memcpy
            (  heapRoot + i*elsz
            ,  elemch
            ,  elsz
            )
         ;  heap->n_inserted++
      ;  }

         else if ((cmp)(elemch, heapRoot) > 0)
         {
            int   root     =  0
         ;  int   d

         ;  while ((d = 2*root+1) < hpsz)
            {
               if (  (d+1 < hpsz)
                  && (cmp)(heapRoot + d*elsz, heapRoot + (d+1)*elsz) > 0
                  )
               d++

            ;  if ((cmp)(elemch, heapRoot + d*elsz) > 0)
               {
                  memcpy(heapRoot+root*elsz, heapRoot+d*elsz, elsz)
               ;  root     =  d
            ;  }
               else
               {  break
            ;  }
         ;  }

            memcpy(heapRoot+root*elsz, elemch, elsz)
      ;  }
   ;  }

      else if (heap->type == MAX_HEAP)
      {
         if (heap->n_inserted  < hpsz)
         {
            int   i  =  heap->n_inserted

         ;  while (i != 0 && (cmp)(heapRoot+elsz*((i-1)/2), elemch) < 0)
            {
               memcpy
               (  heapRoot + i*elsz
               ,  heapRoot + elsz*((i-1)/2)
               ,  elsz
               )
            ;  i     =  (i-1)/2
         ;  }

            memcpy
            (  heapRoot + i*elsz
            ,  elemch
            ,  elsz
            )
         ;  heap->n_inserted++
      ;  }

         else if ((cmp)(elemch, heapRoot) < 0)
         {
            int   root     =  0
         ;  int   d

         ;  while ((d = 2*root+1) < hpsz)
            {
               if (  (d+1<hpsz)
                  && (cmp)(heapRoot + d*elsz, heapRoot + (d+1)*elsz) < 0
                  )
               d++

            ;  if ((cmp)(elemch, heapRoot + d*elsz) < 0)
               {
                  memcpy(heapRoot+root*elsz, heapRoot+d*elsz, elsz)
               ;  root     =  d
            ;  }
               else
               {  break
            ;  }
         ;  }

            memcpy(heapRoot+root*elsz, elemch, elsz)
      ;  }
   ;  }

;  }


