
#ifndef NONEMA_IO_H
#define NONEMA_IO_H

#include <stdio.h>
#include "vector.h"
#include "matrix.h"
#include "math.h"
#include "util/file.h"
#include "util/array.h"
#include "util/types.h"

/*
 *
*/

#define MatrixMagicNumber  0x4D545833     /* MTX3 */


int mcxParseHeaderLines
(  
   mcxIOstream      *xfIn
,  mcxTable         *txtTable
)  ;


mcxMatrix* mcxMatrixRead
(  
   mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


int mcxMatrixFilePeek
(  
   mcxIOstream*      xfIn
,  int               *N_cols
,  int               *N_rows
,  mcxOnFail         ON_FAIL
)  ;


mcxMatrix* mcxMatrixMaskedRead
(  
   mcxIOstream*      xfIn
,  const mcxVector*  selector
,  mcxOnFail         ON_FAIL
)  ;


EXTERN__INLINE__ mcxMatrix* mcxMatrixRead
(  
   mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  
   {  
      return mcxMatrixMaskedRead(xfIn, NULL, ON_FAIL)
;  }


mcxMatrix* mcxMatrixReadAscii
(  
   mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;

mcxstatus  mcxMatrixWrite
(  
   const mcxMatrix*  mtx
,  mcxIOstream*      xfOut
,  mcxOnFail         ON_FAIL
)  ;


void mcxFlowPrettyPrint
(  
   const mcxMatrix*  mx
,  FILE*             fp
,  int               digits
,  const char        msg[]
)  ;


mcxstatus mcxMatrixTaggedWrite
( 
   const mcxMatrix*        mx
,  const mcxVector*        vecTags
,  mcxIOstream*            xfOut
,  int                     valdigits
,  mcxOnFail               ON_FAIL
)  ;


mcxstatus mcxMatrixWriteAscii
(  
   const mcxMatrix*  mx
,  mcxIOstream*      xfOut
,  int               valdigits
,  mcxOnFail         ON_FAIL
)  ;


void  mcxMatrixList
(  
   mcxMatrix*        mx
,  FILE*             fp
,  int               x_lo
,  int               y_lo
,  int               x_hi
,  int               y_hi
,  int               width
,  int               digits
,  const char*       msg
)  ;


void                 mcxMatrixBoolPrint
(  
   mcxMatrix*        mx
,  int               mode
)  ;

/*
 *
*/

#define mcxVectorMagicNumber  0x56454331     /* VEC1 */


mcxVector* mcxVectorRead
(  
   mcxVector*        prealloc_vec
,  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


int mcxVectorEmbedRead
(  
   mcxVector*        vec
,  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxVector* mcxVectorReadAscii
(  
   mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mcxVectorWrite
(  
   const mcxVector*  vec
,  mcxIOstream*      xfOut
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mcxVectorEmbedWrite
(  
   const mcxVector*  vec
,  mcxIOstream*      xfOut
)  ;


void mcxVectorWriteAscii
(  
   const mcxVector*  vec
,  FILE*             fp
,  int               valdigits
)  ;


void mcxVectorDumpAscii
(  
   const mcxVector*  vec
,  FILE*             fp
,  int               vindex          /* identifies vector */
,  int               idxwidth
,  int               valdigits
,  int               doHeader
)  ;


EXTERN__INLINE__ void mcxVectorWriteAscii
(  const mcxVector*  vec
,  FILE*             fp
,  int               valdigits
)  
   {  
      mcxVectorDumpAscii
      (  vec
      ,  fp
      ,  -1
      ,  1
      ,  valdigits
      ,  1
      )
;  }


void  mcxVectorList
(  
   mcxVector*     vec
,  FILE*          fp
,  int            lo_bound
,  int            hi_bound
,  int            width
,  int            digits
,  const char*    pre
,  const char*    msg
)  ;

#endif /* NONEMA_IO_H */

