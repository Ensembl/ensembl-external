/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "curly.h"
#include "util.h"
#include "file.h"

#include "util/txt.h"
#include "util/types.h"

/*
 *    txt->str[offset] must be '{'.
 *    returns l such that txt->str[offset+l] == '}'.
*/

int   closingcurly
(
   mcxTing     *txt
,  int         offset
,  int*        linect
,  mcxOnFail   ON_FAIL
)
   {
      char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  int   n     =  1           /* 1 open bracket */
   ;  int   lc    =  0
   ;  int   esc   =  0
   ;  int   q

   ;  if (*p != '{')
      q = CURLY_NOLEFT

   ;  else
      {  while(++p < z)
         {
            if (*p == '\n')
            lc++

         ;  if (esc)
            {  esc   =  0           /* no checks for validity */
            ;  continue
         ;  }

            switch(*p)
            {  case '\\'
               :  esc = 1; break
            ;  case '{'
               :  n++; break
            ;  case '}'
               :  n--; break
         ;  }

         ;  if (!n)
            break
      ;  }
      ;  q = n ? CURLY_NORIGHT : p-o
   ;  }

   ;  if (linect)
      *linect += lc

   ;  if (q<0 && ON_FAIL == EXIT_ON_FAIL)
      scopeErr(NULL, "closingcurly", q)

   ;  return q
;  }


void  scopeErr
(  yamSeg      *seg
,  const char  *caller
,  int         error
)
   {
      if (error == CURLY_NORIGHT)
      fprintf
      (  stderr
      ,  "\n"
         "[%s] unable to close scope (starting around line %d in file %s)\n"
      ,  caller
      ,  yamInputGetLc()
      ,  yamInputGetName()
      )
   ;  else if (error == CURLY_NOLEFT)
      fprintf
      (  stderr
      ,  "\n"
         "[%s] scope error (around input line %d in file %s)\n"
         "[%s] expected to see an opening '{'.\n"
      ,  caller
      ,  yamInputGetLc()
      ,  yamInputGetName()
      ,  caller
      )
   ;  exit(1)
;  }


