/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>
#include <stdio.h>

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/io.h"
#include "nonema/compose.h"
#include "nonema/iface.h"
#include "util/file.h"
#include "util/types.h"
#include "mcl/clm.h"


int main
(  int                  argc
,  const char*          argv[]
)
   {  mcxIOstream    **xfMcs        =  NULL
   ;  mcxIOstream    *xfOut         =  NULL
   ;  const char     *dieMsg        =  NULL

   ;  mclMatrix      *lft           =  NULL
   ;  mclMatrix      *rgt           =  NULL
   ;  mclMatrix      *dst           =  NULL

   ;  const char     *whoiam        =  "clmmeet"

   ;  int            o, m, e
   ;  int            a              =  1
   ;  int            n_mx           =  0
   ;  int            j
   ;  int            N_cols         =  -1
   ;  int            N_rows         =  -1
   ;  int            status         =  0

   ;  mclVerbosityIoNonema          =  1

   ;  if ((argc==1) || (argc >= 2 && !strcmp(argv[1], "-h")))
      {  goto help
   ;  }

   ;  if (argc < 3)
      {  dieMsg = "specify clustering and meet file names"
      ;  goto die
   ;  }

   ;  xfMcs    =  (mcxIOstream**) mcxAlloc
                  (  (argc)*sizeof(mcxIOstream*)
                  ,  EXIT_ON_FAIL
                  )
   ;  while(a<argc)
      {  
         if (!strcmp(argv[a], "-h"))
         {  help
         :  fprintf(stdout,
"Usage:\n"
"clmmeet -o <meet file> <cl file> <cl file>*\n"
"<meet file>  File where the meet is written (in MCL matrix format).\n"
"             The meet is the largest clustering that is a\n"
"             subclustering of all clusterings specified.\n"
"<cl file>    File containing clustering (in MCL matrix format).\n"
"             At least one such file is required.\n"
"             Two or more clusterings make it interesting.\n"
)
         ;  exit(0)
      ;  }
         else if (0)
         {  die:
            fprintf(stderr, "%s\n", dieMsg)
         ;  exit(1)
      ;  }
         else if (!strcmp(argv[a], "-o"))
         {  
            if (a+1 == argc)
            goto arg_missing

         ;  xfOut = mcxIOstreamNew(argv[++a], "w")
         ;  mcxIOstreamOpen(xfOut, EXIT_ON_FAIL)
      ;  }
         else if (0)
         {  arg_missing:
            fprintf
            (  stderr
            ,  "[clmmeet] flag [%s] needs argument (see -h for usage)\n"
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }
         else
         {  xfMcs[n_mx] = mcxIOstreamNew(argv[a], "r")
         ;  mcxIOstreamOpen(xfMcs[n_mx], EXIT_ON_FAIL)
         ;  n_mx++
      ;  }
      ;  a++
   ;  }

   ;  if (!xfOut)
      {  dieMsg = "-o <fname> option is mandatory (use -h for usage)"
      ;  goto die
   ;  }

   ;  if (!n_mx)
      {  dieMsg = "at least one clustering matrix required (use -h for usage)"
      ;  goto die
   ;  }

   ;  for (j=0;j<n_mx;j++)
      {
         int new_N_rows, new_N_cols
      ;  if
         (  mclMatrixFilePeek
            (  xfMcs[j]
            ,  &new_N_cols
            ,  &new_N_rows
            ,  RETURN_ON_FAIL
            )
            == STATUS_FAIL
         )
         {  fprintf
            (  stderr
            ,  "[%s] matrix format not known for matrix %d\n"
            ,  whoiam, j
            )  ;
         ;  exit(1)
      ;  }

      ;  if (j && N_rows != new_N_rows)
         {  fprintf
            (  stderr
            ,  "[%s] different ranges [%d] versus [%d] for clusterings in"
               " input files %d, %d\n"
            ,  whoiam
            ,  N_rows      ,  new_N_rows
            ,  j-1         ,  j
            )  ;
         ;  exit(1)
      ;  }
         else
         {  N_cols      =  new_N_cols
         ;  N_rows      =  new_N_rows
      ;  }
   ;  }

   ;  lft               =  mclMatrixRead(xfMcs[0], EXIT_ON_FAIL)

   ;  if (mclClusteringEnstrict(lft, &o, &m, &e, ENSTRICT_REPORT_ONLY))
      {  fprintf
         (  stderr
         ,  "[clmmeet] Clustering in file [%s] is not a partition\n"
         ,  xfMcs[0]->fn->str
         )
      ;  exit(1)
   ;  }

   ;  mcxIOstreamRelease(xfMcs[0])

   ;  for (j=1;j<n_mx;j++)
      {  
         rgt =  mclMatrixRead (xfMcs[j], EXIT_ON_FAIL)

      ;  if (mclClusteringEnstrict(lft, &o, &m, &e, ENSTRICT_REPORT_ONLY))
         {  fprintf
            (  stderr
            ,  "[clmmeet] Clustering in file [%s] is not a partition\n"
            ,  xfMcs[j]->fn->str
            )
         ;  exit(1)
      ;  }

      ;  mcxIOstreamRelease(xfMcs[j])

      ;  dst   =  mclClusteringMeet(lft, rgt, EXIT_ON_FAIL)
      ;  lft   =  dst
      ;  mclMatrixFree(&rgt)
   ;  }

   ;  mclMatrixWriteAscii(lft, xfOut, -1, EXIT_ON_FAIL)

   ;  mclMatrixFree(&lft)
   ;  mcxIOstreamFree(&xfOut)
   ;  free(xfMcs)

   ;  return(0)
;  }

