/*
// mcl.c                Core MCL clustering algorithm
*/

#include <pthread.h>

#include "mcl/mcl.h"
#include "mcl/params.h"
#include "mcl/dpsd.h"

#include "nonema/io.h"

#include "util/txt.h"
#include "util/file.h"
#include "util/types.h"
#include "util/alloc.h"


#define ITERATION_INITIAL  1
#define ITERATION_MAIN     2


static int mclVerbosityStart    =  1;

static void pruningExplain
(  FILE* vbfp
)  ;

typedef struct
{
   int            id
;  int            start
;  int            end
;  float          power
;  mcxMatrix*     mx
;
}  mcxFlowInflate_thread_arg   ;


pthread_t         *threads_inflate;
pthread_t         *threads_expand;              /* used in mcl/compose.c */
static pthread_attr_t  pthread_custom_attr;


void mcxFlowInflate_threaded
(  
   mcxMatrix*        mx
,  float             power
)  ;


void  mcxFlowInflate_thread
(  
   void *arg
)  ;


void  mcxDumpMatrix
(  
   mcxMatrix*     mx
,  const char*    fstem
,  const char*    affix
,  const char*    pfix
,  int            n
,  int            printValue
)  ;


void  mcxDumpVector
(  
   mcxVector*     vec
,  const char*    fstem
,  const char*    affix
,  const char*    pfix
,  int            n
,  int            printValue
)  ;


int mcxDoIteration
(  
   mcxMatrix**       mxin
,  mcxMatrix**       mxout
,  const mclParam*   param
,  mcxComposeStats*  stats
,  int               type
,  int               ite_index
)  ;


mclParam* mclParamNew
(  void
)  
   {  
      mclParam* param = (mclParam*) rqAlloc(sizeof(mclParam), EXIT_ON_FAIL)

   ;  param->mainInflation             =     2
   ;  param->mainLoopLength            =     10000
   ;  param->initInflation             =     2
   ;  param->initLoopLength            =     0
                                     
   ;  param->printDigits               =     3
   ;  param->printMatrix               =     0
                                     
   ;  param->mcxIpretParam             =     mcxIpretParamNew()
   ;  return param
;  }


mcxMatrix*  mclCluster
(  
   mcxMatrix*        mxEven
,  const mclParam*   param
)
   {
      mcxComposeStats*  stats          =  mcxComposeStatsNew(mcl_nx,mcl_ny)

   ;  mcxMatrix*        mxOdd          =  NULL
   ;  mcxMatrix*        mxCluster      =  NULL
   ;  int               i              =  0
   ;  int               n_vec          =  mxEven->N_cols
   ;  int               bPrint         =  param->printMatrix
   ;  int               digits         =  param->printDigits

   ;  threads_inflate
      =  (pthread_t *) rqAlloc
         (mcl_num_ithreads*sizeof(pthread_t), EXIT_ON_FAIL)

   ;  threads_expand
      =  (pthread_t *) rqAlloc
         (mcl_num_ethreads*sizeof(pthread_t), EXIT_ON_FAIL)

   ;  if (bPrint)
      mcxFlowPrettyPrint
      (  mxEven   ,  stdout
      ,  digits   ,  "1 After centering (if) and normalization"
      )

   ;  if (mclDumpIterands)
      mcxDumpMatrix(mxEven, mclDumpStem, "ite", "", 0, 1)

   ;  if (mclVerbosityVectorProgress)
      {  
         if (!mclVerbosityPruning)
         fprintf(stdout, " ite ")

      ;  for (i=0;i<n_vec/mclVectorProgression;i++)
         fputc('-', stdout)

      ;  fprintf(stdout, mclVerbosityPruning ? "\n" : " inhomogeneity\n")
   ;  }
      else if (mclVerbosityMatrixProgress)
      fprintf(stdout, " ite  inhomogeneity\n")

   ;  for (i=0;i<param->initLoopLength;i++)
      {  
         int convergence = mcxDoIteration (  &mxEven
                                          ,  &mxOdd
                                          ,  param
                                          ,  stats
                                          ,  ITERATION_INITIAL
                                          ,  i+1
                                          )
      ;  convergence    *= 1              /* don't care for initial loop */
      ;  mcxMatrixFree(&mxEven)
      ;  mxEven  =  mxOdd
   ;  }

      if (  param->initLoopLength
         && (  mclVerbosityPruning
            || mclVerbosityVectorProgress
            )
         )
      fprintf
      (  stdout
      ,  "====== Changing from initial to main inflation now ====\n"
      )

   ;  for (i=0;i<param->mainLoopLength;i++)
      {  
         int convergence = mcxDoIteration (  &mxEven
                                          ,  &mxOdd
                                          ,  param
                                          ,  stats
                                          ,  ITERATION_MAIN
                                          ,  i+1+param->initLoopLength
                                          )
      ;  mcxMatrixFree(&mxEven)
      ;  mxEven  =  mxOdd
      ;  if (convergence)
         {  if (mclVerbosityPruning)
            fprintf(stdout, "\n")
         ;  break
      ;  }
   ;  }

   ;  mxCluster = mcxInterpret(mxEven, param->mcxIpretParam)
   ;  mcxMatrixFree(&mxEven)

   ;  rqFree(threads_inflate)
   ;  rqFree(threads_expand)

   ;  mcxComposeStatsFree(stats)

   ;  return mxCluster
;  }

