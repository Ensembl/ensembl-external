/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "nonema/matrix.h"
#include "nonema/io.h"
#include "nonema/iface.h"
#include "util/file.h"
#include "util/types.h"

int main
(  int                  argc
,  const char*          argv[]
)
   {  mcxIOstream       *xfIn
   ;  mcxIOstream       *xfOut
   ;  mclMatrix*        mx

   ;  if (argc < 3 || !strcmp(argv[1], "-h"))
      {  fprintf
         (  stderr
         ,  "[mcxconvert] Usage: mcxconvert <fname in> <fname out>\n"
         )
      ;  exit(1)
   ;  }

   ;  xfIn     =  mcxIOstreamNew(argv[1], "r")
   ;  mx       =  mclMatrixRead(xfIn, 0)

   ;  xfOut    =  mcxIOstreamNew(argv[2], "w")
   ;  mcxIOstreamOpen(xfOut, EXIT_ON_FAIL)

   ;  if (mclMatrixFormatFound == 'a')
      mclMatrixWrite(mx, xfOut, EXIT_ON_FAIL)
   ;  else
      mclMatrixWriteAscii(mx, xfOut, 8, EXIT_ON_FAIL)

   ;  mclMatrixFree(&mx)
   ;  mcxIOstreamFree(&xfIn)
   ;  mcxIOstreamFree(&xfOut)
   ;  return 0
;  }

