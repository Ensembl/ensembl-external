
#include <stdio.h>

#include "util/file.h"
#include "util/txt.h"
#include "util/types.h"
#include "doc/key.h"

int main
(  int   argc
,  char* argv[]
)  {

      mcxTxt      *filetxt
   ;  yamTables   tables

   ;  mcxIOstream *xf   =  mcxIOstreamNew(argv[1], "r")
   ;  mcxIOstreamOpen(xf, EXIT_ON_FAIL)
   ;  filetxt           =  mcxIOstreamReadFile(xf, NULL)

   ;  tables.tables[0]  =  mcxHashNew(1, mcxTxtHash, mcxTxtCmp)
   ;  tables.tables[1]  =  mcxHashNew(1, mcxTxtHash, mcxTxtCmp)
   ;  tables.n_tables   =  2


   ;  digest(&tables, filetxt, filter_html)
   ;  fprintf(stdout, "\n")

   ;  return 0
;  }