void mcxMatrixCenter
(  mcxMatrix*        mx
,  float             w_center
,  float             w_selfval
)  {  
      int      col

   ;  for (col=0;col<mx->N_cols;col++)
      {
         mcxVector*  vec      =  mx->vectors+col
      ;  mcxIvp*     match    =  NULL
      ;  int         offset   =  -1
      ;  float       selfval

      ;  if
         (  vec->ivps
         && (  mcxVectorIdxVal(vec, col, &offset)
            ,  offset >= 0
            )
         )  
         {  
            match = (vec->ivps+offset)
         ;  selfval           =  match->val
         ;  match->val        =  0.0
      ;  }
         else                    /* create extra room in vector */
         { 
            mcxVectorResize (vec, (vec->n_ivps)+1)
         ;  match             =  vec->ivps+(vec->n_ivps-1)
         ;  match->val        =  0.0
         ;  match->idx        =  col
         ;  mcxVectorSort (vec, mcxIvpIdxCmp)
                                 /* ^^^ this could be done by shifting */

         ;  mcxVectorIdxVal(vec, col, &offset)

         ;  if (offset < 0)
            fprintf
            (  stderr
            ,  "[mcxMatrixCenter SNH] insertion failed ??\n"
            )
         ,  exit(1)

         ;  match             =  (vec->ivps+offset)
         ;  selfval           =  0.0
      ;  }

         {  
            float sum            =  mcxVectorSum(vec)

         ;  if (sum == 0.0)
            {  match->val =  1
         ;  }
            else
            {  match->val        =  w_center == 0.0
                                    ?  0.0
                                    :  (  w_center * mcxVectorPowSum(vec, 2)
                                          +  w_selfval * selfval
                                       ) / sum
         ;  }
      ;  }

      ;  mcxVectorNormalize(vec)
   ;  }
;  }


void mcxFlowInflate
(  
   mcxMatrix*              mx
,  float                   power
)  {  
      mcxVector*     vecPtr          =     mx->vectors
   ;  mcxVector*     vecPtrMax       =     vecPtr + mx->N_cols

   ;  while (vecPtr < vecPtrMax)
      {  mcxVectorInflate(vecPtr, power)
      ;  vecPtr++
   ;  }
;  }


void mcxFlowInflate_threaded
(  
   mcxMatrix*        mx
,  float             power
)  {
      mcxVector*     vecPtr      =  mx->vectors
   ;  mcxVector*     vecPtrMax   =  vecPtr + mx->N_cols
   ;  int            workLoad    =  mx->N_cols / mcl_num_ithreads
   ;  int            workTail    =  mx->N_cols % mcl_num_ithreads
   ;  int            i           =  0

   ;  pthread_attr_init(&pthread_custom_attr)

   ;  for (i=0;i<mcl_num_ithreads;i++)
      {
         mcxFlowInflate_thread_arg *a
                     =  (mcxFlowInflate_thread_arg *)
                        malloc(sizeof(mcxFlowInflate_thread_arg))
      ;  a->id       =  i
      ;  a->start    =  workLoad * i
      ;  a->end      =  workLoad * (i+1)
      ;  a->mx       =  mx
      ;  a->power    =  power

      ;  if (i+1==mcl_num_ithreads)
         a->end   +=  workTail

      ;  pthread_create
         (  &threads_inflate[i]
         ,  &pthread_custom_attr
         ,  (void *) mcxFlowInflate_thread
         ,  (void *) a
         )
   ;  }

   ;  for (i = 0; i < mcl_num_ithreads; i++)
      pthread_join(threads_inflate[i], NULL)
;  }


