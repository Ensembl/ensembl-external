/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "util/array.h"
#include "util/alloc.h"
#include "util/types.h"
#include <string.h>

void  mcxSplice
(  void*           base1pptr
,  const void*     base2ptr
,  int             size      /*  size of base1 and base2 members          */
,  int         *pn_base1     /*  # base1 elements currently in use        */
,  int         *pN_base1     /*  # base1 elements for which is malloced   */
,  int           O_base1     /*  splice relative to this element          */
,  int           d_base1     /*  delete this number of elements           */
,  int           c_base2     /*  number of elements to copy               */
)  
   {  char **ppr1          =  (char **)   base1pptr
   ;  const char *ptr2     =  (const char *)   base2ptr

   ;  int   n_base1        =  *pn_base1
   ;  int   N_base1        =  *pN_base1
   ;  int   m_base1        =  n_base1 - d_base1 + c_base2

   ;  int   o_base1        =  O_base1 >= 0
                              ?  
                                 O_base1
                              :  
                                 n_base1 + O_base1 + 1

   ;  const char  *dieMsg  =  ""

   ;  if (0)
      {  die
      :  fprintf
         (  stderr
         ,  "[mcxSplice PBD] %s\n"
            "[mcxSplice] [n1, %d] [N1, %d] [o1, %d] [d1, %d] [c2, %d]\n"
         ,  dieMsg
         ,  n_base1, N_base1, O_base1, d_base1, c_base2
         )
      ;  exit(1)
   ;  }

      if (   n_base1    <  0
         ||  N_base1    <  0
         ||  n_base1    >  N_base1
         ||  d_base1    <  0
         ||  c_base2    <  0
         )
      {  dieMsg      =  "integer arguments not consistent"
      ;  goto die
   ;  }

      if (o_base1 < 0 || o_base1 > n_base1)
      {  dieMsg      =  "computed splice offset not in bounds"
      ;  goto die
   ;  }

      if (*ppr1 == NULL && ptr2 == NULL)
      {  dieMsg      =  "source and destination both void"
      ;  goto die
   ;  }

      if (o_base1 + d_base1 > n_base1)
      {  dieMsg      =  "not that many elements to delete"
      ;  goto die
   ;  }

      if (m_base1 > N_base1)
         *ppr1       =  mcxRealloc(*ppr1, size*m_base1, RETURN_ON_FAIL)
      ,  *pN_base1   =  N_base1 = m_base1

   ;  if (m_base1 && *ppr1 == NULL)
         mcxMemDenied(stderr, "mcxSplice", "void", m_base1)
      ,  exit(1)

   ;  if (o_base1 < n_base1)
      memmove
      (  *ppr1 + size*(o_base1 + c_base2)
      ,  *ppr1 + size*(o_base1 + d_base1)
      ,  size*(n_base1 - o_base1 - d_base1)
      )

   ;  if (c_base2)
      memcpy
      (  *ppr1 + size * (o_base1)
      ,  ptr2
      ,  size*(c_base2)
      )
   ;  *pn_base1      =  m_base1
;  }



int mcxSplitsearch
(  void*                key
,  void*                base
,  int                  nr
,  int                  size
,  int                  (*cmp)(const void*, const void*)
,  mcxbool              right
)
   {  int   u     =     nr-1
   ;  int   l     =     0
   ;  int   left  =     right == 0 ? 1 : 0

   ;  if (!base)
      {  fprintf(stderr, "[mcxSplitsearch] warning: received void argument\n")
      ;  return -1
   ;  }
      else if (!cmp(((char*)base)+(nr-1)*size, key) )
      {  return left ? nr-1 : -1
   ;  }
      else if ( cmp(((char*)base)+0, key) )
      {  return left ? -1 : 0
   ;  }
                                       /* invariant: cmp(base[u], key)
                                                    !cmp(base[l], key)
                                        */
      while (l+1 < u)
      {  int   m  =  (l+u)/2
      ;  if (!cmp(((char*)base)+m*size, key) )
            l  =  m
      ;  else
            u  =  m
   ;  }
      return u - left
;  }


