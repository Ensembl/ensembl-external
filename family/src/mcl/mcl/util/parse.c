/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <ctype.h>

#include "parse.h"
#include "types.h"


/* bug: newlines in str thrash correct character counting */

mcxstatus mcxFpParse
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)
   {  const char*       s        =  str
   ;  short             c        =  0
   ;  short             d        =  0
   ;  long              bct      =  0
   ;  FILE*             fp       =  xf->fp
   ;  long              pos      =  ftell(fp)
   ;  int               bReset   =  0

   ;  while
      (  c = s[0]
      ,  
         (  c
         && (  d = fgetc(fp)
            ,  bct++
            ,  c == d
            )  
         )  
      )
      {  s++
   ;  }

   ;  if (c)
      {  if (ON_FAIL == EXIT_ON_FAIL)
         {  fprintf
            (  stderr
            ,  "[%s] Parse error: expected to see `%s'\n"
            ,  caller
            ,  str
            )
         ;  mcxIOstreamReport(xf, stderr)
         ;  exit(1)
      ;  }
         else
         {  if (bReset)
            {  fseek(fp, SEEK_SET,  pos)
         ;  }
            else
            {  ungetc(d, fp)     /* put back first nonmatching character */
            ;  xf->bc += bct-1   /* note that bct >= 1 since c != '\0'    */
            ;  xf->lo += bct-1
         ;  }
      ;  }
      ;  return STATUS_FAIL
   ;  }
      else
      {  xf->bc += bct
      ;  xf->lo += bct
      ;  return STATUS_OK
   ;  }
;  }


float mcxFpParseNumber
(  mcxIOstream*             xf
,  const char*          caller
)
   {  float             num
   ;  int               n_read   =  0

   ;  if (1 != fscanf(xf->fp, " %f%n", &num, &n_read))
      {  fprintf
         (  stderr
         ,  "[%s] Parse error: expected a number\n"
         ,  caller
         )
      ;  mcxIOstreamReport(xf, stderr)
      ;  exit(1)
   ;  }
   ;  xf->bc += n_read
   ;  xf->lo += n_read
   ;  return num
;  }


int mcxFpSkipSpace
(  mcxIOstream*         xf
,  const char*          caller
)
   {  short             c
   ;  long              lct    =    0
   ;  long              bct    =    0
   ;  long              lo     =    xf->lo

   ;  while ((c = fgetc(xf->fp)) != EOF)
      {  if (c=='\n')
         {  lct++
         ;  bct++
         ;  lo   =  1
      ;  }
         else if (isspace(c))
         {  bct++
         ;  lo++
      ;  }
         else
         {  break
      ;  }
   ;  }

   ;  xf->lc +=  lct
   ;  xf->bc +=  bct
   ;  xf->lo  =  lo

   ;  if (c == EOF)
      {  xf->ateof   =  1
      ;  return EOF
   ;  }
      else
      {  ungetc(c, xf->fp)
      ;  return c
   ;  }
;  }


mcxstatus mcxFpFindInFile
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)
   {  short             c

   ;  for (;;)
      {  
         c  =  fgetc(xf->fp)
      ;  mcxIOstreamStep(xf, c)

      ;  if (c == EOF)
         {  
            fprintf
            (  stderr
            ,  "[%s] In file [%s] at EOF, expected `%s' not found\n"
            ,  caller
            ,  xf->fn->str
            ,  str
            )
         ;  mcxIOstreamReport(xf, stderr)

         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }

      ;  if
         (  c == str[0] 
         && (  mcxFpParse
               (  xf
               ,  str + 1
               ,  caller
               ,  1
               )
            == STATUS_OK
            )
         )
         {  return STATUS_OK
      ;  }
   ;  }
   ;  return STATUS_FAIL
;  }


