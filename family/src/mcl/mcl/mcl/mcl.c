/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <pthread.h>

#include "mcl.h"
#include "params.h"
#include "dpsd.h"

#include "nonema/io.h"
#include "nonema/matrix.h"

#include "util/txt.h"
#include "util/file.h"
#include "util/types.h"
#include "util/alloc.h"


#define ITERATION_INITIAL  1
#define ITERATION_MAIN     2


static int mclVerbosityStart    =  1;

typedef struct
{
   int            id
;  int            start
;  int            end
;  float          power
;  mclMatrix*     mx
;
}  localMatrixInflate_worker_arg   ;


pthread_t         *threads_inflate;
pthread_t         *threads_expand;              /* used in mcl/compose.c */
static pthread_attr_t  pthread_custom_attr;

void localMatrixInflate_manager
(  mclMatrix*        mx
,  float             power
)  ;

void  localMatrixInflate_worker
(  void *arg
)  ;

void  mcxDumpMatrix
(  mclMatrix*     mx
,  const char*    fstem
,  const char*    affix
,  const char*    pfix
,  int            n
,  int            printValue
)  ;

void  mcxDumpVector
(  mclVector*     vec
,  const char*    fstem
,  const char*    affix
,  const char*    pfix
,  int            n
,  int            printValue
)  ;

int doIteration
(  mclMatrix**       mxin
,  mclMatrix**       mxout
,  const mclParam*   param
,  mclComposeStats*  stats
,  int               type
,  int               ite_index
)  ;

mclParam* mclParamNew
(  void
)  
   {  mclParam* param = (mclParam*) mcxAlloc(sizeof(mclParam), EXIT_ON_FAIL)

   ;  param->mainInflation             =     2
   ;  param->mainLoopLength            =     10000
   ;  param->initInflation             =     2
   ;  param->initLoopLength            =     0
                                     
   ;  param->printDigits               =     3
   ;  param->printMatrix               =     0
                                     
   ;  param->mclIpretParam             =     mclIpretParamNew()
   ;  return param
;  }


mclMatrix*  mclCluster
(  mclMatrix*        mxEven
,  const mclParam*   param
)
   {  mclComposeStats*  stats          =  mclComposeStatsNew(mcl_nx,mcl_ny)

   ;  mclMatrix*        mxOdd          =  NULL
   ;  mclMatrix*        mxCluster      =  NULL
   ;  int               i              =  0
   ;  int               n_vec          =  mxEven->N_cols
   ;  int               bPrint         =  param->printMatrix
   ;  int               digits         =  param->printDigits

   ;  threads_inflate
      =  (pthread_t *) mcxAlloc
         (mcl_num_ithreads*sizeof(pthread_t), EXIT_ON_FAIL)

   ;  threads_expand
      =  (pthread_t *) mcxAlloc
         (mcl_num_ethreads*sizeof(pthread_t), EXIT_ON_FAIL)

   ;  if (bPrint)
      mclFlowPrettyPrint
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

   ;  if (mclInflateFirst)
      {  if (mcl_num_ithreads)
         localMatrixInflate_manager(mxEven, param->mainInflation)
      ;  else
         mclMatrixInflate(mxEven, param->mainInflation)
   ;  }

   ;  for (i=0;i<param->initLoopLength;i++)
      {  
         int convergence = doIteration (  &mxEven
                                       ,  &mxOdd
                                       ,  param
                                       ,  stats
                                       ,  ITERATION_INITIAL
                                       ,  i+1
                                       )
      ;  convergence    *= 1              /* don't care for initial loop */
      ;  mclMatrixFree(&mxEven)
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
         int convergence = doIteration (  &mxEven
                                       ,  &mxOdd
                                       ,  param
                                       ,  stats
                                       ,  ITERATION_MAIN
                                       ,  i+1+param->initLoopLength
                                       )
      ;  mclMatrixFree(&mxEven)
      ;  mxEven  =  mxOdd
      ;  if (convergence)
         {  if (mclVerbosityPruning)
            fprintf(stdout, "\n")
         ;  break
      ;  }
   ;  }

   ;  mxCluster = mclInterpret(mxEven, param->mclIpretParam)
   ;  mclMatrixFree(&mxEven)

   ;  mcxFree(threads_inflate)
   ;  mcxFree(threads_expand)

   ;  mclComposeStatsFree(&stats)

   ;  return mxCluster
;  }

