/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "filter.h"
#include "util.h"
#include "entry.h"
#include "key.h"
#include "file.h"

#include "util/hash.h"
#include "util/txt.h"
#include "util/types.h"
#include "util/file.h"


typedef struct
{
   mcxTing*          fname
;  const mcxTing*    txt
;  int               linect
;
}  inputHook          ;


#define MAX_FILES_NEST 10

inputHook inputHookDir[MAX_FILES_NEST]
=   
{  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
,  {  NULL, NULL, 1 }
}  ;

#define hd inputHookDir

static mcxHash*   wrtTable_g     =  NULL;    /* open output files */
static int        hdidx_g        =  -1;
static mcxTing*   fntxt_g        =  NULL;


void yamFileInitialize
(  int   n
)
   {  wrtTable_g  =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
;  }


mcxstatus yamInputPop
(  void
)
   {
      hdidx_g--

   ;  if (hdidx_g >= 0)
      yamKeyInsert(fntxt_g, hd[hdidx_g].fname->str)

   ;  return STATUS_OK
;  }


mcxstatus yamInputPush
(  const char*       str
,  const mcxTing*    txt
)
   {
      hdidx_g++

   ;  if (hdidx_g >= MAX_FILES_NEST)
      return STATUS_FAIL

   ;  hd[hdidx_g].linect   =  1
   ;  hd[hdidx_g].txt      =  txt

   ;  if (hd[hdidx_g].fname)
      mcxTingWrite(hd[hdidx_g].fname, str)
   ;  else
      hd[hdidx_g].fname    =   mcxTingNew(str)

   ;  fntxt_g = mcxTingNew("$file")
   ;  yamKeyInsert(fntxt_g, str)

   ;  return STATUS_OK
;  }


mcxbool yamInputCanPush
(  void
)  {  return hdidx_g+1 < MAX_FILES_NEST ? TRUE : FALSE
;  }

int yamInputGetLc
(  void
)
   {  return hd[hdidx_g].linect
;  }


const char* yamInputGetName
(  void
)
   {  return hd[hdidx_g].fname->str
;  }


void yamInputIncrLc
(  const mcxTing* txt
,  int d
)
   {  if (hd[hdidx_g].txt == txt)
      hd[hdidx_g].linect += d
;  }


void yamOutputAlias
(  const char*    str
,  mcxIOstream*   xfout
)
   {  mcxTing* key         =  mcxTingNew(str)
   ;  mcxKV* kv            =  mcxHashSearch(key, wrtTable_g, MCX_DATUM_INSERT)
   ;  kv->val              =  xfout
;  }


mcxIOstream* yamOutputNew
(  const char*  s
)
   {
      mcxIOstream *xf      =  NULL
   ;  mcxTing *fname       =  mcxTingNew(s)
   ;  mcxKV *kv

   ;  if (fname->len > 123)
      yamExit
      (  "yamOutputNew"
      ,  "output file name expansion too long (>123)\n"
      )

   ;  kv = mcxHashSearch(fname, wrtTable_g, MCX_DATUM_FIND)

   ;  if (!kv)
      {  xf = mcxIOstreamNew(fname->str, "w")
      ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) != STATUS_OK)
         {  mcxIOstreamFree(&xf)
         ;  yamExit
            (  "yamOutputNew"
            ,  "can not open file <%s> for writing\n"
            ,  fname->str
            )
      ;  }
         xf->ufo = yamFilterDataNew(xf->fp)
      ;  kv      = mcxHashSearch(fname, wrtTable_g, MCX_DATUM_INSERT)
      ;  kv->val = xf
   ;  }
      else
      {  xf = (mcxIOstream*) kv->val
      ;  mcxTingFree(&fname)
   ;  }

   ;  return xf
;  }

