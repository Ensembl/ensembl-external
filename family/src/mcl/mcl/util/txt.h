/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_ting__
#define util_ting__

#include <string.h>
#include "util/alloc.h"
#include "util/types.h"
#include "util/hash.h"


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
 *    mcxTingEnsure is the only routine allowed to fiddle with mxl.
 *    (apart from mcxTingInit which sets it to zero).
 *    Future option could be something like mcxTingFinalize,
 *    releasing unused memory.
 * 
 *    Routines marked `+' and `#' will accept ting==NULL argument.
 *    Routines marked `#' should not be called other than by ting routines
 * 
 *                  #tingInit
 *                  /       \
 *          #tingEnsure <- #tingInstantiate
 *          :      \               :                   
 *  +Empty        tingSplice   +tingNew,Write
 *   NWrite           :               
 *                    :
 *           tingAppend,Insert,Delete
*/

typedef struct {
   char  *str;
   int   len;
   int   mxl;
}      
   mcxTing;


/* ================================================================== */


void mcxTingAlert        
(  const char*          caller
)  ;

                    /*
                     *     Accepts NULL argument.
                     *     void arguments so that it can be passed.
                     */
void* mcxTingInit
(  void*             ting
)  ;  

                    /*
                     *     Accepts NULL argument.
                     */
mcxTing* mcxTingInstantiate
(  mcxTing*           dst_ting
,  const char*       str
)  ;  

                    /*
                     *     Accepts NULL argument.
                     */
mcxTing* mcxTingEnsure
(  mcxTing*           ting
,  int               length
)  ;  


                    /*     Accepts NULL argument.
                    */
mcxTing* mcxTingEmpty
(  mcxTing*           ting
,  int               len
)  ;


/* ================================================================== */


                    /*     accepts NULL argument, maps to empty string.
                    */
mcxTing* mcxTingNew
(  const char*       str
)  ;

                    /*     accepts NULL argument, maps to empty string.
                    */
mcxTing* mcxTingNNew
(  const char*       str
,  int               n
)  ;


void mcxTingFree
(  mcxTing           **tingpp
)  ;


void mcxTingFree_v
(  void              *tingpp
)  ;


void mcxTingRelease
(  void              *ting
)  ;



                    /*     does NOT accept NULL argument.
                    */
void mcxTingSplice
(  mcxTing*           ting
,  const char*       pstr
,  int               d_offset
,  int               n_delete
,  int               n_copy
)  ;


                    /*     does NOT accept NULL argument.
                    */
void mcxTingWrite
(  mcxTing*           ting
,  const char*       str
)  ;


                    /*     does NOT accept NULL argument.
                    */
void mcxTingNWrite
(  mcxTing*          ting
,  const char*       str
,  int               n
)  ;

                    /*     does NOT accept NULL argument.
                    */
void mcxTingInsert
(  mcxTing* ting
,  const char*       str
,  int               offset
)  ;

                    /*     does NOT accept NULL argument.
                    */
void mcxTingNInsert
(  mcxTing* ting
,  const char*       str
,  int               offset   /* of ting->str */
,  int               length   /* of str */
)  ;

                    /*     does NOT accept NULL argument.
                    */
void mcxTingAppend
(  mcxTing*     ting
,  const char* str
)  ;

                    /*     does NOT accept NULL argument.
                    */
void mcxTingNAppend
(  mcxTing*     ting
,  const char* str
,  int         n
)  ;

                    /*     does NOT accept NULL argument.
                    */
void mcxTingDelete
(  mcxTing*          ting
,  int               offset
,  int               width
)  ;


void mcxTingShrink
(  mcxTing*  ting
,  int      length
)  ;


char*    mcxTingStr
(  mcxTing*  ting
)  ;

                    /*     does accept NULL argument.
                    */
mcxTing*  mcxTingInteger
(  mcxTing*  dst
,  int      x
)  ;


int mcxTingCmp
(  const void* t1
,  const void* t2
)  ;


u32 mcxTingELFhash
(  const void* ting
)  ;

u32 mcxTingHash
(  const void* ting
)  ;

u32 mcxTingBJhash
(  const void* ting
)  ;

u32 mcxTingCThash
(  const void* ting
)  ;

u32 mcxTingDPhash
(  const void* ting
)  ;

u32 mcxTingBDBhash
(  const void* ting
)  ;

u32 mcxTingSvDhash
(  const void* ting
)  ;

u32 mcxTingSvD2hash
(  const void* ting
)  ;

u32 mcxTingSvD1hash
(  const void* ting
)  ;

u32 mcxTingDJBhash
(  const void* ting
)  ;

#endif


