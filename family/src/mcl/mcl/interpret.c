/*
// interpret.c          Interpretation of clusterings 
*/

#include <math.h>
#include <float.h>
#include <limits.h>

#include "util/distr.h"
#include "util/types.h"
#include "util/alloc.h"
#include "util/file.h"

#include "mcl/interpret.h"

#include "nonema/io.h"

#define  ISaTTRACTIVE_RECURBOUND     20

float    delta             =  100 * FLT_EPSILON;

#define  bit_attractive      0x01
#define  bit_unattractive    0x02
#define  bit_classified      0x04

/*
 *
 *   Routine int isAttractive(,,,) is used by mcxInterpret. Fills array
 *   colProps after a partial categorization. Vertices (i.e. columns
 *   of the matrix M) come in two flavours: i)  bit_attractive ii) and
 *   bit_unattractive. In the partial initialization, a vertex/column c
 *   is attractive if it sees itself (there is a loop from c to c), it is
 *   unattractive if there is no incoming loop at all. isAttractive computes
 *   the closure of the relation "has attractive parent", where a first order
 *   attractive parent is an incoming node which has itself a loop. Initially
 *   unattractive nodes can thus become attractive.

 *   Motivation: mcxInterpret uses each connected set of attractive nodes as
 *   defining (the core of) a separate cluster. All nodes which reach such
 *   a set are included in the cluster as well. This can cause overlap. This
 *   definition and implementation ensures that the resulting clustering is
 *   permutation invariant, i.e. does not depend on the order in which the
 *   columns of M (nodes of the underlying graph) are listed. This is not
 *   entirely true, since there is a bound on the recursion. Graphs meeting
 *   this recursion bound are likely to be very funny.
 *
 */


int isAttractive
(  const mcxMatrix*  Mt
,  int*              colProps
,  int               col
,  int               depth
); 