void  mcxFlowInflate_thread
( 
   void *arg
)
   {
      mcxFlowInflate_thread_arg
                     *a          =  (mcxFlowInflate_thread_arg *)  arg
   ;  mcxMatrix*     mx          =  a->mx
                     
   ;  mcxVector*     vecPtr      =  mx->vectors + a->start
   ;  mcxVector*     vecPtrMax   =  mx->vectors + a->end
   ;  float          power       =  a->power

   ;  while (vecPtr < vecPtrMax)
      {
         mcxVectorInflate(vecPtr, power)
      ;  vecPtr++
   ;  }

   ;  free(a)
;  }


int mcxDoIteration
(  mcxMatrix**          mxin
,  mcxMatrix**          mxout
,  const mclParam*      param
,  mcxComposeStats*     stats
,  int                  type
,  int                  ite_index
)  {
      int               bPrint         =  param->printMatrix
   ;  int               digits         =  param->printDigits
   ;  FILE*             vbfp           =  stdout
   ;  int               bInitial       =  (type == ITERATION_INITIAL)
   ;  const char        *when          =  bInitial ? "initial" : "main"
   ;  float             inflation      =  bInitial
                                          ?  param->initInflation
                                          :  param->mainInflation
   ;  char              msg[80]

   ;  if (mclVerbosityVectorProgress && !mclVerbosityPruning)
      fprintf(stdout, "%3d  ", ite_index)

   ;  if (  (mclModeCompose == MCL_COMPOSE_DENSE)
         && (ite_index > 1)
         && mcxMatrixNrofEntries(*mxin) < pow((*mxin)->N_cols, 1.5)
         )
      mclModeCompose = MCL_COMPOSE_SPARSE

   ;  *mxout =  mcxFlowExpand(*mxin, stats )

   ;  if (bPrint)
      {  sprintf
         (  msg, "%d%s%s%s"
         ,  2*ite_index, " After mcxFlowExpand (", when, ")"
         )
      ;  mcxFlowPrettyPrint(*mxout, stdout, digits, msg)
   ;  }


   ;  if (mclVerbosityVectorProgress)
      {  if (mclVerbosityPruning)
         fprintf(stdout, "\n")
      ;  else
         fprintf(stdout, " %6.2f\n", stats->inhomogeneity)
   ;  }
      else if (!mclVerbosityPruning && mclVerbosityMatrixProgress)
      fprintf(stdout, "%3d  %6.2f\n", ite_index, stats->inhomogeneity)


   ;  if (  mclVerbosityPruning || mclDumpClusters )
      { 
         mcxMatrix*  clus  =  mcxInterpret(*mxout, param->mcxIpretParam)

      ;  if (mclVerbosityPruning)
         {  
            if (mclVerbosityStart)
            {  
               pruningExplain(vbfp)
            ;  mclVerbosityStart = 0
         ;  }

         ;  mcxComposeStatsPrint(stats, vbfp)
         ;  fprintf(vbfp, "\n")
      ;  }

      ;  if (mclDumpClusters)
         {  mcxDumpMatrix(clus, mclDumpStem, "cls", "", ite_index, 0)
      ;  }
      ;  mcxMatrixFree(&clus)
   ;  }

      if (mcl_num_ithreads)
      mcxFlowInflate_threaded(*mxout, inflation)
   ;  else
      mcxFlowInflate(*mxout, inflation)

   ;  if (bPrint)
      {  sprintf
         (  msg,  "%d%s%s%s"
         ,  2*ite_index+1, " After inflation (", when, ")"
         )
      ;  mcxFlowPrettyPrint(*mxout, stdout, digits, msg)
   ;  }

   ;  if (mclDumpIterands)
         mcxDumpMatrix(*mxout, mclDumpStem, "ite", "", ite_index, 1)

   ;  if (mclDumpAttractors)
      {  mcxMatrix*  diago = mcxDiagOrdering(*mxout, &mcl_vec_attr)
      ;  mcxDumpVector(mcl_vec_attr, mclDumpStem, "attr", ".vec", ite_index, 1)
      ;  mcxMatrixFree(&diago)
   ;  }

   ;  if (stats->inhomogeneity < mclInhomogeneityStop)
      return 1
   ;  else
      return 0
;  }


