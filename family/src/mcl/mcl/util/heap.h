/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef util_heap_h__
#define util_heap_h__


enum
{
   MCX_MIN_HEAP = 10000           /*    find large elements                 */
,  MCX_MAX_HEAP                   /*    find small elements                 */
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
(  int      heapSize
,  int      elemSize
,  int      (*cmp)(const void* lft, const void* rgt)
,  int      HEAPTYPE          /* MIN_HEAP or MAX_HEAP */
)  ;


void mcxHeapFree
(  mcxHeap**   heap
)  ;


void mcxHeapInsert
(  mcxHeap* heap
,  void*    elem
)  ;


#endif

