/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <string.h>

#include "compile.h"
#include "file.h"
#include "types.h"
#include "alloc.h"


void mcxIOstreamErr
(  mcxIOstream*   xf
,  const char     *complainer
,  const char     *complaint
,  const char     *type
)
   {  char  mode  =  xf->mode ? *(xf->mode) : 'x'

   ;  fprintf
      (  stderr
      ,  "[%s%s%s] %s stream [%s] %s\n"
      ,  complainer
      ,  (type && *type) ?  " " : ""
      ,  type
      ,  mode == 'r' ? "input" : mode == 'w' ? "output" : "noput(!)"
      ,  xf->fn->str
      ,  complaint
      )
;  }


mcxIOstream*   mcxIOstreamNew
(  const char*       str
,  const char*       mode
)
   {  mcxIOstream*   xf

   ;  if (!str || !mode)
      {  fprintf
         (  stderr
         ,  "[mcxIOstreamNew PBD] void string or mode argument\n"
         )
      ;  exit(1)
   ;  }

      if (strcmp(mode, "w") && strcmp(mode, "r"))
      {  fprintf
         (  stderr
         ,  "[mcxIOstreamNew PBD] unsupported open mode [%s]\n"
         ,  mode
         )
      ;  exit(1)
   ;  }

   ;  xf = (mcxIOstream*) mcxAlloc(sizeof(mcxIOstream), EXIT_ON_FAIL)

   ;  xf->fn      =  mcxTingNew(str)
   ;  xf->mode    =  mode
   ;  xf->fp      =  NULL
   ;  xf->lc      =  1
   ;  xf->lo      =  1
   ;  xf->bc      =  0
   ;  xf->ateof   =  0
   ;  xf->stdio   =  0
   ;  xf->ufo     =  NULL
   ;  return xf
;  }


