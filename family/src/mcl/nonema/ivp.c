/*
// mcxIvp                Index value pair
*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "nonema/ivp.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/sign.h"


/*
////////////////////////////////////////////////////////////////////////
//
// Construction, assignment, destruction
//
*/

mcxIvp* mcxIvpInstantiate
(  mcxIvp*                 ivp
,  int                     index
,  float                   value
)  {  
      if (!ivp) ivp  =  (mcxIvp*) rqAlloc(sizeof(mcxIvp), EXIT_ON_FAIL)

   ;  ivp->idx       =  index
   ;  ivp->val       =  value
   
   ;  return ivp
;  }


/*
////////////////////////////////////////////////////////////////////////
//
// Comparison and deduplication
//
*/

int mcxIvpIdxGeq
(  const void*             i1
,  const void*             i2
)  {  return ((mcxIvp*)i1)->idx >= ((mcxIvp*)i2)->idx
;  }

int mcxIvpIdxCmp
(  const void*             i1
,  const void*             i2
)  {  return ((mcxIvp*)i1)->idx - ((mcxIvp*)i2)->idx
;  }

int mcxIvpIdxRevCmp
(  const void*             i1
,  const void*             i2
)  {  return ((mcxIvp*)i2)->idx - ((mcxIvp*)i1)->idx
;  }

int mcxIvpValCmp
(  const void*             i1
,  const void*             i2
)  { 
     int     s  =  float_SIGN(((mcxIvp*)i1)->val - ((mcxIvp*)i2)->val)
   ;  return (s ? s : ((mcxIvp*)i1)->idx - ((mcxIvp*)i2)->idx)
;  }

int mcxIvpValRevCmp
(  const void*             i1
,  const void*             i2
)  {  
      int     s  =  float_SIGN(((mcxIvp*)i2)->val - ((mcxIvp*)i1)->val)
   ;  return (s ? s : ((mcxIvp*)i2)->idx - ((mcxIvp*)i1)->idx)
;  }

void mcxIvpMergeDiscard
(  void*                   i1
,  const void*             i2
)  {
;  }

void mcxIvpMergeAdd
(  void*                   i1
,  const void*             i2
)  {  ((mcxIvp*)i1)->val += ((mcxIvp*)i2)->val
;  }



