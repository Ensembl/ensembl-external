
#include "util/array.h"
#include "util/alloc.h"
#include "util/types.h"
#include <string.h>

void  mcxSplice
(  
   void*           base1pptr
,  const void*     base2pptr
,  int             size      /*  size of base1 and base2 members          */
,  int         *pn_base1     /*  # base1 elements currently in use        */
,  int         *pN_base1     /*  # base1 elements for which is malloced   */
,  int           o_base1     /*  splice relative to this element          */
,  int           d_base1     /*  delete this number of elements           */
,  int           o_base2     /*  start copying elements at this ofset     */
,  int           c_base2     /*  number of elements to copy               */
)  
   {
      char **ppr1          =  (char **)   base1pptr
   ;  const char **ppr2    =  (const char **)   base2pptr

   ;  int   m_base1        =  *pn_base1 - d_base1 + c_base2

   ;  int   O_base1        =  o_base1 >= 0
                              ?  
                                 o_base1
                              :  
                                 *pn_base1 + o_base1 + 1

   ;  const char  *dieMsg  =  ""
   ;  char        *store   =  NULL

/*
;  fprintf(stdout, "Entering splice\n")
*/
   ;  if (0)
      {
         die
      :  fprintf
         (  stderr
         ,  "[mcxSplice PBD] %s\n"
            "[mcxSplice] [n1, %d] [N1, %d] [o1, %d]"
                       " [d1, %d] [o2, %d] [c2, %d]\n"
         ,  dieMsg
         , *pn_base1, *pN_base1
         ,   o_base1,   d_base1
         ,   o_base2,   c_base2
         )
      ;  exit(1)
   ;  }

   ;  if (  *pn_base1   <  0
         || *pN_base1   <  0
         || *pn_base1   >  *pN_base1
         ||  d_base1    <  0
         ||  o_base2    <  0
         ||  c_base2    <  0
         )
      {  dieMsg      =  "integer arguments not consistent"
      ;  goto die
   ;  }

   ;  if (O_base1 < 0 || O_base1 > *pn_base1)
      {  dieMsg      =  "computed splice offset not in bounds"
      ;  goto die
   ;  }

   ;  if (*ppr1 == NULL && *ppr2 == NULL)
      {  dieMsg      =  "source and destination both void"
      ;  goto die
   ;  }

   ;  if (O_base1 + d_base1 > *pn_base1)
      {  dieMsg      =  "not that many elements to delete"
      ;  goto die
   ;  }

   ;  if (*ppr1 == *ppr2 && c_base2)
      {  
         store       =  (char*) rqRealloc(NULL, size*c_base2, RETURN_ON_FAIL)

      ;  if (!store)
            mcxMemDenied(stderr, "mcxSplice", "char", size*c_base2)
         ,  exit(1)

      ;  memcpy(store,  (*ppr2)+size*(o_base2), size * (c_base2))
      ;  o_base2     =  0
      ;  ppr2        =  (const char**) &store
   ;  }

   ;  if (m_base1 > *pN_base1)
         *ppr1       =  rqRealloc(*ppr1, size*m_base1, RETURN_ON_FAIL)
      ,  *pN_base1   =  m_base1
/*
fprintf(stdout, "[realloc %d %d]\n", size*m_base1, *pN_base1)
*/

   ;  if (m_base1 && *ppr1 == NULL)
         mcxMemDenied(stderr, "mcxSplice", "void", m_base1)
      ,  exit(1)

   ;  if (O_base1 < *pn_base1)
      memmove
      (  *ppr1 + size*(O_base1 + c_base2)
      ,  *ppr1 + size*(O_base1 + d_base1)
      ,  size*(*pn_base1 - O_base1 - d_base1)
      )

   ;  if (c_base2)
      memcpy
      (  *ppr1 + size*(O_base1)
      ,  *ppr2 + size*(o_base2)
      ,  size*(c_base2)
      )

   ;  if (store)
      rqFree(store)

   ;  *pn_base1      =  m_base1
;  }



int mcxSplitsearch
(  
   void*                key
,  void*                base
,  int                  nr
,  int                  size
,  int                  (*cmp)(const void*, const void*)
,  mcxbool              right
)
   {  
      int   u     =     nr-1
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
   ;  while (l+1 < u)
      {  int   m  =  (l+u)/2
      ;  if (!cmp(((char*)base)+m*size, key) )
            l  =  m
      ;  else
            u  =  m
   ;  }
   ;  return u - left
;  }


int mcxDedup
(  
   void*                base
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

   ;  return k       
;  }  


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
      ar                =  (mcxArray*) rqAlloc(sizeof(mcxArray), EXIT_ON_FAIL)

   ;  ar->ls            =  (void*) rqAlloc
                           (  n * size
                           ,  RETURN_ON_FAIL
                           )

   ;  if (n && !ar->ls)
         mcxMemDenied(stderr, "mcxArray", "void", n)
      ,  exit(1)

   ;  ar->n             =  n
   ;  ar->n_alloc       =  n
   ;  ar->size          =  size
   ;  ar->factor        =  1.3

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

   ;  mcxTable    *table   =  (mcxTable*) rqAlloc
                              (  sizeof(mcxTable)
                              ,  EXIT_ON_FAIL
                              )

   ;  table->ls            =  (mcxArray*) rqAlloc
                              (  n*sizeof(mcxArray)
                              ,  RETURN_ON_FAIL
                              )

   ;  if (n && !table->ls)
         mcxMemDenied(stderr, "mcxTableNew", "mcxArray", n)
      ,  exit(1)

   ;  table->n             =  n  
   ;  table->factor        =  1.3

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

      ;  while (--n >= 0)
         {  obRelease(ob)
         ;  ob         +=  ar->size
      ;  }

      ;  rqFree(ar->ls)
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

      ;  rqFree((*tablepp)->ls)
      ;  rqFree(*tablepp)
      ;  (*tablepp)     =  NULL
   ;  }
;  }


