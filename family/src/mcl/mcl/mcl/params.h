/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcl_params_h__
#define mcl_params_h__

#include "nonema/vector.h"


#define  MCL_PRUNING_RIGID   1
#define  MCL_PRUNING_ADAPT  2

#define  MCL_COMPOSE_DENSE  1
#define  MCL_COMPOSE_SPARSE 2




/* inflation related options */

extern   int            mcl_num_ithreads;


/* expand, c.q. pruning related handles */

extern   int            mcl_num_ethreads;

extern   mcxbool        mclCloneMatrices;
extern   int            mclCloneBarrier;

extern   int            mclModePruning;
extern   int            mclModeCompose;

extern   float          mclPct;
extern   float          mclPrecision;

extern   int            mclPruneNumber;
extern   int            mclSelectNumber;
extern   int            mclRecoverNumber;

extern   float          mclCutCof;
extern   float          mclCutExp;

extern   int            mcl_nx;
extern   int            mcl_ny;

extern   mcxbool        mclVerbosityVectorProgress;
extern   mcxbool        mclVerbosityPruning;
extern   mcxbool        mclVerbosityExplain;

extern   int            mclVectorProgression;

extern   int            mclWarnFactor;
extern   float          mclWarnPct;


/* cluster related handles */

extern   mcxbool        mclVerbosityMatrixProgress;

extern   mcxbool        mclInflateFirst;

extern   float          mclInhomogeneityStop;

extern   mclVector*     mcl_vec_attr;

extern   mcxbool        mclDumpIterands;
extern   mcxbool        mclDumpAttractors;
extern   mcxbool        mclDumpClusters;
extern   int            mclDumpMode;
extern   int            mclDumpModulo;
extern   int            mclDumpOfset;
extern   int            mclDumpBound;
extern   const char*    mclDumpStem;


/* miscellaneous handles */

extern   mcxbool        mclVerbosityMcl;

extern   mcxbool        mclDevel;
                        

/* handles for passing information from mclCluster to caller */

extern   int            mclMarks[3];


#endif

