

/*
//
*/

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/io.h"
#include "nonema/iface.h"
#include "util/file.h"
#include "util/types.h"
#include "intalg/ilist.h"
#include "intalg/la.h"
#include "mcl/interpret.h"
#include <string.h>

int main
(  int                  argc
,  const char*          argv[]
)  {  
      mcxIOstream           *xfMx       =  NULL

   ;  mcxMatrix         *cl         =  NULL
   ;  mcxMatrix         *mx         =  NULL

   ;  int               a           =  2

   ;  mcxVerbosityIoNonema          =  0

   ;  if ((argc < 3) || !strcmp(argv[1], "-h"))
      {  fprintf
         (  stdout
         ,  "\n"
            "[clminfo] usage:\n"
            "clminfo <mx file> <cl file> [<cl file>*]\n"
            "  where mx file encodes a graph (in MCL matrix format)\n"
            "  and each cl file encodes a clustering of this graph (in MCL"
               " matrix format)\n"
            "\n"
         )
      ;  exit(0)
   ;  }

   ;  xfMx     =  mcxIOstreamNew(argv[1], "r")
   ;  mx       =  mcxMatrixRead
                  (  xfMx
                  ,  0              /* do not return */
                  )
   ;  mcxIOstreamFree(&xfMx)

   ;  while(a < argc)
      {    
         mcxIOstream *xfCl    =  mcxIOstreamNew(argv[a], "r")
      ;  cl                   =  mcxMatrixRead
                              (  xfCl
                              ,  0  /* do not return */
                              )
      ;  mcxIOstreamFree(&xfCl)

      ;  {  float       mxMass            =  mcxMatrixMass(mx)
         ;  float       mxArea            =     (float) mx->N_cols
                                             *  (mx->N_cols -1)

         ;  float       nrEdges           =  (float) mcxMatrixNrofEntries(mx)
         ;  float       mxLinkWeight      =  mxMass / nrEdges

         ;  float       coverage, clLinkWeight

         ;  float       clArea            =  0.0
         ;  float       clMass            =  0.0
         ;  float       clEdgesCovered    =  0.0

         ;  float       globalDensity
                     ,  withinDensity
                     ,  outsideDensity
                     ,  massFraction
                     ,  areaFraction

         ;  int         c

         ;  for (c=0;c<cl->N_cols;c++)
            {  mcxVector *cvec   =  cl->vectors+c
            ;  clEdgesCovered   +=  (float) mcxSubmatrixNrofEntries
                                    (  mx, cvec, cvec )
            ;  clMass           +=  mcxSubmatrixMass(mx, cvec, cvec)
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

         ;  coverage             =  mcxMatrixCoverage(mx, cl, NULL)

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
            ,  clLinkWeight
            ,  mxLinkWeight
            )  ;
      ;  }
      ;  mcxMatrixFree(&cl)
      ;  a++
   ;  }

   ;  mcxMatrixFree(&mx)
   ;  return 0
;  }

