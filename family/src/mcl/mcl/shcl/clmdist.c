/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>
#include <stdio.h>

#include "nonema/matrix.h"
#include "nonema/io.h"
#include "nonema/iface.h"
#include "nonema/ivp.h"
#include "intalg/ilist.h"
#include "intalg/la.h"
#include "mcl/clm.h"
#include "util/types.h"


typedef struct
{  mclMatrix*  cl
;  mcxTing*    name
;
}  clnode      ;


int main
(  int                  argc
,  const char*          argv[]
)
   {  int               i, j, x, cddist, dcdist
   ;  int n_clusterings =  0
   ;  clnode*  cls      =  mcxAlloc(argc * sizeof(clnode), EXIT_ON_FAIL)

   ;  mclVerbosityIoNonema  =  0

   ;  if (argc < 3 || !strcmp(argv[1], "-h"))
      {  fprintf
(stdout,
"Usage:\n"
"clmdist <cl file> <cl file>+\n"
"   where each <cl file> is a matrix in MCL format encoding a clustering.\n"
"   Clusterings output by mcl are compliant.\n"
)
      ;  exit(0)
   ;  }

      if (argc > 3)
      fprintf(stderr, "[clmdist] reading clusterings ...\n")
   ;
      for (i=1;i<argc;i++)
      {  mcxIOstream *xfcl    =  mcxIOstreamNew(argv[i], "r")
      ;  mclMatrix*   cl      =  mclMatrixRead(xfcl, EXIT_ON_FAIL)
      ;  cls[n_clusterings].cl = cl
      ;  cls[n_clusterings].name = mcxTingNew(xfcl->fn->str)
      ;  n_clusterings++
   ;  }

      if (argc > 3)
      {  fprintf(stdout, "%16s", "")
      ;  for (i=2;i<argc && argc > 3;i++)
         fprintf(stdout, "%-12s", argv[i])
      ;  fprintf(stdout, "\n")
   ;  }

      for (i=0;i<n_clusterings-1;i++)
      {
         mclMatrix*   cl2     =  cls[i].cl
      ;  mcxTing*     name2   =  cls[i].name

      ;  if (argc > 3)
         {  fprintf(stdout, "%-10s", name2->str)
         ;  for (x=0;x<i;x++)
            fprintf(stdout, "%12s", "")
      ;  }

      ;  for (j=i+1;j<n_clusterings;j++)
         {
            mclMatrix* cl1    =  cls[j].cl
         ;  mcxTing*    name1 =  cls[j].name

         ;  int   o1, o2, m1, m2, e1, e2

         ;  if (cl2->N_rows != cl1->N_rows)
            {  fprintf
               (  stderr
               ,  "[clmdist] range %d of clustering %d [%s] differs from"
                  " range %d of clustering %d [%s]\n"
               ,  cl2->N_rows
               ,  i
               ,  name2->str
               ,  cl1->N_rows
               ,  j
               ,  name1->str
               )
            ;  exit(1)
         ;  }

         ;  mclClusteringEnstrict(cl1, &o1, &m1, &e1, 0)
         ;  mclClusteringEnstrict(cl2, &o2, &m2, &e2, 0)

         ;  if (o2)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily removed overlap instances (%d) in [%s]\n"
            ,  o2
            ,  name2->str
            )
         ;  if (o1)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily removed overlap instances (%d) in[%s]\n"
            ,  o1
            ,  name1->str
            )
         ;  if (m2)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily added missing nodes (%d) in [%s]\n"
            ,  m2
            ,  name2->str
            )
         ;  if (m1)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily added missing nodes (%d) in [%s]\n"
            ,  m1
            ,  name1->str
            )
         ;  if (e2)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily removed empty clusters (%d) in [%s]\n"
            ,  e2
            ,  name2->str
            )
         ;  if (e1)
            fprintf
            (  stderr
            ,  "[clmdist] temporarily removed empty clusters (%d) in [%s]\n"
            ,  e1
            ,  name1->str
            )

         ;  mclClusteringSJD(cl1, cl2, &cddist, &dcdist)
         ;
            {  char tmp[30] 
            ;  sprintf(tmp, "[%d,%d]", dcdist, cddist)
            ;  fprintf(stdout, "%12s", tmp)
         ;  }
      ;  }
         fprintf(stdout, "\n")
   ;  }
;  }