void mclMatrixCenter
(  mclMatrix*        mx
,  float             w_center
,  float             w_selfval
)  {  
      int      col

   ;  for (col=0;col<mx->N_cols;col++)
      {
         mclVector*  vec      =  mx->vectors+col
      ;  mclIvp*     match    =  NULL
      ;  int         offset   =  -1
      ;  float       selfval

      ;  if
         (  vec->ivps
         && (  mclVectorIdxVal(vec, col, &offset)
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
            mclVectorResize (vec, (vec->n_ivps)+1)
         ;  match             =  vec->ivps+(vec->n_ivps-1)
         ;  match->val        =  0.0
         ;  match->idx        =  col
         ;  mclVectorSort (vec, mclIvpIdxCmp)
                                 /* ^^^ this could be done by shifting */

         ;  mclVectorIdxVal(vec, col, &offset)

         ;  if (offset < 0)
            fprintf
            (  stderr
            ,  "[mclMatrixCenter SNH] insertion failed ??\n"
            )
         ,  exit(1)

         ;  match             =  (vec->ivps+offset)
         ;  selfval           =  0.0
      ;  }

         {  
            float sum            =  mclVectorSum(vec)

         ;  if (sum == 0.0)
            {  match->val =  1
         ;  }
            else
            {  match->val        =  w_center == 0.0
                                    ?  0.0
                                    :  (  w_center * mclVectorPowSum(vec, 2)
                                          +  w_selfval * selfval
                                       ) / sum
         ;  }
      ;  }

      ;  mclVectorNormalize(vec)
   ;  }
;  }


void localMatrixInflate_manager
(  
   mclMatrix*        mx
,  float             power
)  {
      mclVector*     vecPtr      =  mx->vectors
   ;  mclVector*     vecPtrMax   =  vecPtr + mx->N_cols
   ;  int            workLoad    =  mx->N_cols / mcl_num_ithreads
   ;  int            workTail    =  mx->N_cols % mcl_num_ithreads
   ;  int            i           =  0

   ;  pthread_attr_init(&pthread_custom_attr)

   ;  for (i=0;i<mcl_num_ithreads;i++)
      {
         localMatrixInflate_worker_arg *a
                     =  (localMatrixInflate_worker_arg *)
                        malloc(sizeof(localMatrixInflate_worker_arg))
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
         ,  (void *) localMatrixInflate_worker
         ,  (void *) a
         )
   ;  }

   ;  for (i = 0; i < mcl_num_ithreads; i++)
      pthread_join(threads_inflate[i], NULL)
;  }


void  localMatrixInflate_worker
( 
   void *arg
)
   {
      localMatrixInflate_worker_arg
                     *a          =  (localMatrixInflate_worker_arg *)  arg
   ;  mclMatrix*     mx          =  a->mx
                     
   ;  mclVector*     vecPtr      =  mx->vectors + a->start
   ;  mclVector*     vecPtrMax   =  mx->vectors + a->end
   ;  float          power       =  a->power

   ;  while (vecPtr < vecPtrMax)
      {
         mclVectorInflate(vecPtr, power)
      ;  vecPtr++
   ;  }

   ;  free(a)
;  }


