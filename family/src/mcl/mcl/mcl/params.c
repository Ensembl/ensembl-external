/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <stdio.h>

#include "params.h"

#include "util/types.h"


int      mcl_num_ethreads              =  0;
int      mcl_num_ithreads              =  0;

mcxbool  mclCloneMatrices              =  FALSE;
int      mclCloneBarrier               =  20;

int      mclModePruning                =  MCL_PRUNING_RIGID;
int      mclModeCompose                =  MCL_COMPOSE_SPARSE;

float    mclPrecision                  =  0.000666;
float    mclPct                        =  0.95;

int      mclPruneNumber                =  1500;
int      mclSelectNumber               =  500;
int      mclRecoverNumber              =  600;

int      mclMarks[3]                   =  { 100, 100, 100 } ;

float    mclCutCof                     =  4.0;
float    mclCutExp                     =  4.0;

int      mcl_nx                        =  10;
int      mcl_ny                        =  100;

mcxbool  mclVerbosityPruning           =  FALSE;
mcxbool  mclVerbosityMcl               =  TRUE;
mcxbool  mclVerbosityExplain           =  FALSE;
mcxbool  mclVerbosityVectorProgress    =  TRUE;
mcxbool  mclVerbosityMatrixProgress    =  FALSE;

int      mclVectorProgression          =  30;

mcxbool  mclDevel                      =  FALSE;

mcxbool  mclInflateFirst               =  FALSE;


mcxbool  mclDumpIterands               =  FALSE;
mcxbool  mclDumpClusters               =  FALSE;
mcxbool  mclDumpAttractors             =  FALSE;
int      mclDumpMode                   =  'a';
int      mclDumpModulo                 =  1;
int      mclDumpOfset                  =  0;
int      mclDumpBound                  =  0;

float    mclInhomogeneityStop          =  0.0001;

int      mclWarnFactor                 =  50;
float    mclWarnPct                    =  0.3;

const char*    mclDumpStem             =  "mcl";
mclVector*     mcl_vec_attr            =  NULL;


