/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_array_h__
#define util_array_h__

#include "types.h"
#include "alloc.h"


void  mcxSplice
(  void*           base1pptr /*  _address_ of pointer to elements       */
,  const void*     base2ptr  /*  pointer to elements                    */
,  int             size      /*  size of base1 and base2 members        */
,  int         *pn_base1     /*  total length of elements after base1   */
,  int         *pN_base1     /*  number of alloc'ed elements for base1  */
,  int           o_base1     /*  splice relative to this ofset          */
,  int           d_base1     /*  delete this number of elements         */
,  int           c_base2     /*  number of elements to copy             */
)  ;


int mcxDedup
(  void*          base     
,  int            nmemb    
,  int            size     
,  int            (*cmp)(const void *, const void *)
,  void           (*merge)(void *, const void *)
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
(  void*       key
,  void*       base
,  int         nr
,  int         size
,  int        (*cmp)(const void*, const void*)
,  mcxbool     right
)  ;


#endif

