/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_counter_h__
#define zoem_counter_h__

#include "util/txt.h"

/*
 * This module is still a bit shaky and needs a better design.
 * Since it is so small, this is best forgotten until the module grows.
 * Mind the funny yamCtrMake semantics though.
*/


/*
 *  The return value of yamGetCtr should never be freed by caller
*/ 
mcxTing* yamCtrGet
(  mcxTing*  key
)  ;

/*
 * The two below act on counters, not on labels/keys mapping to counters.
*/
void yamCtrSet
(  mcxTing* ctr
,  int   c
)  ;
void yamCtrWrite
(  mcxTing* ctr
,  const char* str
)  ;

/*
 * This one is a bit funny, should only be called if ctr <label>
 * does not yet exist. Returns the new counter associated with label.
*/
mcxTing* yamCtrMake
(  mcxTing* label
)  ;


void yamCounterInitialize   /* library wide init */
(  int   n
)  ;


#endif