mcxMatrix* mcxInterpret
(  const mcxMatrix*           A
,  const mcxIpretParam*       ipretParam
)  {  
      mcxMatrix*     clus2elem   =  NULL
   ;  mcxMatrix*     M           =  mcxMatrixCopy(A)
   ;  mcxMatrix*     Mt

   ;  float          w_center    =  ipretParam->w_center
   ;  float          w_selfval   =  ipretParam->w_selfval
   ;  float          w_maxval    =  ipretParam->w_maxval

   ;  int            N_cols      =  M->N_cols
   ;  int               col
                     ,  i
                     ,  startnode
                     ,  n_cluster

   ;  int*           colProps
   ;  mcxVector**    clusterNodes

   ;  colProps       =  (int*) rqAlloc(sizeof(int)*N_cols, RETURN_ON_FAIL)

   ;  if (N_cols && !colProps)
         mcxMemDenied(stderr, "mcxInterpret", "int", N_cols)
      ,  exit(1)

   ;  clusterNodes   =  (mcxVector**) rqAlloc
                        (  sizeof(mcxVector*)*(N_cols+1)
                        ,  RETURN_ON_FAIL
                        )

   ;  if (!clusterNodes)
         mcxMemDenied(stderr, "mcxInterpret", "mcxVector", N_cols+1)
      ,  exit(1)

   ;  for (i=0;i<N_cols;i++)
      *(colProps+i) = 0

   ;  for (col=0;col<N_cols;col++)                    /* thorough clean-up */
      {  
         mcxVector*  vec      =  M->vectors+col
      ;  float       center   =  mcxVectorPowSum(vec, 2)
      ;  float       selfval  =  mcxVectorIdxVal(vec, col, (int*)0)
      ;  float       maxval   =  mcxVectorMaxValue(vec)

      ;  float       bar      =     (w_center * center) 
                                 +  (w_selfval * selfval) 
                                 +  (w_maxval * maxval) 
                                 -  delta
      ;  mcxVectorSelectGqBar (vec, bar)
      ;  mcxVectorMakeCharacteristic (vec)
   ;  }

   ;  Mt = mcxMatrixTranspose(M)

   ;  {  for (col=0;col<N_cols;col++)
         {  mcxVector*  vec         =  M->vectors+col
         ;  int      offset

           /*
            *  vertex col has a loop
            */

         ;  if
            (  mcxVectorIdxVal(vec, col, &offset)
            ,  offset >= 0
            )
            {  colProps[col] = colProps[col] | bit_attractive
         ;  }

           /*
            *  vertex col has no parents (and thus not a loop)
            */

         ;  if ((Mt->vectors+col)->n_ivps == 0)
            {  colProps[col] = colProps[col] | bit_unattractive
         ;  }
      ;  }

        /*
         *  compute closure of Bool "has attractive parent"
         */

      ;  for (col=0;col<N_cols;col++)
         {  isAttractive (Mt, colProps, col, 0)
      ;  }
   ;  }

   ;  startnode = 0
   ;  n_cluster = 0

   ;  while (startnode < N_cols)
      {
         {  while (startnode < N_cols)
            {  if
               (  (colProps[startnode] & bit_attractive)
               &&!(colProps[startnode] & bit_classified)
               )
               {  break
            ;  }
               else
               {  startnode++
            ;  }
         ;  }

         ;  if (startnode == N_cols)
            {  continue
         ;  }
      ;  }
                                            /* new members of cluster */
         {  mcxVector  *leafnodes      =  mcxVectorCreate(1)
                                            /* current members of cluster */
         ;  mcxVector  *treenodes      =  mcxVectorCreate(0)
         ;
         ;  (leafnodes->ivps+0)->val   =  1.0
         ;  (leafnodes->ivps+0)->idx   =  startnode

         ;  while (leafnodes->n_ivps)
            {
               mcxVector  *new_leafnodes   =  mcxVectorCreate(0)
            ;  mcxIvp     *leafivp, *leafl, *leafr

            ;  leafl       =     leafnodes->ivps+0
            ;  leafr       =     leafl + leafnodes->n_ivps

            ;  for (leafivp=leafl; leafivp < leafr; leafivp++)
               {
                  int leafidx       =  leafivp->idx
               ;  colProps[leafidx] =  colProps[leafidx] | bit_classified

               ;  if (colProps[leafidx] & bit_attractive)
                  {  
                     mcxVectorSetMerge          /* look forward too */
                     (  new_leafnodes
                     ,  M->vectors+leafidx
                     ,  new_leafnodes
                     )
                  ;  mcxVectorSetMerge          /* look backward */
                     (  new_leafnodes
                     ,  Mt->vectors+leafidx
                     ,  new_leafnodes
                     )
               ;  }
                  else if (!(colProps[leafidx] & bit_attractive))
                  {  
                     mcxVectorSetMerge          /* look backward only */
                     (  new_leafnodes
                     ,  Mt->vectors+leafidx
                     ,  new_leafnodes
                     )
               ;  }
               }

            ;  mcxVectorSetMerge (treenodes, leafnodes, treenodes)
            ;  mcxVectorSetMinus (new_leafnodes, treenodes, leafnodes)
            ;  mcxVectorFree(&new_leafnodes)
         ;  }

         ;  *(clusterNodes+n_cluster) = treenodes
         ;  mcxVectorFree(&leafnodes)
         ;  n_cluster++
      ;  }
   ;  }

   ;  clus2elem = mcxMatrixAllocZero(n_cluster, N_cols)
   ;  clus2elem->N_rows = A->N_rows

     /*
      *     If this is ever put back in, remember to alloc
      *     n_cluster+1 columns instead of n_cluster (AllocZero above)
      */

   ;  if (0)
      {  int         n_garbage   =  0
      ;  mcxVector*  garbageVec  =  clus2elem->vectors+n_cluster

      ;  for (col=0;col<N_cols;col++)
         {  
            if (!(colProps[col] & bit_classified) )
            n_garbage++
      ;  }

      ;  if (n_garbage)
         {  
            int pos = 0
         ;  mcxVectorResize(garbageVec, n_garbage)

         ;  for (col=0;col<N_cols;col++)
            {  
               if (!(colProps[col] & bit_classified) )
               {  
                  ((garbageVec)->ivps+pos)->idx = col;
               ;  ((garbageVec)->ivps+pos)->val = 1.0;
               ;  pos++
            ;  }
         ;  }
      ;  }
   ;  }

   ;  for (i=0;i<n_cluster;i++)
      {  
         mcxVectorInstantiate
         (  clus2elem->vectors+i
         ,  (*(clusterNodes+i))->n_ivps
         ,  (*(clusterNodes+i))->ivps 
         )
      ;  mcxVectorFree( clusterNodes+i )
   ;  }

   ;  free(colProps)
   ;  free(clusterNodes)
   ;  mcxMatrixFree(&M)
   ;  mcxMatrixFree(&Mt)

   ;  return clus2elem
;  }