mcxstatus  mcxIOstreamOpen
(  mcxIOstream*   xf
,  mcxOnFail      ON_FAIL
)
   {  const char* treat    =  ""
   ;  const char* fname    =  xf->fn->str
   ;  if (!xf)
      {  fprintf
         (  stderr, "[mcxIOstreamOpen PBD] received void object\n");
      ;  exit(1)
   ;  }

   ;  if (xf->fp)
      {  fprintf
         (  stderr, "[mcxIOstreamOpen PBD] file pointer already pointing\n");
      ;  exit(1)
   ;  }

   ;  if (!strcmp(xf->mode, "r"))
      treat   =  "reading"
   ;  else if (!strcmp(xf->mode, "w"))
      treat   =  "writing"

   ;  if
      (  !strcmp(xf->mode, "r")
      && (  !strcmp(fname, "-")
         || !strcmp(fname, "stdin")
         )  
      )
      {  xf->fp      =  stdin
      ;  xf->stdio   =  1
      ;  mcxTingWrite(xf->fn, "stdin")
   ;  }
      else if
      (  !strcmp(xf->mode, "w")
      && (  !strcmp(fname, "-")
         || !strcmp(fname, "stdout")
         )  
      )
      {  xf->fp      =  stdout
      ;  xf->stdio   =  1
      ;  mcxTingWrite(xf->fn, "stdout")
   ;  }
      else if (!strcmp(fname, "stderr"))
      {  xf->fp      =  stderr
      ;  xf->stdio   =  1
   ;  }
      else if ((xf->fp = fopen(fname, xf->mode)) == NULL)
      {  mcxIOstreamErr
         (  xf
         ,  "mcxIOstreamOpen"
         ,  "can not be opened"
         ,  ""
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }
   ;  return STATUS_OK
;  }


void mcxIOstreamRelease
(  mcxIOstream*  xf
)
   {  if (xf)
      {  if (xf->fp)
         fclose(xf->fp)
   ;  }

   ;  if (xf->fn)
      mcxTingFree(&(xf->fn))
;  }


void mcxIOstreamOtherName
(  mcxIOstream*       xf
,  const char*    newname
)
   {  if (!xf)
      {  fprintf
         (  stderr, "[mcxIOstreamOtherName PBD] received void object\n");
      ;  exit(1)
   ;  }
      else if (xf->fp)
      {  fprintf
         (  stderr
         ,  "[mcxIOstreamOtherName warning] stream open,"
            " changing name from [%s] to [%s]\n"
         ,  xf->fn->str
         ,  newname
         )  ;
      }
      else if (!xf->fn)
      {  fprintf
         (  stderr, "[mcxIOstreamOtherName warning] no old file name!\n");
      ;  xf->fn = mcxTingNew(newname)
      ;  exit(1)
   ;  }
      else
      mcxTingWrite(xf->fn, newname)
;  }


void mcxIOstreamClose
(  mcxIOstream*    xf
)
   {  if (xf->fp)
      {  fclose(xf->fp)
      ;  xf->fp   =  NULL
   ;  }
;  }


void mcxIOstreamStep
(  mcxIOstream*    xf
,  short           c
)
   {  switch(c)
      {
      case '\n'
      :     xf->lc++
         ;  xf->bc++
         ;  xf->lo      =  1
         ;  break
         ;
      case EOF
      :     xf->ateof   =  1
         ;  break
         ;
      default
      :     xf->bc++
         ;  xf->lo++
         ;  break
   ;  }
;  }


mcxTing*  mcxIOstreamReadFile
(  mcxIOstream    *xf
,  mcxTing         *filetxt
)
#define MCX_IORF_BSZ 112
   {  char     cbuf[MCX_IORF_BSZ]
   ;  short    c
   ;  int      i        =  0

   ;  if (!xf->fp)
         mcxIOstreamErr(xf, "mcxIOstreamReadFile", "is not open", "PBD")
      ,  exit(1)

   ;  filetxt           =   mcxTingEmpty(filetxt, 1)

   ;  while
      (  c = fgetc(xf->fp)
      ,  c != EOF
      )
      {
         cbuf[i]        =  (char) c

      ;  if (c == '\n')
         xf->lc++

      ;  if (i+1 == MCX_IORF_BSZ)
         {
            mcxTingNAppend(filetxt, cbuf, i+1)
         ;  i = 0
         ;  continue
      ;  }

      ;  i++
   ;  }

   ;  if (i)               /* nothing written at this position */
      mcxTingNAppend(filetxt, cbuf, i)

   ;  xf->ateof   =  1

   ;  return filetxt
#undef MCX_IORF_BSZ
;  }



mcxTing*  mcxIOstreamReadLine
(  mcxIOstream    *xf
,  mcxTing         *lineTxt
,  mcxflags       flags
)
#define MCX_IORL_BSZ 12
   {  char     cbuf[MCX_IORL_BSZ]
   ;  short    c
   ;  int      i        =  0        /* number of characters read */
   ;  int      j        =  0        /* number of buffers read */
   ;  mcxbool  chomp    =  flags & MCX_READLINE_CHOMP
   ;  mcxbool  skip     =  flags & MCX_READLINE_SKIP_EMPTY
   ;  mcxbool  par      =  flags & MCX_READLINE_PAR
  /*  mcxbool  bs       =  flags & MCX_READLINE_BS_CONTINUES
   */

   ;  if (!xf->fp)
         mcxIOstreamErr(xf, "mcxIOstreamReadLine", "is not open", "PBD")
      ,  exit(1)

   ;  if (xf->ateof)
      return NULL

   ;  lineTxt           =   mcxTingEmpty(lineTxt, 1)

   ;  if (par)
      {  while((c = fgetc(xf->fp)) == '\n')
         xf->lc++
      ;  ungetc(c, xf->fp)
   ;  }

   ;  i  =  0

   ;  while
      (  c = fgetc(xf->fp)
      ,  c != EOF
      )
      {  cbuf[i]     =  (char) c

      ;  if (c == '\n')
         {
            xf->lc++

         ;  if (skip && !i && !j)
            continue             /*    i is not incremented, '\n' ignored  */

         ;  else if (par && i && cbuf[i-1] != '\n')
            ;                    /*    i is incremented and '\n' included  */

            else                 /*    finish, this works for par too.     */
            {
               mcxTingNAppend(lineTxt, cbuf, chomp ? i : i+1)
            ;  break
         ;  }
      ;  }
                                 /* cannot write at pos i+1, next iteration  */
         if (i+1 == MCX_IORL_BSZ)
         {
            mcxTingNAppend(lineTxt, cbuf, i+1) /* something written at pos i */
         ;  i           =  0
         ;  j++
      ;  }
         else
         i++
   ;  }

     /*
      *     Because ateof check was void and we assume that that reflects
      *     the true state, eof was pulled in by the code above.
      *
      *     Below: we have not seen a newline as before-EOF character. It may
      *     be true that we have not seen anything at all. In case something
      *     and !chomp, caller gets a newline. in case something and chomp,
      *     proceed  as usual. In case nothing and skip or !skip, caller gets a
      *     NULL (and the newline issue was resolved in a previous call (if
      *     any)).
     */

   ;  if (c == EOF)
      {
         xf->lc--          /* 'beginning of line' does not begin a line */

      ;  if (!i)
         return NULL

      ;  else
         {
            if (!chomp)
            cbuf[i++]      =  '\n'

         ;  mcxTingNAppend(lineTxt, cbuf, i)

         ;  xf->ateof      =  1
      ;  }
   ;  }

   ;  xf->bc = 0

   ;  return lineTxt
#undef MCX_IORL_BSZ
;  }


void mcxIOstreamReport
(  mcxIOstream*    xf
,  FILE*          channel
)
   {  const char* ateof =  xf->ateof ? "at EOF in " : ""
   ;  fprintf
      (  channel
      ,  "___[mclIO] %sstream [%s], line [%d], character [%d]\n"
      ,  ateof
      ,  xf->fn->str
      ,  xf->lc
      ,  xf->lo
      )
;  }


void  mcxIOstreamRewind
(  mcxIOstream*   xf
)
   {  xf->lc   =  1
   ;  xf->lo   =  1
   ;  xf->bc   =  0
;  }


my_inline void mcxIOstreamFree
(  mcxIOstream**  xf
)  
   {  if (*xf)
      {  mcxIOstreamRelease(*xf)
      ;  mcxFree(*xf)
      ;  *xf   =  NULL
   ;  }
;  }


