/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef mcl_clm_h__
#define mcl_clm_h__

#include "nonema/matrix.h"
#include "intalg/ilist.h"
#include "util/types.h"

#define  ENSTRICT_KEEP_OVERLAP   1
#define  ENSTRICT_LEAVE_MISSING  2
#define  ENSTRICT_KEEP_EMPTY     4

#define  ENSTRICT_REPORT_ONLY    ENSTRICT_KEEP_OVERLAP\
                              |  ENSTRICT_LEAVE_MISSING\
                              |  ENSTRICT_KEEP_EMPTY

int  mclClusteringEnstrict
(  mclMatrix*  C1
,  int         *overlap
,  int         *missing
,  int         *empty
,  mcxflags    flags
)  ;


void mclClusteringSJD
(  mclMatrix*  cl
,  mclMatrix*  dl
,  int*        cddist
,  int*        dcdist
)  ;


Ilist*  mclClusteringGetAligner
(  mclMatrix*  C
)  ;


mclMatrix*  mclClusteringMeet
(  mclMatrix*  C1
,  mclMatrix*  C2
,  mcxstatus   ON_FAIL
)  ;


mclMatrix*  mclClusteringContingency
(  mclMatrix*  cl
,  mclMatrix*  dl
)  ;



#endif

