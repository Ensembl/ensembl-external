/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#include <string.h>
#include <stdio.h>

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/io.h"
#include "nonema/iface.h"
#include "util/file.h"
#include "util/types.h"
#include "intalg/ilist.h"
#include "intalg/la.h"
#include "mcl/interpret.h"


int main
(  int                  argc
,  const char*          argv[]
)
   {  mcxIOstream           *xfMx       =  NULL

   ;  mclMatrix         *cl         =  NULL
   ;  mclMatrix         *mx         =  NULL

   ;  int               a           =  2

   ;  mclVerbosityIoNonema          =  0

   ;  if ((argc < 3) || !strcmp(argv[1], "-h"))
      {  fprintf(stdout,
"Usage:\n"
"clminfo <mx file> <cl file> [<cl file>*]\n"
"   where mx file encodes a graph (in MCL matrix format)\n"
"   and each cl file encodes a clustering of it (in MCL matrix format).\n"
)
      ;  exit(0)
   ;  }

   ;  xfMx     =  mcxIOstreamNew(argv[1], "r")
   ;  mx       =  mclMatrixRead(xfMx, EXIT_ON_FAIL)
   ;  mcxIOstreamFree(&xfMx)

   ;  if (mx->N_cols != mx->N_rows)
      {  fprintf
         (  stderr
         ,  "First argument, %dx%d matrix, does not encode a graph\n"
         ,  mx->N_rows
         ,  mx->N_cols
         )
      ;  exit(1)
   ;  }

   ;  while(a < argc)
      {    
         mcxIOstream *xfCl =  mcxIOstreamNew(argv[a], "r")
      ;  cl =  mclMatrixRead(xfCl, EXIT_ON_FAIL)
      ;  mcxIOstreamFree(&xfCl)

      ;  if (mx->N_cols != cl->N_rows)
         {  fprintf
            (  stderr
            ,  "clustering of set of size %d cannot pertain to %dx%d matrix\n"
            ,  cl->N_rows
            ,  mx->N_rows
            ,  mx->N_cols
            )
         ;  exit(1)
      ;  }

      ;  {  float       mxMass            =  mclMatrixMass(mx)
         ;  float       mxArea            =     (float) mx->N_cols
                                             *  (mx->N_cols -1)

         ;  float       nrEdges           =  (float) mclMatrixNrofEntries(mx)
         ;  float       mxLinkWeight      =  mxMass / nrEdges

         ;  float       coverage, clLinkWeight

         ;  float       clArea            =  0.0
         ;  float       clMass            =  0.0
         ;  float       clEdgesCovered    =  0.0

         ;  float  globalDensity
                 , withinDensity
                 , outsideDensity
                 , massFraction
                 , areaFraction
         ;  int    c

         ;  for (c=0;c<cl->N_cols;c++)
            {  mclVector *cvec   =  cl->vectors+c
            ;  clEdgesCovered   +=  (float) mclMatrixSubNrofEntries
                                    (  mx, cvec, cvec )
            ;  clMass           +=  mclMatrixSubMass(mx, cvec, cvec)
            ;  clArea           +=  (float) cvec->n_ivps * (cvec->n_ivps -1)
         ;  }
         ;  clLinkWeight         =  clMass / clEdgesCovered

         ;  globalDensity        =  (float) mxMass / (float) mxArea
         ;  withinDensity        =  (float) clMass / (float) clArea
         ;  outsideDensity       =  (float) mxArea - clArea
                                    ?  (  (float) (mxMass - clMass) 
                                       /  (float) (mxArea - clArea)
                                       )
                                    : 0.0

         ;  massFraction         =  mxMass ? clMass / mxMass : 0.0
         ;  areaFraction         =  mxArea ? clArea / mxArea : 0.0

         ;  coverage             =  mclMatrixCoverage(mx, cl, NULL)

         ;  fprintf
            (  stdout
            ,  "For cluster in file [%s]\n"
               " Efficiency  | Mass frac   |"
               " Area frac   | Cl weight   | Mx link weight\n"
               " %.5f       %.5f       %.5f       %.5f       %.5f\n"
            ,  argv[a]

            ,  coverage
            ,  massFraction
            ,  areaFraction
            ,  clLinkWeight      /*  clmass / cledges covered */
            ,  mxLinkWeight      /*  mxmass / mxnrofentries */
            )  ;
      ;  }
      ;  mclMatrixFree(&cl)
      ;  a++
   ;  }

   ;  mclMatrixFree(&mx)
   ;  return 0
;  }

