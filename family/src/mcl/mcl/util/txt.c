/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>
#include <string.h>

#include "compile.h"
#include "txt.h"
#include "minmax.h"
#include "alloc.h"
#include "array.h"
#include "hash.h"
#include "compile.h"
#include "types.h"
#include "pool.h"


#if !MCX_UTIL_THREADED
static MP* tingPool_g = NULL;
#endif


void mcxTingAlert        
(  const char*          caller
)
   {  fprintf(stderr, "[%s] void ting argument\n", caller)
   ;  return
;  }


void mcxTingRelease
(  void* tingv
)
   {  if (tingv)
      mcxFree(((mcxTing*)tingv)->str)
;  }


void mcxTingFree_v
(  void  *tingpp
)
   {  mcxTingFree((mcxTing**) tingpp)
;  }


void mcxTingFree
(  mcxTing            **tingpp
)
   {  mcxTing*  ting   =    *tingpp

   ;  if (ting)
      {  
         if (ting->str)
         mcxFree(ting->str)

#if MCX_UTIL_THREADED
      ;  mcxFree(ting)
#else
      ;  mp_free(tingPool_g, ting)
#endif
      ;  *tingpp = NULL
   ;  }
;  }


void mcxTingShrink
(  mcxTing*  ting
,  int      length
)
   {  if (!ting)
         mcxTingAlert("mcxTingShrink")
      ,  exit(1)

   ;  if (length < 0 || length > ting->len)
      {  fprintf(stderr, "[mcxTingShrink] arg combo false\n")
      ;  return
   ;  }
      else
      {  *(ting->str+length) = '\0'
      ;  ting->len = length;
   ;  }
;  }


mcxTing* mcxTingEnsure
(  mcxTing*  ting
,  int      length
)  
   {  if (!ting)
      ting  =  (mcxTing*) mcxTingInit(NULL)
   
   ;  if (length < 0)
         fprintf
         (  stderr
         ,  "[mcxTingEnsure PBD] request for negative length [%d]\n"
         ,  length
         )
      ,  exit(1)

   ;  else if (length <= ting->mxl)

   ;  else
      {  
         ting->str = (char*) mcxRealloc(ting->str, length+1, RETURN_ON_FAIL)

      ;  if (!ting->str)
            mcxMemDenied(stderr, "mcxTingEnsure", "char", length)
         ,  exit(1)

      ;  ting->mxl             =  length
      ;  *(ting->str+ting->mxl) =  '\0'
   ;  }

  /*  *(ting->str+ting->len)    =  '\0'
   *  REMOVING THIS. WHY THE HELL DID I REMOVE THIS?????
   *  II HHAADD AA GGOOOODD RREEAASSOONN AANNDD AAMM SSTTIICCKKIINNGG
   *  WWIITTHH TTHHIISS.
   *  __MM_OO_RR_EE__ __SS_TT_RR_EE_SS__ and legibility will suffer.
  */
   ;  return ting
;  }


mcxTing*  mcxTingInteger
(  mcxTing*  dst
,  int      x
)
   {  char num[28]

   ;  sprintf(num, "%d", x)
   ;  if (dst)
      {  mcxTingWrite(dst, num)
      ;  return dst
   ;  }

   ;  return mcxTingNew(num)
;  }


void* mcxTingInit
(  void *  tingv
)
   {  mcxTing *ting  =  (mcxTing*) tingv

   ;  if (!ting)
      {
#if MCX_UTIL_THREADED
         ting =  (mcxTing*) mcxAlloc(sizeof(mcxTing), EXIT_ON_FAIL)
#else
         if (!tingPool_g)
         tingPool_g = mp_init(4096, MP_EXPONENTIAL, sizeof(mcxTing), 0)
      ;  ting = (mcxTing*) mp_alloc(tingPool_g)
#endif
   ;  }

   ;  ting->str      =  (char*) mcxAlloc(sizeof(char), EXIT_ON_FAIL)
   ;  *(ting->str+0) =  '\0'
   ;  ting->len      =  0
   ;  ting->mxl      =  0

   ;  return  ting
;  }


/*
 *    Take string into an existing ting or into a new ting
*/

mcxTing* mcxTingInstantiate
(  mcxTing*           ting
,  const char*       string
)
   {  int   length         =  string ? strlen(string) : 0

   ;  ting  = mcxTingEnsure(ting, length)     /* handles ting==NULL case */

	;  if (string)
      {  strncpy(ting->str, string, length)
      ;  *(ting->str+length)  =  '\0'
   ;  }

   ;  ting->len            =  length

	;  return ting
;  }


int mcxTingCmp
(  const void* t1
,  const void* t2
)
   {  return (strcmp(((mcxTing*)t1)->str, ((mcxTing*)t2)->str))
;  }