int isAttractive
(  const    mcxMatrix*  Mt
,  int*                 colProps
,  int                  col
,  int                  depth
)  {  int   i

   ;  if (colProps[col] & bit_attractive)            /* already categorized */
      return 1

   ;  if (colProps[col] & bit_unattractive)          /* already categorized */
      return 0

   ;  if (depth > ISaTTRACTIVE_RECURBOUND)           /* prevent cycles */
      {  
         colProps[col] = colProps[col] |  bit_unattractive
      ;  return 0
   ;  }

   ;  for (i=0;i<(Mt->vectors+col)->n_ivps;i++)
      {  if
         (  isAttractive
            (  Mt
            ,  colProps
            ,  ((Mt->vectors+col)->ivps+i)->idx
            ,  depth +1
            )
         )
         {  colProps[col] = colProps[col] |  bit_attractive
         ;  return 1
      ;  }                             /* inherits attractivity from parent */
   ;  }

   ;  colProps[col] = colProps[col] |  bit_unattractive        /* no good */
   ;  return 0
;  }



void  clusterMeasure
(  const mcxMatrix*  clus
,  FILE*          fp
)  {
      int         clsize   =  clus->N_cols
   ;  int         clrange  =  clus->N_rows
   ;  int         i
   ;  float       ctr      =  0.0

   ;  for (i=0;i<clus->N_cols;i++)
      ctr     +=  (float) pow((float) (clus->vectors+i)->n_ivps, 2.0)

   ;  if (clsize)
      ctr     /=  clrange

   ;  fprintf
      (  fp
      ,  " %-d"
      ,  clsize
      )
;  }


#if 0
void mcxDiagnosticsAttractor
(  const char*          ffn_attr
,  const mcxMatrix*     clus2elem
,  const mcxDumpParam   dumpParam
)  {  int         n_nodes     =  clus2elem->n_range
   ;  int         n_written   =  dumpParam->n_written
   ;  int         i           =  0
   ;  mcxMatrix*  mtx_Ascore  =  mcxMatrixAllocZero(n_written, n_nodes)
   ;  mcxIOstream*   xfOut    =  mcxIOstreamNew(ffn_atr, "w")

   ;  if (mcxIOstreamOpen(xfOut, RETURN_ON_FAIL) == STATUS_FAIL)
      {  mcxMatrixFree(&mtx_Ascore)
      ;  mcxIOstreamFree(&xfOut)
      ;  return
   ;  }

   ;  for(i=0; i<n_written; i++)
      {  mcxMatrix*  iterand     =  *(dumpParam->iterands+i)
      ;  mcxVector*  vec_Ascore  =  NULL
      ;  if (iterands->N_cols != n_nodes || iterand->n_range != n_nodes)
         {  fprintf(stderr, "mcxDiagnosticsAttractor: dimension error\n")
         ;  exit(1)
      ;  }

      ;  vec_Ascore  =  mcxAttractivityScale(iterand)
      ;  mcxVectorCreate((mtx_Ascore->vectors+i),
            vec_Ascore->n_ivps, vec_Ascore->ivps)
      ;  mcxVectorFree(&vec_Ascore)
   ;  }

   ;  mcxMatrixWrite(mtx_Ascore, xfOut, RETURN_ON_FAIL)
   ;  mcxMatrixFree(mtx_Ascore)
;  }


void mcxDiagnosticsPeriphery
(  const char*     ffn_peri
,  const mcxMatrix*  clustering
,  const mcxDumpParam   dumpParam
)  {
;  }
#endif


mcxVector*  mcxAttractivityScale
(  const mcxMatrix*           M
)  {  int         N_cols      =  M->N_cols
   ;  int         col

   ;  mcxVector*     vec_values     =  mcxVectorCreate(N_cols)

   ;  for (col=0;col<N_cols;col++)
      {  mcxVector*  vec      =  M->vectors+col
      ;  float    selfval  =  mcxVectorIdxVal(vec, col, (int*)0)
      ;  float    maxval   =  mcxVectorMaxValue(vec)
      ;  if (maxval <= 0.0)
         {  fprintf
            (  stderr
            ,  "mcxAttractivity: encountered nonpositive maximum value\n"
            )
         ;  maxval = 1.0  
      ;  }
      ;  (vec_values->ivps+col)->idx = col
      ;  (vec_values->ivps+col)->val = selfval / maxval
   ;  }
   ;  return vec_values
;  }

