
/*
 *    iface.h
 */

#ifndef MCL_IFACE_H
#define MCL_IFACE_H

#include "nonema/vector.h"

#define  MCL_PRUNING_RIGID   1
#define  MCL_PRUNING_ADAPT  2

#define  MCL_COMPOSE_DENSE  1
#define  MCL_COMPOSE_SPARSE 2


extern   int            mclModePruning;
extern   int            mclModeCompose;

extern   int            mcl_num_ethreads;
extern   int            mcl_num_ithreads;

extern   mcxbool        mclCloneMatrices;
extern   int            mclCloneBarrier;

extern   float          mclCutCof;
extern   float          mclCutExp;

extern   float          mclPct;
extern   float          mclPrecision;
extern   int            mclMarknum;
extern   int            mclDefaultMarknum;
extern   mcxbool        mclRecover;
extern   mcxbool        mclSelect;

extern   int            mcl_nx;
extern   int            mcl_ny;

extern   mcxbool        mclVerbosityPruning;
extern   mcxbool        mclVerbosityVectorProgress;
extern   mcxbool        mclVerbosityMatrixProgress;
extern   mcxbool        mclVerbosityMcl;

extern   int            mclVectorProgression;

extern   mcxbool        mclDevel;
                        

extern   mcxbool        mclDumpIterands;
extern   mcxbool        mclDumpAttractors;
extern   mcxbool        mclDumpClusters;
extern   int            mclDumpMode;
extern   int            mclDumpModulo;
extern   int            mclDumpOfset;
extern   int            mclDumpBound;
extern   const char*    mclDumpStem;

extern   float          mclInhomogeneityStop;

extern   mcxVector*     mcl_vec_attr;


#endif /* MCL_IFACE_H */