void  mcxDumpMatrix
(  mcxMatrix*     mx
,  const char*    fstem
,  const char*    affix
,  const char*    postfix
,  int            n
,  int            printValue
)  {  mcxIOstream*   xfDump
   ;  char snum[18]
   ;  mcxTxt*  fname

   ;  if (  (  mclDumpOfset
            && (n<mclDumpOfset)
            )
         || (  mclDumpBound
            && (n >= mclDumpBound)
            )
         )
         return

   ;  fname = mcxTxtNew(fstem)
   ;  mcxTxtAppend(fname, affix)

   ;  sprintf(snum, "%d", n)
   ;  mcxTxtAppend(fname, snum)
   ;  mcxTxtAppend(fname, postfix)

   ;  xfDump   =  mcxIOstreamNew(fname->str, "w")

   ;  if (mcxIOstreamOpen(xfDump, RETURN_ON_FAIL) != STATUS_OK)
      {  fprintf
         (  stderr
         ,  "[mcxDumpMatrix] cannot open stream [%s], ignoring\n"
         ,  xfDump->fn->str
         )
      ;  return
   ;  }
      else
      {  if (mclDumpMode == 'a')
         mcxMatrixWriteAscii(mx, xfDump, printValue ? 8 : -1, RETURN_ON_FAIL)
      ;  else
         mcxMatrixWrite(mx, xfDump, RETURN_ON_FAIL)
   ;  }

   ;  mcxIOstreamFree(&xfDump)
   ;  mcxTxtFree(&fname)
;  }


void  mcxDumpVector
(  mcxVector*     vec
,  const char*    fstem
,  const char*    affix
,  const char*    postfix
,  int            n
,  int            printValue
)  {  mcxIOstream*   xf
   ;  char snum[18]
   ;  mcxTxt*  fname

   ;  if (  (  mclDumpOfset
            && (n<mclDumpOfset)
            )
         || (  mclDumpBound
            && (n >= mclDumpBound)
            )
         )
         return

   ;  fname = mcxTxtNew(fstem)
   ;  mcxTxtAppend(fname, affix)

   ;  sprintf(snum, "%d", n)
   ;  mcxTxtAppend(fname, snum)
   ;  mcxTxtAppend(fname, postfix)

   ;  xf =  mcxIOstreamNew(fname->str, "w")
   ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) == STATUS_FAIL)
      {  mcxTxtFree(&fname)
      ;  mcxIOstreamFree(&xf)
      ;  return
   ;  }

   ;  if (mclDumpMode == 'a')
      mcxVectorWriteAscii(vec, xf->fp, printValue ? 8 : -1)
   ;  else
      mcxVectorWrite(vec, xf, RETURN_ON_FAIL)

   ;  mcxIOstreamFree(&xf)
   ;  mcxTxtFree(&fname)
;  }


static void pruningExplain
(  FILE* vbfp
)  
   {
   const char* pruneMode      =  (mclModePruning == MCL_PRUNING_ADAPT)
                              ?  "adaptive"
                              :  "rigid"  
;  const char* pStatus        =  (mclModePruning == MCL_PRUNING_ADAPT)
                              ?  "minimum"
                              :  "rigid"  
;

fprintf
(  vbfp
,  "The %s threshold value equals [%f] (-p <f> or -P <i>)).\n"
,  pStatus
,  mclPrecision
)  ;

if (mclMarknum && mclSelect)
fprintf
(  vbfp
,  "Exact selection prunes to at most %d positive entries (-m <i>).\n"
,  mclMarknum
)  ;

if (mclMarknum && mclRecover)
fprintf
(  vbfp
,  "If %s thresholding leaves less than %2.0f%% mass (-pct) and less than\n"
   "%d entries, as much mass as possible is recovered (--recover).\n"
,  pruneMode
,  100 * mclPct
,  mclMarknum
)  ;

fprintf
(  vbfp
,  "\nLegend\n"
   "all: average over all vectors\n"
   "ny:  average over the worst %d cases (-ny <i>).\n"
   "nx:  average over the worst %d cases (-nx <i>).\n"
   "<>:  recovery is %sactivated. (-m, -M, -pct, --recover)\n"
   "[]:  selection is %sactivated. (-m, -M, --select)\n"
   "recovery and selection: 'mcldoc pruning' explains\n"
   "8532c:  'mcldoc 8532c' explains.\n"
,  mcl_ny
,  mcl_nx
,  (mclMarknum && mclRecover) ? "" : "NOT "
,  (mclMarknum && mclSelect) ? "" : "NOT "
)  ;

fprintf
(  vbfp
,  "\n"
"----------------------------------------------------------------------------\n"
" mass percentages  | distributions of vector sizes |#recover cases <>       \n"
"         |         |__ compose ________ prune _____||    #select cases []   \n"
"  prune  | final   |000  00   0    |000  00   0    ||       |     #below pct\n"
"all ny nx|all ny nx|8532c8532c8532c|8532c8532c8532c|V       V        V      \n"
"---------.---------.---------------.---------------.-------.--------.-------\n"
)  ;
}


