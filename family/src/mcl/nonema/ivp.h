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


EXTERN__INLINE__DECLARE mcxIvp* mcxIvpInit
(  
   mcxIvp*                 ivp
)  ;


EXTERN__INLINE__DECLARE mcxIvp* mcxIvpCreate
(  
   int                     idx
,  float                   value
)  ;


EXTERN__INLINE__DECLARE void mcxIvpFree
(  
   mcxIvp**                ivp
)  ;


EXTERN__INLINE__DEFINE mcxIvp* mcxIvpInit
(  
   mcxIvp*                 ivp
)  
   {  
      return mcxIvpInstantiate(ivp, -1, 0.0)
;  }


EXTERN__INLINE__DEFINE mcxIvp* mcxIvpCreate
(  
   int                     idx
,  float                   value
)  
   {  
      return mcxIvpInstantiate(NULL, idx, value)
;  }


EXTERN__INLINE__DEFINE void mcxIvpFree
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