int doIteration
(  mclMatrix**          mxin
,  mclMatrix**          mxout
,  const mclParam*      param
,  mclComposeStats*     stats
,  int                  type
,  int                  ite_index
)
   {  int               bPrint         =  param->printMatrix
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
         && mclMatrixNrofEntries(*mxin) < pow((*mxin)->N_cols, 1.5)
         )
      mclModeCompose = MCL_COMPOSE_SPARSE

   ;  *mxout =  mclFlowExpand(*mxin, stats )

   ;  if (ite_index > 0 && ite_index < 4)
      {  mclMarks[ite_index-1] = (int) (100.0*stats->mass_final_nx)
   ;  }

   ;  if (bPrint)
      {  sprintf
         (  msg, "%d%s%s%s"
         ,  2*ite_index, " After mclFlowExpand (", when, ")"
         )
      ;  if (mclVerbosityVectorProgress)
         fprintf(stdout, "\n")
      ;  mclFlowPrettyPrint(*mxout, stdout, digits, msg)
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
         mclMatrix*  clus  =  mclInterpret(*mxout, param->mclIpretParam)

      ;  if (mclVerbosityPruning)
         {  
            if (mclVerbosityStart && mclVerbosityExplain)
            {  mclComposeStatsHeader(vbfp)
            ;  mclVerbosityStart = 0
         ;  }
         ;  mclComposeStatsPrint(stats, vbfp)
      ;  }

      ;  if (mclDumpClusters)
         {  mcxDumpMatrix(clus, mclDumpStem, "cls", "", ite_index, 0)
      ;  }
      ;  mclMatrixFree(&clus)
   ;  }

      if (mcl_num_ithreads)
      localMatrixInflate_manager(*mxout, inflation)
   ;  else
      mclMatrixInflate(*mxout, inflation)

   ;  if (bPrint)
      {  sprintf
         (  msg,  "%d%s%s%s"
         ,  2*ite_index+1, " After inflation (", when, ")"
         )
      ;  if (mclVerbosityVectorProgress)
         fprintf(stdout, "\n")
      ;  mclFlowPrettyPrint(*mxout, stdout, digits, msg)
   ;  }

   ;  if (mclDumpIterands)
         mcxDumpMatrix(*mxout, mclDumpStem, "ite", "", ite_index, 1)

   ;  if (mclDumpAttractors)
      {  mclMatrix*  diago = mcxDiagOrdering(*mxout, &mcl_vec_attr)
      ;  mcxDumpVector(mcl_vec_attr, mclDumpStem, "attr", ".vec", ite_index, 1)
      ;  mclMatrixFree(&diago)
   ;  }

   ;  if (stats->inhomogeneity < mclInhomogeneityStop)
      return 1
   ;  else
      return 0
;  }


void  mcxDumpMatrix
(  mclMatrix*     mx
,  const char*    fstem
,  const char*    affix
,  const char*    postfix
,  int            n
,  int            printValue
)  {  mcxIOstream*   xfDump
   ;  char snum[18]
   ;  mcxTing*  fname

   ;  if (  (  mclDumpOfset
            && (n<mclDumpOfset)
            )
         || (  mclDumpBound
            && (n >= mclDumpBound)
            )
         )
         return

   ;  fname = mcxTingNew(fstem)
   ;  mcxTingAppend(fname, affix)

   ;  sprintf(snum, "%d", n)
   ;  mcxTingAppend(fname, snum)
   ;  mcxTingAppend(fname, postfix)

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
         mclMatrixWriteAscii(mx, xfDump, printValue ? 8 : -1, RETURN_ON_FAIL)
      ;  else
         mclMatrixWrite(mx, xfDump, RETURN_ON_FAIL)
   ;  }

   ;  mcxIOstreamFree(&xfDump)
   ;  mcxTingFree(&fname)
;  }


void  mcxDumpVector
(  mclVector*     vec
,  const char*    fstem
,  const char*    affix
,  const char*    postfix
,  int            n
,  int            printValue
)  {  mcxIOstream*   xf
   ;  char snum[18]
   ;  mcxTing*  fname

   ;  if (  (  mclDumpOfset
            && (n<mclDumpOfset)
            )
         || (  mclDumpBound
            && (n >= mclDumpBound)
            )
         )
         return

   ;  fname = mcxTingNew(fstem)
   ;  mcxTingAppend(fname, affix)

   ;  sprintf(snum, "%d", n)
   ;  mcxTingAppend(fname, snum)
   ;  mcxTingAppend(fname, postfix)

   ;  xf =  mcxIOstreamNew(fname->str, "w")
   ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) == STATUS_FAIL)
      {  mcxTingFree(&fname)
      ;  mcxIOstreamFree(&xf)
      ;  return
   ;  }

   ;  if (mclDumpMode == 'a')
      mclVectorWriteAscii(vec, xf->fp, printValue ? 8 : -1)
   ;  else
      mclVectorWrite(vec, xf, RETURN_ON_FAIL)

   ;  mcxIOstreamFree(&xf)
   ;  mcxTingFree(&fname)
;  }


