/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "ivp.h"

#include "util/alloc.h"
#include "util/types.h"
#include "util/sign.h"


mclIvp* mclIvpInstantiate
(  mclIvp*                 ivp
,  int                     index
,  float                   value
)  {  
      if (!ivp) ivp  =  (mclIvp*) mcxAlloc(sizeof(mclIvp), EXIT_ON_FAIL)

   ;  ivp->idx       =  index
   ;  ivp->val       =  value
   
   ;  return ivp
;  }

int mclIvpIdxGeq
(  const void*             i1
,  const void*             i2
)  {  return ((mclIvp*)i1)->idx >= ((mclIvp*)i2)->idx
;  }

int mclIvpIdxCmp
(  const void*             i1
,  const void*             i2
)  {  return ((mclIvp*)i1)->idx - ((mclIvp*)i2)->idx
;  }

int mclIvpIdxRevCmp
(  const void*             i1
,  const void*             i2
)  {  return ((mclIvp*)i2)->idx - ((mclIvp*)i1)->idx
;  }

int mclIvpValCmp
(  const void*             i1
,  const void*             i2
)  {  int     s  =  SIGN(((mclIvp*)i1)->val - ((mclIvp*)i2)->val)
   ;  return (s ? s : ((mclIvp*)i1)->idx - ((mclIvp*)i2)->idx)
;  }

int mclIvpValRevCmp
(  const void*             i1
,  const void*             i2
)  {  int     s  =  SIGN(((mclIvp*)i2)->val - ((mclIvp*)i1)->val)
   ;  return (s ? s : ((mclIvp*)i2)->idx - ((mclIvp*)i1)->idx)
;  }

void mclIvpMergeDiscard
(  void*                   i1
,  const void*             i2
)  {
;  }

void mclIvpMergeAdd
(  void*                   i1
,  const void*             i2
)  {  ((mclIvp*)i1)->val += ((mclIvp*)i2)->val
;  }


my_inline mclIvp* mclIvpInit
(  mclIvp*                 ivp
)  
   {  return mclIvpInstantiate(ivp, -1, 0.0)
;  }


my_inline mclIvp* mclIvpCreate
(  int                     idx
,  real                    value
)  
   {  return mclIvpInstantiate(NULL, idx, value)
;  }


my_inline void mclIvpFree
(  mclIvp**                   p_ivp
)  
   {  mcxFree(*p_ivp)
   ;  *p_ivp   =  NULL
;  }