void mcxTingSplice
(  mcxTing*        ting
,  const char*    pstr
,  int            d_offset
,  int            n_delete
,  int            n_copy
)
   {  int      newlen   =  ting->len - n_delete + n_copy

   ;  if (ting == NULL)
         mcxTingAlert("mcxTingSplice PBD")
      ,  exit(1)

   ;  if (newlen < 0)
      fprintf
      (  stderr
      ,  "[mcxTingSplice PBD] arguments result in negative length\n"
      )
   
  /*
   *  essential: mcxSplice does not know to allocate room for '\0'
  */
   ;  mcxTingEnsure(ting, newlen)

   ;  mcxSplice
      (  &(ting->str)
      ,  pstr
      ,  sizeof(char)
      ,  &(ting->len)
      ,  &(ting->mxl)
      ,  d_offset
      ,  n_delete
      ,  n_copy
      )

  /*
   *  essential: mcxSplice might have realloced, so has to be doen afterwards.
  */
   ;  *(ting->str+newlen)  =  '\0'

   ;  if (ting->len != newlen)
         fprintf
         (  stderr
         ,  "[mcxSpliceting PBD] disagreement with mcxSplice on new length\n"
         )
      ,  exit(1)
;  }


u32 mcxTingDJBhash
(  const void* ting
)
   {  return(mcxBJhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingBDBhash
(  const void* ting
)
   {  return(mcxBDBhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingBJhash
(  const void* ting
)
   {  return(mcxBJhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingCThash
(  const void* ting
)
   {  return(mcxCThash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingDPhash
(  const void* ting
)
   {  return(mcxDPhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingELFhash
(  const void* ting
)
   {  return(mcxELFhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingSvDhash
(  const void* ting
)
   {  return(mcxSvDhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingSvD2hash
(  const void* ting
)
   {  return(mcxSvD2hash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingSvD1hash
(  const void* ting
)
   {  return(mcxSvD1hash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


u32 mcxTingHash
(  const void* ting
)
   {  return(mcxDPhash(((mcxTing*) ting)->str, ((mcxTing*) ting)->len))
;  }


my_inline mcxTing* mcxTingNew
(  const char* str
)  {  return mcxTingInstantiate(NULL, str)
;  }


my_inline mcxTing* mcxTingNNew
(  const char*       str
,  int               n
)  {  
      mcxTing*  ting   =  mcxTingEnsure(NULL, n)
   ;  strncpy(ting->str, str, n)
   ;  *(ting->str+n) = '\0'
   ;  ting->len = n
   ;  return ting
;  }


my_inline mcxTing* mcxTingEmpty
(  mcxTing*           ting
,  int               len
)  {
      ting               =   mcxTingEnsure(ting, len)
   ;  *(ting->str+0)     =  '\0'
   ,  ting->len          =  0
   ;  return ting
;  }


my_inline void mcxTingWrite
(  mcxTing*           ting
,  const char*       str
)  {  
      if (ting==NULL)
      mcxTingAlert("mcxTingWrite")
   ;  else
      mcxTingInstantiate(ting, str)
;  }


my_inline void mcxTingNWrite
(  mcxTing*           ting
,  const char*       str
,  int               n
)  {  
      if (ting==NULL)
      mcxTingAlert("mcxTingNWrite")
   ;  else
      {  mcxTingEnsure(ting, n)
      ;  strncpy(ting->str, str, n)
      ;  *(ting->str+n) = '\0'
      ;  ting->len = n
   ;  }
;  }


my_inline char* mcxTingStr
(  mcxTing*           ting
)  {  
      char* str  =  mcxAlloc(ting->len+1, EXIT_ON_FAIL)
   ;  memcpy(str, ting->str, ting->len)         
   ;  *(str+ting->len) = '\0'
   ;  return str
;  }



my_inline void mcxTingAppend
(  mcxTing*              ting
,  const char*          str
)  {  
      mcxTingSplice
      (  ting
      ,  str
      , -1                             /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  str? strlen(str) : 0          /*    string length     */
      )
;  }


my_inline void mcxTingNAppend
(  mcxTing*              ting
,  const char*          str
,  int                  n
)  {  
      mcxTingSplice
      (  ting
      ,  str
      , -1                             /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  n                             /*    string length     */
      )
;  }


my_inline void mcxTingInsert
(  mcxTing*              ting
,  const char*          str
,  int                  offset
)  {  
      mcxTingSplice
      (  ting
      ,  str
      ,  offset                        /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  str? strlen(str) : 0          /*    string length     */
      )
;  }


my_inline void mcxTingNInsert
(  mcxTing*             ting
,  const char*          str
,  int                  offset
,  int                  length
)  {  
      mcxTingSplice
      (  ting
      ,  str
      ,  offset                        /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  length                        /*    length of str     */
      )
;  }


my_inline void mcxTingDelete
(  mcxTing*           ting
,  int               offset
,  int               width
)  {
      const char*    str   =  NULL

   ;  mcxTingSplice
      (  ting
      ,  str
      ,  offset                        /*    splice offset     */
      ,  width                         /*    delete width      */
      ,  0                             /*    string length     */
      )
;  }
