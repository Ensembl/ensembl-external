
#ifndef util_array__
#define util_array__

#include "util/types.h"
#include "util/alloc.h"


typedef struct
{
   void*       ls
;  int         n
;  int         n_alloc       /*  For future functionality */
;  int         size
;  float       factor        /*  For future functionality */
;
}  mcxArray  ;


typedef struct
{
   mcxArray*   ls
;  int         n
;  int         n_alloc       /*  For future functionality */
;  float       factor        /*  For future functionality */
;
}  mcxTable ;


void  mcxSplice
(  
   void*           base1pptr /*  _address_ of pointer to elements       */
,  const void*     base2pptr /*  _address_ of pointer to elements       */
,  int             size      /*  size of base1 and base2 members        */
,  int         *pn_base1     /*  total length of elements after base1   */
,  int         *pN_base1     /*  number of alloc'ed elements for base1  */
,  int           o_base1     /*  splice relative to this ofset          */
,  int           d_base1     /*  delete this number of elements         */
,  int           o_base2     /*  start copying elements at this ofset   */
,  int           c_base2     /*  number of elements to copy             */
)  ;


int mcxDedup
(  
   void*       base     
,  int         nmemb    
,  int         size     
,  int        (*cmp)(const void *, const void *)
,  void       (*merge)(void *, const void *)
)  ;


/*
 *     Search based on two-valued compare (one of <, <=, >, >=). Key is always
 *     put into the second argument of cmp.
 *
 *     It is assumed that cmp(base[i], key) is ascending in i. That is, it
 *     produces a row of the kind [00000011111111], where all zeros or all ones
 *     are allowed. Splitsearch returns the index of the leftmost 1 (if right
 *     is 1), or the index of the rightmost 0 (if right is 0).
*/

int mcxSplitsearch
(  
   void*       key
,  void*       base
,  int         nr
,  int         size
,  int        (*cmp)(const void*, const void*)
,  mcxbool     right
)  ;


mcxArray* mcxArrayInit
(  
   mcxArray    *ar
,  int         n
,  int         size
,  void*      (*obInit)    (void *)
)  ;


mcxTable*   mcxTableNew
(  
   int         n
,  int         len
,  int         size
,  void*      (*obInit)    (void *)
)  ;  


void        mcxArrayRelease
(  
   mcxArray*  ar
,  void       (*obRelease)(void *)
)  ;  


void        mcxArrayFree
(  
   mcxArray**  arpp
,  void        (*obRelease)(void *)
)  ;


EXTERN__INLINE__ void  mcxArrayFree
(  
   mcxArray**  arpp
,  void        (*obRelease)(void *)
)  
   {
      if (*arpp)
      {  mcxArrayRelease(*arpp, obRelease)
      ;  rqFree(*arpp)
      ;  *arpp  =  NULL
   ;  }
;  }


void        mcxTableFree
(  
   mcxTable**  tablepp
,  void       (*obRelease)(void *)
)  ;  


#endif

