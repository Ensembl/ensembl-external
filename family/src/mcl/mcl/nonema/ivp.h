/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef nonema_ivp_h__
#define nonema_ivp_h__

#include "types.h"

#include "util/alloc.h"


typedef struct
{  
   int         idx
;  real        val
;
}  mclIvp      ; 


/*
 *
*/


mclIvp* mclIvpInstantiate
(  mclIvp*                 prealloc_ivp
,  int                     idx
,  real                    value
)  ;


mclIvp* mclIvpInit
(  mclIvp*                 ivp
)  ;


mclIvp* mclIvpCreate
(  int                     idx
,  real                    value
)  ;


void mclIvpFree
(  mclIvp**                ivp
)  ;


int mclIvpIdxGeq
(  const void*             ivp1
,  const void*             ivp2
)  ;


int mclIvpIdxCmp
(  const void*             ivp1
,  const void*             ivp2
)  ;


int mclIvpIdxRevCmp
(  const void*             ivp1
,  const void*             ivp2
)  ;


int mclIvpValCmp
(  const void*             ivp1
,  const void*             ivp2
)  ;


int mclIvpValRevCmp
(  const void*             ivp1
,  const void*             ivp2
)  ;


void mclIvpMergeDiscard
(  void*                   ivp1
,  const void*             ivp2
)  ;


void mclIvpMergeAdd
(  void*                   ivp1
,  const void*             ivp2
)  ;


#endif /* NONEMA_IVP_H */

