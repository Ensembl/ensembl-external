
#include "nonema/matrix.h"
#include "nonema/io.h"
#include "nonema/iface.h"
#include "nonema/ivp.h"
#include "intalg/ilist.h"
#include "intalg/la.h"
#include "mcl/clm.h"
#include "util/types.h"
#include <string.h>

int main
(  int                  argc
,  const char*          argv[]
)  {  mcxIOstream       *xfCl1, *xfCl2
   ;  mcxMatrix         *cl, *dl, *cdting, *dcting
   ;  int               i, j, cddist, dcdist

   ;  mcxVerbosityIoNonema  =  0
   ;  if (argc < 3 || !strcmp(argv[1], "-h"))
      {  fprintf
         (  stdout
         ,  "\n"
            "[clmdist] usage:\n"
            "clmdist <cl file> <cl file>\n"
            "  where each <cl file> is a matrix in MCL format"
               " encoding a clustering.\n"
            "  Clusterings output by mcl are compliant ^_^\n"
            "\n"
         )
      ;  exit(0)
   ;  }

   ;  xfCl1       =  mcxIOstreamNew(argv[1], "r")
   ;  xfCl2       =  mcxIOstreamNew(argv[2], "r")

   ;  cl          =  mcxMatrixRead
                     (  xfCl1
                     ,  EXIT_ON_FAIL
                     )
   ;  dl          =  mcxMatrixRead
                     (  xfCl2
                     ,  EXIT_ON_FAIL
                     )
   ;

   {
      int   o1, o2, m1, m2, e1, e2

   ;  mclClusteringEnstrict(cl, &o1, &m1, &e1, 0)
   ;  mclClusteringEnstrict(dl, &o2, &m2, &e2, 0)

   ;  if (o1)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily removed overlap instances (%d) in [%s]"
         " cluster\n"
      ,  o1
      ,  xfCl1->fn->str
      )
   ;  if (o2)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily removed overlap instances (%d) in [%s]"
         " cluster\n"
      ,  o2
      ,  xfCl2->fn->str
      )
   ;  if (m1)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily added missing nodes (%d) in [%s] cluster\n"
      ,  m1
      ,  xfCl1->fn->str
      )
   ;  if (m2)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily added missing nodes (%d) in [%s] cluster\n"
      ,  m2
      ,  xfCl2->fn->str
      )  ;
   ;  if (e1)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily removed empty clusters (%d) in [%s] cluster\n"
      ,  e1
      ,  xfCl1->fn->str
      )  ;
   ;  if (e2)
      fprintf
      (  stderr
      ,  "[clmdist] temporarily removed empty clusters (%d) in [%s] cluster\n"
      ,  e2
      ,  xfCl2->fn->str
      )  ;
   }

   ;  mcxIOstreamFree(&xfCl1)
   ;  mcxIOstreamFree(&xfCl2)

   ;  if (0)
      {  mcxIOstream *xfStdout   =  mcxIOstreamNew("-", "w")
      ;  mcxIOstreamOpen(xfStdout, 0)
      ;  mcxMatrixWriteAscii(cl, xfStdout, -1, EXIT_ON_FAIL)
      ;  mcxMatrixWriteAscii(dl, xfStdout, -1, EXIT_ON_FAIL)
   ;  }

   ;  if (cl->N_rows != dl->N_rows)
      {  fprintf(stderr, "[clmdist] dimensions do not fit\n")
      ;  exit(1)
   ;  }

   ;  cdting   =  mclClusteringContingency(cl, dl)
   ;  dcting   =  mcxMatrixTranspose(cdting)
   ;  cddist   =  0
   ;  dcdist   =  0

   ;  for (i=0;i<cdting->N_cols;i++)
      {  
         int         max            =  0
      ;  mcxVector   *vecmeets      =  cdting->vectors+i

      ;  for (j=0;j<vecmeets->n_ivps;j++)
         {  if ((int) (vecmeets->ivps+j)->val > max)
            {  max = (int) (vecmeets->ivps+j)->val
         ;  }
      ;  }
      ;  cddist += (cl->vectors+i)->n_ivps - max
   ;  }

   ;  for (i=0;i<dcting->N_cols;i++)
      {  
         int         max         =  0
      ;  mcxVector   *vecmeets   =  dcting->vectors+i

      ;  for (j=0;j<vecmeets->n_ivps;j++)
         {  if ((int) (vecmeets->ivps+j)->val > max)
            {  max = (int) (vecmeets->ivps+j)->val
         ;  }
      ;  }
      ;  dcdist += (dl->vectors+i)->n_ivps - max
   ;  }

   ;  fprintf(stdout, "[%d, %d]\n", cddist, dcdist)

   ;  mcxMatrixFree(&cl)
   ;  mcxMatrixFree(&dl)
   ;  mcxMatrixFree(&cdting)
   ;  mcxMatrixFree(&dcting)

   ;  return 0
;  }

