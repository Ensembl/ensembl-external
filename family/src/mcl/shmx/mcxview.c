
#include "nonema/matrix.h"
#include "nonema/io.h"
#include "util/file.h"
#include "util/types.h"

int main
(  int                  argc
,  const char*          argv[]
)  {  mcxIOstream*          xfIn
   ;  mcxMatrix*        mx

   ;  if (argc < 2 || !strcmp(argv[1], "-h"))
      {  fprintf
         (  stderr
         ,  "[mcxview] Usage: mclview <mx file>\n"
         )
      ;  exit(0)
   ;  }

   ;  xfIn  =  mcxIOstreamNew(argv[1], "r")

   ;  if (mcxIOstreamOpen(xfIn, RETURN_ON_FAIL))
      {  fprintf
         (  stderr
         ,  "[mcxview] cannot open stream [%s] for reading\n"
            "[mcxview] Usage: mclview <mx file>\n"
         ,  xfIn->fn->str
         )
      ;  mcxIOstreamFree(&xfIn)
      ;  exit(1)
   ;  }

   ;  mx    =  mcxMatrixRead(xfIn, 0)
   ;  mcxIOstreamFree(&xfIn)

   ;  mcxMatrixList(mx, stdout, 0, 0, 0, 0, 0, 3, "")
   ;  mcxMatrixFree(&mx)
   ;  return 0
;  }

