
#include <stdio.h>
#include <string.h>

#include "util/txt.h"
#include "util/minmax.h"
#include "util/alloc.h"
#include "util/array.h"
#include "util/hash.h"
#include "util/types.h"


static char snum[50];         /* space for sprintf */


void mcxTxtAlert        
(  const char*          caller
)  {  fprintf(stderr, "[%s] void txt argument\n", caller)
   ;  return
;  }


void mcxTxtRelease
(  void* txtv
)  {  
      if (txtv)
      rqFree(((mcxTxt*)txtv)->str)
;  }


void mcxTxtFree
(  void            *txtpp
)  {
      mcxTxt*  txt   =    *((mcxTxt**) txtpp)

   ;  if (txt)
      {  
         mcxTxtRelease(txt)
      ;  rqFree(txt)

      ;  *((mcxTxt**) txtpp)  =  NULL
   ;  }
;  }


mcxTxt* mcxTxtEnsure
(  
   mcxTxt*  txt
,  int      length
)  
   {
      int   mylength =  ((int) (1.3 * length)) + 3

   ;  if (!txt)
      txt  =  (mcxTxt*) mcxTxtInit(NULL)
   
   ;  if (length < 0)
         fprintf
         (  stderr
         ,  "[mcxTxtEnsure PBD] request for negative length [%d]\n"
         ,  length
         )
      ,  exit(1)

   ;  else if (length <= txt->mxl)

   ;  else
      {  
         txt->str = (char*) rqRealloc(txt->str, mylength, RETURN_ON_FAIL)

      ;  if (mylength && !txt->str)
            mcxMemDenied(stderr, "mcxTxtEnsure", "char", mylength)
         ,  exit(1)

      ;  txt->mxl               =  mylength-1
      ;  *(txt->str+txt->mxl)  =  '\0'
   ;  }

   ;  *(txt->str+length)        =  '\0'

   ;  return txt
;  }


char*    mcxTxtChrcpy
(  mcxTxt*  txt
)  {
      char*    string

   ;  if (!txt)
         mcxTxtAlert("mcxTxtChars PBD")
      ,  exit(1)

   ;  string   =  rqAlloc(sizeof(char) * ((txt->len)+1), EXIT_ON_FAIL)

   ;  if (txt->str)
      {  strncpy(string, txt->str, txt->len)
      ;  *(string+txt->len)   =  '\0'
   ;  }
      else
      {  *(string) =  '\0'
   ;  }

   ;  return(string)
;  }


mcxTxt*  mcxTxtInteger
(  mcxTxt*  dst
,  int      x
)  {  sprintf(snum, "%d", x)
   ;  return   dst ? mcxTxtWrite(dst, snum) : mcxTxtNew(snum)
;  }


void* mcxTxtInit
(  void *  txtv
)  {
      mcxTxt *txt   =  (mcxTxt*) txtv

   ;  if (!txt)
      txt           =  (mcxTxt*) rqAlloc(sizeof(mcxTxt), EXIT_ON_FAIL)

   ;  txt->str      =  (char*) rqAlloc(sizeof(char), EXIT_ON_FAIL)
   ;  *(txt->str+0) =  '\0'
   ;  txt->len      =  0
   ;  txt->mxl      =  0

   ;  return  txt
;  }


/*
 *    Take string into an existing txt or into a new txt
*/

mcxTxt* mcxTxtInstantiate
(  mcxTxt*           txt
,  const char*       string
)  {  
      int   length         =  string ? strlen(string) : 0

   ;  txt  = mcxTxtEnsure(txt, length)     /* handles txt==NULL case */

	;  if (string)
      {  strncpy(txt->str, string, length)
      ;  *(txt->str+length)  =  '\0'
   ;  }

   ;  txt->len            =  length

	;  return txt
;  }


u32 mcxTxtHash
(  const void* txt
)  {  return(mcxDPhash(((mcxTxt*) txt)->str, ((mcxTxt*) txt)->len))
;  }


int mcxTxtCmp
(  const void* t1
,  const void* t2
)  {  
      return (strcmp(((mcxTxt*)t1)->str, ((mcxTxt*)t2)->str))
;  }


mcxTxt* mcxTxtSplice
(  mcxTxt*        txt
,  const char**   pstr
,  int            d_offset
,  int            n_delete
,  int            s_offset
,  int            n_copy
)  {  
      int      newlen   =  txt->len - n_delete + n_copy

   ;  if (txt == NULL)
         mcxTxtAlert("mcxTxtSplice PBD")
      ,  exit(1)

   ;  if (newlen < 0)
      fprintf
      (  stderr
      ,  "[mcxTxtSplice PBD] arguments result in negative length\n"
      )
   
   ;  txt                 =  mcxTxtEnsure(txt, newlen)
   ;  *(txt->str+newlen)  =  '\0'
                                          /*    
                                           *    mcxSplice does not affect
                                           *    newlen position.
                                           */
   ;  mcxSplice
      (  &(txt->str)
      ,  pstr
      ,  sizeof(char)
      ,  &(txt->len)
      ,  &(txt->mxl)
      ,  d_offset
      ,  n_delete
      ,  s_offset
      ,  n_copy
      )

   ;  if (txt->len != newlen)
         fprintf
         (  stderr
         ,  "[mcxSpliceTxt PBD] disagreement with mcxSplice on new length\n"
         )
      ,  exit(1)

   ;  return txt
;  }



#ifndef SPLICE_WRAPPING


mcxTxt* mcxTxtShrink
(  mcxTxt* txt
,  int width
)  {  
      if (txt == NULL)
         mcxTxtAlert("mcxTxtShrink PBD")
      ,  exit(1)

	;  if (width < 0)
      width = txt->len + width

   ;  if (width <= 0)
      { /*
         *     The if condition handles implicitly the str=NULL case.
         */
         if (txt->len)
         {  *(txt->str)   =  '\0'
         ;  txt->len      =  0
      ;  }
   ;  }
      else if (width > 0 && width <= txt->len)
      {  
         txt->len         =  width
      ;  *(txt->str+txt->len) = '\0'
   ;  }

	;  return txt
;  }


mcxTxt* mcxTxtInsert
(  mcxTxt* txt
,  const char* string
,  int position
)  {  
      int width, offset, oldlen, i

   ;  if (txt == NULL)
         mcxTxtAlert("mcxTxtInsert PBD")
      ,  exit(1)

   ;  if (txt->str == NULL)
      return mcxTxtInstantiate(txt, string)

   ;  if (string == NULL || string[0] == '\0')
      return txt

   ;  oldlen            =  txt->len
   ;  width             =  strlen(string)
   ;  offset            =  position >= 0 
                           ? MIN(position ,  oldlen) 
                           : MAX(0        ,  oldlen + position + 1)

   ;  mcxTxtEnsure(txt, oldlen + width)

        /*    the part below can be done more efficiently with memcpy if
         *    we are sure that blocks can be moved overlappingly.
         */

   ;  for (i=oldlen+width-1;i>=offset+width;i--)
      {  *(txt->str+i) = *(txt->str+(i-width))
   ;  }

   ;  strncpy(txt->str+offset, string, width)

   ;  txt->len = oldlen + width
   ;  *(txt->str+txt->len) = '\0'

   ;  return txt
;  }

#endif

