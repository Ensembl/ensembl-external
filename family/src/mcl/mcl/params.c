
#include <stdlib.h>
#include <stdio.h>
#include "mcl/params.h"
#include "util/types.h"

int      mcl_num_ethreads              =  0;
int      mcl_num_ithreads              =  0;

mcxbool  mclCloneMatrices              =  mcxFALSE;
int      mclCloneBarrier               =  20;

int      mclModePruning                =  MCL_PRUNING_RIGID;
int      mclModeCompose                =  MCL_COMPOSE_SPARSE;


int      mclDefaultMarknum             =  0;
int      mclMarknum                    =  0;
float    mclPrecision                  =  0.001;
float    mclPct                        =  0.95;
mcxbool  mclRecover                    =  mcxFALSE;
mcxbool  mclSelect                     =  mcxFALSE;


float    mclCutCof                     =  4.0;
float    mclCutExp                     =  4.0;

int      mcl_nx                        =  10;
int      mcl_ny                        =  100;

mcxbool  mclVerbosityPruning           =  mcxFALSE;
mcxbool  mclVerbosityMcl               =  mcxTRUE;
mcxbool  mclVerbosityVectorProgress    =  mcxTRUE;
mcxbool  mclVerbosityMatrixProgress    =  mcxFALSE;

int      mclVectorProgression          =  30;

mcxbool  mclDevel                      =  mcxFALSE;


mcxbool  mclDumpIterands               =  mcxFALSE;
mcxbool  mclDumpClusters               =  mcxFALSE;
mcxbool  mclDumpAttractors             =  mcxFALSE;
int      mclDumpMode                   =  'a';
int      mclDumpModulo                 =  1;
int      mclDumpOfset                  =  0;
int      mclDumpBound                  =  0;

float    mclInhomogeneityStop          =  0.0001;

const char*    mclDumpStem             =  "mcl";
mcxVector*     mcl_vec_attr            =  NULL;


