
/*
 *    General purpose operations on clusterings.
 */

#ifndef CLM_H_
#define CLM_H_

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
(  mcxMatrix*  C1
,  int         *overlap
,  int         *missing
,  int         *empty
,  mcxflags    flags
)  ;


Ilist*  mclClusteringGetAligner
(  mcxMatrix*  C
)  ;


mcxMatrix*  mclClusteringMeet
(  mcxMatrix*  C1
,  mcxMatrix*  C2
,  mcxstatus   ON_FAIL
)  ;


mcxMatrix*  mclClusteringContingency
(  mcxMatrix*  cl
,  mcxMatrix*  dl
)  ;



#endif

