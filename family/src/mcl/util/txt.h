
#ifndef UTIL_TXT__
#define UTIL_TXT__

#include <string.h>
#include "util/alloc.h"
#include "util/types.h"
#include "util/hash.h"

#define SPLICE_WRAPPING 1


/*
 *    str:  array of chars
 *
 *    len:  length of first string in str (excluding '\0')
 *          *(str+len) == '\0'
 *
 *    mxl:  current allocated number of writable char's (excluding '\0')
 *          Allocated amount is mxl+1
 *          *(str+mxl) == '\0'
 *
 *    mcxTxtEnsure is the only routine allowed to fiddle with mxl.
 *    (apart from mcxTxtInit which sets it to zero).
 *    Future option could be something like mcxTxtFinalize,
 *    releasing unused memory.
 * 
 *    Behind the scenes the routines try to think of a NULL str member
 *    as being identical to a "\0" str.
 *    They will for example happily append to a NULL str.
 *    This solves a lot of headaches and causes some new ones.
 *    If you are unsure, use mcxTxtGetStr to access a string.
 * 
 *    Routines marked `+' and `#' will accept txt==NULL argument.
 *    Routines marked `#' should not be called other than by txt routines
 * 
 *                  #txtInit
 *                  /       \
 *          #txtEnsure <- #txtInstantiate
 *          :      \               :                   
 *  +EmptyString  txtSplice   +txtNew,Write
 *   NWrite           :               
 *                    :
 *           txtAppend,Insert,Delete
*/

typedef struct {
   char  *str;
   int   len;
   int   mxl;
}      
   mcxTxt;


/* ================================================================== */


void mcxTxtAlert        
(  const char*          caller
)  ;

                    /*
                     *     Accepts NULL argument!
                     *     void arguments so that it can be passed.
                     */
void* mcxTxtInit
(  void*             txt
)  ;  

                    /*
                     *     Accepts NULL argument!
                     */
mcxTxt* mcxTxtInstantiate
(  mcxTxt*           dst_txt
,  const char*       string
)  ;  

                    /*
                     *     Accepts NULL argument!
                     */
mcxTxt* mcxTxtEnsure
(  mcxTxt*           txt
,  int               length
)  ;  


/* ================================================================== */


mcxTxt* mcxTxtNew
(  const char*       string
)  ;

                    /*
                     *     Accepts NULL argument!
                     */
mcxTxt* mcxTxtEmptyString
(  mcxTxt*           txt
)  ;


void mcxTxtRelease
(  void              *txt
)  ;


void mcxTxtFree
(  void              *txtpp
)  ;

int mcxTxtCmp
(  const void* t1
,  const void* t2
)  ;

u32 mcxTxtHash
(  const void* txt
)  ;


mcxTxt* mcxTxtAppend
(  mcxTxt*           txt
,  const char*       string
)  ;


mcxTxt* mcxTxtSplice
(  mcxTxt*           txt
,  const char**      pstr
,  int               d_offset
,  int               n_delete
,  int               s_offset
,  int               n_copy
)  ;


                    /*     does NOT accept NULL argument.
                     *     Txt is overwritten
                     */
mcxTxt* mcxTxtNWrite
(  mcxTxt*           txt
,  const char*       string
,  int               n
)  ;

                    /*     does NOT accept NULL argument.
                     *     Txt is overwritten
                     */
mcxTxt* mcxTxtWrite
(  mcxTxt*           txt
,  const char*       string
)  ;

                    /*
                     *     Wraps around txtSplice
                     */
mcxTxt* mcxTxtInsert
(  mcxTxt* txt
,  const char*       string
,  int               offset
)  ;


                    /*
                     *     Wraps around txtSplice
                     */ 
mcxTxt* mcxTxtDelete
(  mcxTxt*           txt
,  int               offset
,  int               width
)  ;


                    /*     Wrapper:
                     *     NULL str member is interpreted as empty string.
                     */ 
const char* mcxTxtGetStr
(  mcxTxt*           txt
)  ;


mcxTxt*  mcxTxtInteger
(  mcxTxt*  dst
,  int      x
)  ;


char*    mcxTxtChrcpy
(  mcxTxt*  txt
)  ;


EXTERN__INLINE__ mcxTxt* mcxTxtEmptyString
(  mcxTxt*           txt
)  {
      txt           =   mcxTxtEnsure(txt, 1)
   ;  *(txt->str+0) =  '\0'
   ,  txt->len      =  0
   ;  return txt
;  }


EXTERN__INLINE__ mcxTxt* mcxTxtNWrite
(  mcxTxt*           txt
,  const char*       string
,  int               n
)  {  
      if (txt==NULL)
      mcxTxtAlert("mcxTxtNWrite"), exit(1)
   ;  else
      {  mcxTxtEnsure(txt, n)
      ;  strncpy(txt->str, string, n)
      ;  txt->len = n
   ;  }
   ;  return txt
;  }


EXTERN__INLINE__ mcxTxt* mcxTxtWrite
(  mcxTxt*           txt
,  const char*       string
)  {  
      if (txt==NULL)
      mcxTxtAlert("mcxTxtWrite"), exit(1)
   ;  else
      return mcxTxtInstantiate(txt, string)
;  }


EXTERN__INLINE__ const char* mcxTxtGetStr
(  mcxTxt*           txt
)  {  
      if (txt==NULL)
      mcxTxtAlert("mcxTxtGetStr"), exit(1)

   ;  return txt->len ? txt->str : "\0"
;  }


EXTERN__INLINE__ mcxTxt* mcxTxtNew
(  const char* string
)  {  return mcxTxtInstantiate(NULL, string)
;  }




#ifdef  SPLICE_WRAPPING


EXTERN__INLINE__ mcxTxt* mcxTxtAppend
(  mcxTxt*              txt
,  const char*          string
)  {  
      return mcxTxtSplice
      (  txt
      ,  &string
      , -1                             /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  0                             /*    string offset     */
      ,  string ? strlen(string) : 0   /*    string length     */
      )
;  }


EXTERN__INLINE__ mcxTxt* mcxTxtInsert
(  mcxTxt*              txt
,  const char*          string
,  int                  offset
)  {  
      return mcxTxtSplice
      (  txt
      ,  &string
      ,  offset                        /*    splice offset     */
      ,  0                             /*    delete nothing    */
      ,  0                             /*    string offset     */
      ,  string ? strlen(string) : 0   /*    string length     */
      )
;  }


EXTERN__INLINE__ mcxTxt* mcxTxtDelete
(  mcxTxt*           txt
,  int               offset
,  int               width
)  {
      const char*    string   =  NULL

   ;  return mcxTxtSplice
      (  txt
      ,  &string
      ,  offset                        /*    splice offset     */
      ,  width                         /*    delete width      */
      ,  0                             /*    string offset     */
      ,  0                             /*    string length     */
      )
;  }


#endif


#ifndef SPLICE_WRAPPING

EXTERN__INLINE__ mcxTxt* mcxTxtAppend
(  mcxTxt*              txt
,  const char*       string
)  {  return mcxTxtInsert(txt, string, -1)
;  }

#endif



#endif

