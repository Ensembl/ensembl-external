
/*
//
*/

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/ivp.h"
#include "nonema/io.h"
#include "mcl/interpret.h"
#include "util/txt.h"
#include "util/buf.h"

int main
(  int                  argc
,  const char*          argv[]
)  {  
      mcxIOstream       *xfCl       =  NULL
   ;  mcxIOstream       *xfMx       =  NULL

   ;  mcxMatrix         *cl         =  NULL
   ;  mcxMatrix         *mx         =  NULL
   ;  mcxVector         *idxVec     =  mcxVectorInit(NULL)
   ;  mcxBuf            idxBuf

   ;  int               status      =  0
   ;  int               a           =  1

   ;  mcxBufInit(&idxBuf,  &(idxVec->ivps), sizeof(mcxIvp), 30)

   ;  if (argc==1)
      goto help
   ;  if (argc<5)
      goto die

   ;  while(a < argc)
      {  if (!strcmp(argv[a], "-icl"))
         {  if (a++ + 1 < argc)
            {  xfCl  =  mcxIOstreamNew(argv[a], "r")
            ;  mcxIOstreamOpen(xfCl, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-imx"))
         {  if (a++ + 1 < argc)
            {  xfMx  =  mcxIOstreamNew(argv[a], "r")
            ;  mcxIOstreamOpen(xfMx, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-idx"))
         {  if (a++ + 1 < argc)
            {  int      y     =  atoi(argv[a])
            ;  mcxIvp   *ivp  =  (mcxIvp*) mcxBufExtend(&idxBuf, 1)
            ;  mcxIvpInstantiate(ivp, y, 1.0)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-h"))
         {  goto help
      ;  }
         else if (0)
         {  die:
            status   =  1
         ;  goto help
      ;  }
         else if (0)
         {  help:
fprintf
(  stdout
,  "\n"
   "[clmsubs] usage:\n"
   "clmsubs <options>\n"
   "\n"
   "Options: (* and # denote obligatory resp. unimplemented options)\n"
   "-icl <fname>  *  read clustering in MCL matrix format\n"
   "-imx <fname>  *  graph in MCL matrix format to which clustering pertains\n"
   "-idx <int i>  *  index of cluster inducing submatrix, repeated use"
                           " allowed\n"
   "\n"
   "-single       #  dump ascii representation of all submatrices to file\n"
   "-many         #  write each submatrix to a separate file\n"
   "-stem         #  use stem as root file name\n"
   "-lb           #  cluster size lower bound for submatrix extraction\n"
   "-ub           #  cluster size upper bound for submatrix extraction\n"
   "\n"
)
         ;  exit(status)
      ;  }
         else if (0)
         {  arg_missing:
         ;  fprintf
            (  stderr
            ,  "[clmsubs] Flag %s needs argument; see help (-h)\n"
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }
         else
         {  fprintf
            (  stderr
            ,  "[clmsubs] Unrecognized flag %s; see help (-h)\n"
            ,  argv[a]
            )
         ;  exit(1)
      ;  }
      ;  a++
   ;  }

   ;  if (!xfCl || !xfMx)
      {  fprintf
         (  stderr
         ,  "[clmsubs] -icl and -imx flag are obligatory see help (-h)\n"
         )
      ;  exit(1)
   ;  }

   ;  idxVec->n_ivps =  mcxBufFinalize(&idxBuf)

   ;  mcxVectorSort(idxVec, NULL)

   ;  mx    =  mcxMatrixRead(xfMx, EXIT_ON_FAIL)
   ;  cl    =  mcxMatrixRead(xfCl, EXIT_ON_FAIL)
   ;  mcxIOstreamFree(&xfMx)
   ;  mcxIOstreamFree(&xfCl)

   ;  {  int   clusIdx
      ;  for (clusIdx=0;clusIdx<cl->N_cols;clusIdx++)
         {  
            if (mcxVectorIdxOffset(idxVec, clusIdx) >= 0)
            {  
               mcxMatrix*           sub
            ;  mcxTxt*  fname =     mcxTxtNew("out.clm")
            ;  char                 snum[18]
            ;  mcxIOstream          *xf

            ;  sprintf(snum, "%d", clusIdx)
            ;  mcxTxtAppend(fname, snum)

            ;  xf    =  mcxIOstreamNew(fname->str, "w")
            ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) == STATUS_FAIL)
               {  fprintf
                  (  stderr
                  ,  "[clmsubs] cannot open file [%s] for writing! Ignoring\n"
                  ,  xf->fn->str
                  )
               ;  mcxTxtFree(&fname)
               ;  mcxIOstreamFree(&xf)
               ;  continue
            ;  }

            ;  sub
               =  mcxSubmatrix
                  (  mx
                  ,  cl->vectors+clusIdx
                  ,  cl->vectors+clusIdx
                  )
            ;  mcxMatrixWriteAscii(sub, xf, 8, RETURN_ON_FAIL)
            ;  mcxMatrixFree(&sub)
            ;  mcxTxtFree(&fname)
            ;  mcxIOstreamFree(&xf)
         ;  }

      ;  }
   ;  }

   ;  return 0
;  }

