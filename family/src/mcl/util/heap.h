
#include "util/array.h"

#ifndef UTIL_HEAP_H__
#define UTIL_HEAP_H__


enum
{
   MIN_HEAP = 10000           /*    find large elements                 */
,  MAX_HEAP                   /*    find small elements                 */
}  ;


typedef struct
{ 
   void     *base
;  int      heapSize
;  int      elemSize
;  int      (*cmp)(const void* lft, const void* rgt)
;  int      type
;  int      n_inserted
;
}  mcxHeap  ;


mcxHeap* mcxHeapNew
(
   int      heapSize
,  int      elemSize
,  int      (*cmp)(const void* lft, const void* rgt)
,  int      HEAPTYPE          /* MIN_HEAP or MAX_HEAP */
)  ;


/*
 *    Does not free the list member. Caller has to do that.
*/


void mcxHeapFree
(
   mcxHeap**   heap
)  ;


void mcxHeapInsert
(
   mcxHeap* heap
,  void*    elem
)  ;


#endif

