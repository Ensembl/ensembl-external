/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#include "read.h"

#include "util/file.h"
#include "util/hash.h"
#include "util/types.h"


static   mcxHash*    mskTable_g        =  NULL;    /* masked input files*/

mcxTing*  yamReadFile
(
   mcxIOstream    *xf
,  mcxTing        *filetxt
,  int            masking
)
   {
#define BUFLEN 1024
      char     cbuf[BUFLEN]
   ;  short    c
   ;  int      i           =  0
   ;  int      esc         =  0

   ;  if (!filetxt)
      filetxt =  mcxTingEmpty(NULL, 500)

   ;  if (!xf->fp)
         mcxIOstreamErr(xf, "yamReadFile", "is not open", "PBD")
      ,  exit(1)

   ;  if (!mskTable_g)         
      mskTable_g           =  mcxHashNew(5, mcxTingHash, mcxTingCmp)

   ;  while
      (  c = fgetc(xf->fp)
      ,  c != EOF
      )
      {
         if (esc)
         {
            esc = 0

         ;  if (c == ':')
            {  
               i--            /* remove backslash just written */
            ;  while (c = fgetc(xf->fp), c != '\n' && c != EOF)
                              ;  /* NOTHING */
            ;  if (c == EOF)  break
                              /* else write the newline below  */
         ;  }

            else if (c == '=' && !masking)
            {
               mcxKV    *kv
            ;  mcxTing  *masked
            ;  mcxTing  *mname   =  mcxIOstreamReadLine
                                    (xf, NULL, MCX_READLINE_CHOMP)
            ;  char     *o    =  strchr(mname->str, '=')

            ;  if (!o)
               {  fprintf(stderr,"___ format err in \\=fname= specification\n")
               ;  exit(1)
            ;  }
               else
               {  
                  *o = '\0'
               ;  mname->len  =  o - mname->str
            ;  }

            ;  kv = mcxHashSearch(mname, mskTable_g, MCX_DATUM_INSERT)
            ;  if (kv->key != mname)
               {  fprintf(stderr, "___ file <%s> already masked\n", mname->str)
               ;  exit(1)
            ;  }
            ;  fprintf(stderr, "=== reading inline file <%s>\n", mname->str)
            ;  masked   =  yamReadFile(xf, NULL, 1)
            ;  kv->val  =  masked
            ;  i--            /* remove the backslash */
            ;  continue       /* do not write the '=' */
         ;  }

            else if (c == '=' && masking)
            {
               mcxTing*  line    =     mcxIOstreamReadLine
                                       (xf, NULL, MCX_READLINE_CHOMP)
            ;  fprintf(stderr, "=== done reading inline file\n")
            ;  i--            /* get rid of backslash          */

            ;  if (line->str[0] != '=')
               {  fprintf
                  (  stderr
                  ,  "___ expecting closing '\\==' at line %d\n"
                  ,  xf->lc
                  )
               ;  exit(1)
            ;  }

               if (i)
               {  cbuf[i]  =  '\0'
               ;  mcxTingAppend(filetxt, cbuf)
            ;  }
            ;  return filetxt
         ;  }

         /* else if c == x    write it below                   */
      ;  }

         else if (c == '\\')
         {  esc = 1           /* write the backslash below     */
      ;  }

         cbuf[i] =  (char) c

      ;  if (c == '\n')
         xf->lc++

      ;  if (i == BUFLEN-2)
         {
            if (esc)
            {  ungetc(c, xf->fp)
            ;  esc = 0
            ;  i--
         ;  }
            cbuf[i+1] =  '\0'
         ;  mcxTingNAppend(filetxt, cbuf, i+1)
         ;  i =  0
      ;  }
         else
         {  i++
      ;  }
   ;  }

   ;  if (masking)
      {  fprintf(stderr, "___ masking scope not closed!\n")
      ;  exit(1)
   ;  }

   ;  if (i)
      {  cbuf[i]  =  '\0'
      ;  mcxTingAppend(filetxt, cbuf)
   ;  }

   ;  xf->ateof   =  1

   ;  return filetxt
;  }


mcxbool yamInlineFile
(  mcxTing* fname
,  mcxTing* filetxt
)
   {  mcxKV* kv = mcxHashSearch(fname, mskTable_g, MCX_DATUM_FIND)
   ;  if (kv)
      {  mcxTingWrite(filetxt, ((mcxTing*)kv->val)->str)
      ;  fprintf(stderr, "=== using inline file <%s>\n", fname->str)
      ;  return TRUE
   ;  }
   ;  return FALSE
;  }


