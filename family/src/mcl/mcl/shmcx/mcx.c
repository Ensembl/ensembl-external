/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>

#include "stack.h"
#include "glob.h"
#include "ops.h"
#include "util.h"

#include "util/file.h"
#include "util/txt.h"


int main
(  int               argc
,  const char*       argv[]
)
   {  
      int  a               =  0
   ;  mcxTing* argtxt      =  mcxTingEmpty(NULL, 10)

   ;  mclVerbosityIoNonema =  0;

   ;  opInitialize()       /* symtable etc */
   ;  globInitialize()     /* hdltable etc */

   ;  if (argc == 1)
      {
         mcxTing* ops      =  mcxTingEmpty(NULL, 20)
      ;  mcxIOstream *xfin =  mcxIOstreamNew("stdin", "r")
      ;  mcxIOstreamOpen(xfin, EXIT_ON_FAIL)

      ;  fprintf
         (  stdout
         ,  "At your service: "
            "'[/<op>] help', '[/<str>] grep', 'ops', 'info', and 'quit'.\n"
         )

      ;  while (1)
         {
            int ok
         ;  mcxTing* line  =  NULL

         ;  fprintf(stdout, "> ")
         ;  fflush(stdout)

         ;  line = mcxIOstreamReadLine(xfin, NULL, MCX_READLINE_DEFAULT)
         ;  mcxTingAppend(ops, line->str)

         ;  if (ops->len > 1 && *(ops->str+ops->len-2) == '\\')
            {  mcxTingFree(&line)
            ;  *(ops->str+ops->len-2) = ' '
            ;  continue
         ;  }

         ;  ok = zsDoSequence(ops->str)

         ;  if (ok && (v_g & V_STACK))
            zsList(0)

         ;  mcxTingEmpty(ops, 20)
      ;  }
   ;  }
      else
      {
         for (a=1;a<argc;a++)
         {
            mcxTingWrite(argtxt, argv[a])
         ;  if (!zgUser(argtxt->str))
            exit(1)
      ;  }
   ;  }

   ;  return 0
;  }


