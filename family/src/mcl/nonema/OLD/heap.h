
#ifndef NONEMA_HEAP_H__
#define NONEMA_HEAP_H__

#include "util/iface.h"
#include "nonema/vector.h"
#include "nonema/ivp.h"

/* 
 *
*/

float mcxVectorKBar
(  mcxVector   *vec
,  int         k
,  float       ignore            /* ignore elems larger/smaller than this        */
,  float*      Heap              /* if != NULL becomes pointer to static memory  */
,  mcxBoolean  bLargest
)  ;


#endif