int mcxDedup
(  void*                base
,  int                  nmemb
,  int                  size
,  int                  (*cmp)(const void *, const void *)
,  void                 (*merge)(void *, const void *)
)  
   {  int   k  =  0
   ;  int   l  =  0 
      
   ;  while (l < nmemb)
      {  
         if (k != l)
         memcpy(((char*)base) + k * size, ((char*)base) + l * size, size)

      ;  while
         (  ++l < nmemb
         && (  cmp
            ?  (!cmp(((char*)base) + k * size, ((char*)base) + l * size))
            :  (!memcmp(((char*)base) + k*size, ((char*)base) + l*size, size))
            )  
         )  
         {  if (merge)
            {  merge(((char*)base) + k * size, ((char*)base) + l * size)
         ;  }
         }
      ;  k++
   ;  }

      return k       
;  }


/* =======================================================================
 *
 *    The stuff below is a little bit nonsensical. Kept it for nostalgia.
 *
 * =======================================================================
*/
#if 0

typedef struct
{
   void*       ls
;  int         n
;  int         n_alloc       /*  For future functionality */
;  int         size
;
}  mcxArray  ;


typedef struct
{
   mcxArray*   ls
;  int         n
;  int         n_alloc       /*  For future functionality */
;
}  mcxTable ;


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


my_inline void  mcxArrayFree
(  
   mcxArray**  arpp
,  void        (*obRelease)(void *)
)  
   {
      if (*arpp)
      {  mcxArrayRelease(*arpp, obRelease)
      ;  mcxFree(*arpp)
      ;  *arpp  =  NULL
   ;  }
;  }


void        mcxTableFree
(  
   mcxTable**  tablepp
,  void       (*obRelease)(void *)
)  ;  


mcxArray*      mcxArrayInit
(
   mcxArray*   ar
,  int         n
,  int         size
,  void*       (*obInit)    (void *)
)
   {

      char* ob

   ;  if (!ar)
      ar                =  (mcxArray*) mcxAlloc(sizeof(mcxArray), EXIT_ON_FAIL)

   ;  ar->ls            =  (void*) mcxAlloc
                           (  n * size
                           ,  RETURN_ON_FAIL
                           )

   ;  if (n && !ar->ls)
         mcxMemDenied(stderr, "mcxArray", "void", n)
      ,  exit(1)

   ;  ar->n             =  n
   ;  ar->n_alloc       =  n
   ;  ar->size          =  size

   ;  ob                =  ar->ls

   ;  if (obInit)
      {  while (--n >= 0)
         {  
            obInit(ob)
         ;  ob += size
      ;  }
   ;  }

   ;  return ar
;  }


mcxTable*  mcxTableNew
(  
   int      n
,  int      len
,  int      size
,  void*    (*obInit)    (void *)
)  
   {  
      mcxArray     *ar

   ;  mcxTable    *table   =  (mcxTable*) mcxAlloc
                              (  sizeof(mcxTable)
                              ,  EXIT_ON_FAIL
                              )

   ;  table->ls            =  (mcxArray*) mcxAlloc
                              (  n*sizeof(mcxArray)
                              ,  RETURN_ON_FAIL
                              )

   ;  if (n && !table->ls)
         mcxMemDenied(stderr, "mcxTableNew", "mcxArray", n)
      ,  exit(1)

   ;  table->n             =  n  

   ;  ar                   =  table->ls

   ;  while (--n >= 0)
         mcxArrayInit(ar, len, size, obInit)
      ,  ar++

   ;  return table
;  }


void  mcxArrayRelease
(  
   mcxArray*    ar
,  void        (*obRelease)(void *)
)  
   {  
      if (ar)
      {  
         int   n        =  ar->n
      ;  char* ob       =  (char*) ar->ls

      ;  if (obRelease)
         {  while (--n >= 0)
            {  obRelease(ob)
            ;  ob         +=  ar->size
         ;  }
      ;  }

      ;  mcxFree(ar->ls)
      ;  ar->ls         =  NULL
      ;  ar->n          =  0
      ;  ar->n_alloc    =  0
      ;  ar->size       =  0
   ;  }
;  }


void mcxTableFree
(  
   mcxTable**  tablepp
,  void        (*obRelease)(void *)
)
   {  
      if (*tablepp)
      {  
         int   n  =  (*tablepp)->n
      ;  mcxArray * ar =  (*tablepp)->ls

      ;  while (--n >= 0)
            mcxArrayRelease(ar, obRelease)
         ,  ar++

      ;  mcxFree((*tablepp)->ls)
      ;  mcxFree(*tablepp)
      ;  (*tablepp)     =  NULL
   ;  }
;  }

#endif


