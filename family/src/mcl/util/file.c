
#include "util/file.h"
#include "util/types.h"
#include "util/alloc.h"
#include <stdlib.h>
#include <string.h>


void mcxIOstreamErr
(
   mcxIOstream*   xf
,  const char     *complainer
,  const char     *complaint
,  const char     *type
)
   {
      char  mode  =  xf->mode ? *(xf->mode) : 'x'

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
(
   const char*       str
,  const char*       mode
)
   {  
      mcxIOstream*   xf

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

   ;  xf = (mcxIOstream*) rqAlloc(sizeof(mcxIOstream), EXIT_ON_FAIL)

   ;  xf->fn      =  mcxTxtNew(str)
   ;  xf->mode    =  mode
   ;  xf->fp      =  NULL
   ;  xf->lc      =  1
   ;  xf->lo      =  1
   ;  xf->bc      =  0
   ;  xf->ateof   =  0
   ;  xf->sys     =  0
   ;  return xf
;  }


mcxstatus  mcxIOstreamOpen
(
   mcxIOstream*   xf
,  mcxOnFail      ON_FAIL
)
   {
      const char* treat  =  ""

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
      && !strcmp(xf->fn->str, "-")
      )
      {  xf->fp   =  stdin
      ;  xf->sys  =  1
      ;  mcxTxtWrite(xf->fn, "stdin")
   ;  }
      else if
      (  !strcmp(xf->mode, "w")
      && !strcmp(xf->fn->str, "-")
      )
      {  xf->fp   =  stdout
      ;  xf->sys  =  1
      ;  mcxTxtWrite(xf->fn, "stdout")
   ;  }
      else if (!strcmp(xf->fn->str, "stderr"))
      {  xf->fp   =  stderr
      ;  xf->sys  =  1
   ;  }
      else if ((xf->fp = fopen(xf->fn->str, xf->mode)) == NULL)
      {  mcxIOstreamErr
         (  xf
         ,  "mcxIOstreamOpen"
         ,  "can not be opened"
         ,  "SYS"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }
   ;  return STATUS_OK
;  }


void     mcxIOstreamRelease
(
   mcxIOstream*  xf
)
   {  
      if (xf)
      {  if (xf->fp)
         fclose(xf->fp)
   ;  }

   ;  if (xf->fn)
      mcxTxtFree(&(xf->fn))
;  }


void mcxIOstreamOtherName
(
   mcxIOstream*       xf
,  const char*    newname
)
   {
      if (!xf)
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
      ;  xf->fn = mcxTxtNew(newname)
      ;  exit(1)
   ;  }
      else
      mcxTxtWrite(xf->fn, newname)
;  }


void mcxIOstreamClose
(
   mcxIOstream*    xf
)
   {
      if (xf->fp)
      {  fclose(xf->fp)
      ;  xf->fp   =  NULL
   ;  }
;  }


void mcxIOstreamStep
(
   mcxIOstream*    xf
,  short           c
)  {  switch(c)
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


mcxTxt*  mcxIOstreamReadFile
(
   mcxIOstream    *xf
,  mcxTxt         *fileTxt
)  {
      char     cbuf[512]   /* it's where do I stuff the '\n' and the '\0'! */
   ;  short    c
   ;  int      i        =  0

   ;  if (!xf->fp)
         mcxIOstreamErr(xf, "mcxIOstreamReadFile", "is not open", "PBD")
      ,  exit(1)

   ;  fileTxt  =  fileTxt ? mcxTxtEmptyString(fileTxt) : mcxTxtInit(NULL)

   ;  while
      (  c = fgetc(xf->fp)
      ,  c != EOF
      )
      {
         cbuf[i]     =  (char) c

      ;  if (c == '\n')
         xf->lc++

      ;  if (i == 510)
         {
            cbuf[511]   =  '\0'
         ;  i           =  0
         ;  mcxTxtAppend(fileTxt, cbuf)
      ;  }
         else
         {  i++
      ;  }
   ;  }

   ;  if (i)
      {
         cbuf[i]  =  '\0'
      ;  mcxTxtAppend(fileTxt, cbuf)
   ;  }

   ;  xf->ateof   =  1

   ;  return fileTxt
;  }



mcxTxt*  mcxIOstreamReadLine
(
   mcxIOstream    *xf
,  mcxTxt         *lineTxt
,  mcxflags       flags
)
   {
      static char cbuf[82]
   ;  short    c
   ;  int      i        =  0
   ;  int      j        =  0
   ;  mcxbool  chomp    =  flags & READLINE_CHOMP
   ;  mcxbool  skip     =  flags & READLINE_SKIP_EMPTY
   ;  mcxbool  par      =  flags & READLINE_PAR
   ;  mcxbool  bs       =  flags & READLINE_BS_CONTINUES

   ;  if (!xf->fp)
         mcxIOstreamErr(xf, "mcxIOstreamReadLine", "is not open", "PBD")
      ,  exit(1)

   ;  if (xf->ateof)
      return NULL

   ;  lineTxt  =  lineTxt ? mcxTxtEmptyString(lineTxt) : mcxTxtInit(NULL)

   ;  if (par)
      {  
         while((c = fgetc(xf->fp)) == '\n')
         xf->lc++
      ;  ungetc(c, xf->fp)
   ;  }

   ;  while
      (  c = fgetc(xf->fp)
      ,  c != EOF
      )
      {
         cbuf[i]     =  (char) c

      ;  if (c == '\n')
         {
            xf->lc++

         ;  if (skip && !i && !j)
            continue             /*    i is not incremented, '\n' ignored  */

         ;  else if (par && i && cbuf[i-1] != '\n')
            ;                    /*    i is incremented and '\n' included  */

            else                 /*    this works for par too.             */
            {
               if (chomp)
               cbuf[i]     =  '\0'
            ;  else
               cbuf[i+1]   =  '\0'

            ;  mcxTxtAppend(lineTxt, cbuf)
            ;  break
         ;  }
      ;  }

         if (i == 80)
         {
            cbuf[i+1]   =  '\0'
         ;  i           =  0
         ;  mcxTxtAppend(lineTxt, cbuf)
         ;  j++
      ;  }
         else
         i++
   ;  }

     /*
      *     Because ateof check was void and we assume that that reflects
      *     the true state, eof was pulled in in the code above.
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

         ;  cbuf[i]        =  '\0'
         ;  xf->ateof      =  1
         ;  mcxTxtAppend(lineTxt, cbuf)
      ;  }
   ;  }

   ;  xf->bc = 0

   ;  return lineTxt
;  }


void mcxIOstreamReport
(  mcxIOstream*    xf
,  FILE*          channel
)  {  
      const char* ateof =  xf->ateof ? "at EOF in " : ""
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
)  {  xf->lc   =  1
   ;  xf->lo   =  1
   ;  xf->bc   =  0
;  }