mcxIpretParam* mcxIpretParamNew
(void
)  {  
      mcxIpretParam* ipretParam     =  (mcxIpretParam*) rqAlloc
                                       (  sizeof(mcxIpretParam)
                                       ,  EXIT_ON_FAIL
                                       )
   ;  ipretParam->w_center           =     0.0
   ;  ipretParam->w_selfval          =     0.05
   ;  ipretParam->w_maxval           =     0.9

   ;  return ipretParam
;  }



float  mcxVectorCoverage
(  const mcxVector*     vec
,  const mcxVector*     cluster
,  int                  i
,  float                *maxcoverage
)  {  mcxVector*        pvec        =  mcxVectorCopy(vec)
   ;  mcxVector*        join        =  mcxVectorSetMerge(vec, cluster, NULL)
   ;  float             ctr, maxval, coverage
   ;  float             diff        =  0.0
   ;  int               n_join      =  join->n_ivps ? join->n_ivps : INT_MAX

   ;  mcxIvp*           vecivp      =  pvec->ivps
   ;  mcxIvp*           vecivpmax   =  vecivp+pvec->n_ivps  
   ;  mcxIvp*           clsivp      =  cluster->ivps
   ;  mcxIvp*           clsivpmax   =  clsivp+cluster->n_ivps  

   ;  if (!vec->n_ivps) return 0.0

   ;  mcxVectorNormalize(pvec)
   ;  ctr      =  mcxVectorPowSum(pvec, 2.0)
   ;  maxval   =  mcxVectorMaxValue(pvec)

   ;  if (ctr <= 0.0)
      {  mcxVectorFree(&pvec)
      ;  return 0.0
   ;  }

  /*  invariant:
   *  keep vecivp->idx <= clsivp->idx
   */
   ;  while(vecivp<vecivpmax && clsivp < clsivpmax)
      {  if (vecivp->idx == i)                     /* disregard loop element. */
         {  vecivp++
      ;  }
         else if (vecivp->idx < clsivp->idx)       /* vec element not in clustering. */
         {  diff        -= vecivp->val
         ;  vecivp++
      ;  }
         else if (vecivp->idx > clsivp->idx)
         {  clsivp++
      ;  }
         else
         {  diff        += vecivp->val
         ;  vecivp++, clsivp++
      ;  }
   ;  }

   ;  while(vecivp<vecivpmax)
      {  diff           -= vecivp->val
      ;  vecivp++
   ;  }

   ;  coverage = (1.0 - ((cluster->n_ivps - (diff/ctr)) / n_join))
   ;  if (maxcoverage)
         *maxcoverage = (1.0 - ((cluster->n_ivps - (diff/maxval)) / n_join))

   ;  mcxVectorFree(&pvec)
   ;  mcxVectorFree(&join)
   ;  return coverage
;  }


float  mcxMatrixCoverage
(  const mcxMatrix*        mx
,  const mcxMatrix*        clus2elem
,  float                   *maxcoverage
)  {
      mcxMatrix*           elem2clus   =  mcxMatrixTranspose(clus2elem)
   ;  int               c
   ;  float             coverage       =  0.0
   ;  float             vecmaxcoverage =  0.0
   ;  float             thismaxcoverage=  0.0
   ;  int               missing        =  0

   ;  if (clus2elem->N_rows != mx->N_cols)
      {  fprintf
         (  stderr
         ,  "[mcxMatrixCoverage] dimensions [%d, %d] do not fit\n"
         ,  clus2elem->N_rows
         ,  mx->N_cols
         )
      ;  exit(1)
   ;  }

   ;  for (c=0;c<mx->N_cols;c++)
      {  if ((elem2clus->vectors+c)->n_ivps == 0)
         {  fprintf
            (  stderr
            ,  "[mcxMatrixCoverage] node [%d] not in cluster\n"
            ,  c
            )
         ;  missing++
      ;  }
      ;  {  int   clusidx  =  ((elem2clus->vectors+c)->ivps+0)->idx;
         ;  coverage      +=  mcxVectorCoverage
                              (  mx->vectors+c
                              ,  clus2elem->vectors+clusidx
                              ,  c
                              ,  &vecmaxcoverage
                              )
         ;  thismaxcoverage += vecmaxcoverage
      ;  }
   ;  }
   ;  if (missing >= mx->N_cols)
      {  missing = 0                   /* safety measure */
   ;  }

   ;  if (maxcoverage)
      {  *maxcoverage = thismaxcoverage / ((float) (mx->N_cols - missing))
   ;  }
   ;  return coverage/((float) (mx->N_cols - missing))
;  }



