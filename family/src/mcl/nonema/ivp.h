/*
// ivp.h                   Index value pairs
*/

#ifndef NONEMA_IVP_H
#define NONEMA_IVP_H

#include "util/alloc.h"

/*
 *
*/


typedef struct
{  
   int         idx
;  float       val
;
}  mcxIvp      ; 


/*
 *
*/


mcxIvp* mcxIvpInstantiate
(  
   mcxIvp*                 prealloc_ivp
,  int                     idx
,  float                   value
)  ;


mcxIvp* mcxIvpInit
(  
   mcxIvp*                 ivp
)  ;


mcxIvp* mcxIvpCreate
(  
   int                     idx
,  float                   value
)  ;


void mcxIvpFree
(  
   mcxIvp**                ivp
)  ;


EXTERN__INLINE__ mcxIvp* mcxIvpInit
(  
   mcxIvp*                 ivp
)  
   {  
      return mcxIvpInstantiate(ivp, -1, 0.0)
;  }


EXTERN__INLINE__ mcxIvp* mcxIvpCreate
(  
   int                     idx
,  float                   value
)  
   {  
      return mcxIvpInstantiate(NULL, idx, value)
;  }


EXTERN__INLINE__ void mcxIvpFree
(  
   mcxIvp**                   p_ivp
)  
   {  
      rqFree(*p_ivp)
   ;  *p_ivp   =  NULL
;  }


/*
 *
*/


int mcxIvpIdxGeq
(  
   const void*             ivp1
,  const void*             ivp2
)  ;


int mcxIvpIdxCmp
(  
   const void*             ivp1
,  const void*             ivp2
)  ;


int mcxIvpIdxRevCmp
(  
   const void*             ivp1
,  const void*             ivp2
)  ;


int mcxIvpValCmp
(  
   const void*             ivp1
,  const void*             ivp2
)  ;


int mcxIvpValRevCmp
(  
   const void*             ivp1
,  const void*             ivp2
)  ;


void mcxIvpMergeDiscard
(  
   void*                   ivp1
,  const void*             ivp2
)  ;


void mcxIvpMergeAdd
(  
   void*                   ivp1
,  const void*             ivp2
)  ;


#endif /* NONEMA_IVP_H */

