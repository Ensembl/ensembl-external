
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
      mcxIOstream       *xfiCl      =  NULL
   ;  mcxIOstream       *xfiMx      =  NULL
   ;  mcxIOstream       *xfNodes    =  NULL
   ;  mcxIOstream       *xfClus     =  NULL

   ;  mcxMatrix         *cl         =  NULL
   ;  mcxMatrix         *el2cl      =  NULL
   ;  mcxMatrix         *el2mass    =  NULL
   ;  mcxMatrix         *cl2mass    =  NULL
   ;  mcxMatrix         *mx         =  NULL

   ;  mcxVector         *meet       =  NULL

   ;  int               a           =  1
   ;  int               i

   ;  mcxVerbosityIoNonema            =  0

   ;  if ((argc < 9) || !strcmp(argv[1], "-h"))
      {  
fprintf
(  stdout
,  "\n"
   "[clmproject] usage:\n"
   "clmproject <options>\n"
   "\n"
   "Options (flags marked * are obligatory):\n"
   "-icl      <fname>  *  read clustering matrix from file\n"
   "-imx      <fname>  *  read corresponding graph matrix from file\n"
   "-nodes    <fname>  *  write node confidence matrix to file\n"
   "-clusters <fname>  *  write cluster confidence matrix to file\n"
   "\n"
   "Node confidence matrix: columns range over all nodes in the graph.\n"
   "  Given a node c, the entry in row zero shows the mass fraction of edges\n"
   "  that have c as tail and for which the head is in the same cluster as c,\n"
   "  relative to the mass of all edges that have c as tail.\n"
   "  The entry in row one lists the number of edges originating from c.\n"
   "Cluster confidence matrix: columns range over all clusters.\n"
   "  Given a cluster C, the entry in row zero shows the average of the node\n"
   "  confidence (defined above) for all nodes c in C.\n"
   "  The entry in row one lists the number of nodes in c.\n"
   "\n"
)
      ;  exit(0)
   ;  }

   ;  while(a < argc)
      {  if (!strcmp(argv[a], "-icl"))
         {  if (a++ + 1 < argc)
            xfiCl =  mcxIOstreamNew(argv[a], "r")
         ;  else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-clusters"))
         {  if (a++ + 1 < argc)
            {  xfClus = mcxIOstreamNew(argv[a], "w")
            ;  mcxIOstreamOpen(xfClus, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-nodes"))
         {  if (a++ + 1 < argc)
            {  xfNodes = mcxIOstreamNew(argv[a], "w")
            ;  mcxIOstreamOpen(xfNodes, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-imx"))
         {  if (a++ + 1 < argc)
            xfiMx = mcxIOstreamNew(argv[a], "r")
         ;  else goto arg_missing;
      ;  }
         else if (0)
         {  arg_missing:
         ;  fprintf
            (  stderr
            ,  "[clmproject] Flag %s needs argument; see help (-h)\n"
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }
         else
         {  fprintf
            (  stderr
            ,  "[clmproject] Unrecognized flag %s; see help (-h)\n"
            ,  argv[a]
            )
         ;  exit(1)
      ;  }
      ;  a++
   ;  }

   ;  cl   =  mcxMatrixRead(xfiCl, 0)
   ;  mx   =  mcxMatrixRead(xfiMx, 0)
   ;  mcxIOstreamFree(&xfiCl)
   ;  mcxIOstreamFree(&xfiMx)

   ;  if (mx->N_cols != cl->N_rows)
      {  fprintf
         (  stderr
         ,  "[clmproject] cluster range [%d] and matrix domain [%d]"
            "do not match\n"
         ,  cl->N_rows
         ,  mx->N_cols
         )
      ;  exit(1)
   ;  }

   ;  el2cl    =  mcxMatrixTranspose(cl)
   ;  el2mass  =  mcxMatrixComplete(mx->N_cols, 2, 0.0)
   ;  cl2mass  =  mcxMatrixComplete(cl->N_cols, 2, 0.0)

   ;  for (i=0;i<el2cl->N_cols;i++)
      {  
         int clusIdx, n_nb
      ;  float meetMass, vecMass

      ;  if ((el2cl->vectors+i)->n_ivps == 0)
         {  fprintf(stderr, "[clmproject] Element [%d] not in clustering\n", i)
      ;  }
         else
         {  clusIdx     =  ((el2cl->vectors+i)->ivps+0)->idx
         ;  meet        =  mcxVectorSetMeet
                           (  mx->vectors+i
                           ,  cl->vectors+clusIdx
                           ,  meet
                           )
         ;  meetMass    =  mcxVectorSum(meet)
         ;  vecMass     =  mcxVectorSum(mx->vectors+i)
         ;  n_nb        =  (mx->vectors+i)->n_ivps

         ;  if (vecMass)
            {  float frac = meetMass / vecMass
            ;  ((el2mass->vectors+i)->ivps+0)->val          =  frac
            ;  ((el2mass->vectors+i)->ivps+1)->val          =  n_nb
            ;  ((cl2mass->vectors+clusIdx)->ivps+0)->val   +=  frac
         ;  }
      ;  }
   ;  }

   ;  mcxVectorFree(&meet)

   ;  for (i=0;i<cl2mass->N_cols;i++)
      {  int n_ivps = (cl->vectors+i)->n_ivps
      ;  if (n_ivps)
         {  ((cl2mass->vectors+i)->ivps+0)->val /= n_ivps
         ;  ((cl2mass->vectors+i)->ivps+1)->val  = (float) n_ivps
      ;  }
   ;  }

   ;  mcxMatrixWriteAscii(el2mass, xfNodes, 6, RETURN_ON_FAIL);
   ;  mcxMatrixWriteAscii(cl2mass, xfClus, 6, EXIT_ON_FAIL);
   ;  return 0
;  }

