
#ifndef NONEMA_HEAP_H__
#define NONEMA_HEAP_H__

  /*  mcxVectorHeapSelect returns a float f such that there are at most
   *  maxDensity elements geq threshold, with the following exception:
   *  If there are more elements equal to f then there can be
   *  more than maxDensity elements.
   *
   *  If heap is not null then the entries in heap will be addresses
   *  of vec->ivps. heap must be used before this function is called
   *  again as the returned pointer point to static memory.
   *
   *  Caller has the option of pruning vec by calling
   *  vectorSelectGqBar or by sorting the heap.
   *
   *  Threshold is used to initialize the heap, it is in effect a lower bound
   *  for f. This may result in a returned f with less than maxDensity
   *  elements geq f.
   */


#include "util/iface.h"
#include "nonema/vector.h"
#include "nonema/ivp.h"


float mcxVectorHeapSelect
(  mcxVector   *vec
,  int         maxDensity
,  float       threshold         /* initialize heap to this */
,  mcxIvp      **heap            /* if NULL ignore          */
,  mcxBoolean  bLargest
)  ;


#endif

