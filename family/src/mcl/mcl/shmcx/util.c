/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdarg.h>
#include <stdio.h>

#include "util.h"

#include "util/types.h"


mcxflags  v_g   =  1;
int digits_g    =  2;

void zmTell
(  int   mode
,  const char* fmt
,  ...
)
   {  va_list  args
   ;  const char* band = "   "

   ;  if
      (  (mode == 'd' && !(v_g & V_HDL))
      || (mode == 't' && !(v_g & V_TRACE))
      || (mode == 'o' && !(v_g & V_TRACE))
      )
      return

   ;  switch(mode)
      {  case 'e' :  band = "###";  break  
      ;  case 'd' :  band = "---";  break  
      ;  case 't' :  band = "...";  break  
      ;  case 'o' :  band = "<->";  break  
      ;  case 'v' :  band = " * ";  break
      ;  case 'm' :  band = " @ ";  break
   ;  }

   ;  va_start(args, fmt)
   ;  fprintf(stderr, "%s ", band)
   ;  vfprintf(stderr, fmt, args)
   ;  fprintf(stderr, "\n")
   ;  va_end(args)
;  }


void zmNotSupported1
(  const char* who
,  int utype
)
   {  zmTell('e', "<%s> [%s] not supported", zgGetTypeName(utype), who)
;  }


void zmNotSupported2
(  const char* who
,  int utype1
,  int utype2
)
   {  zmTell
      (  'e'
      ,  "<%s> <%s> [%s] not supported"
      ,  zgGetTypeName(utype1)
      ,  zgGetTypeName(utype2)
      ,  who
      )
;  }

