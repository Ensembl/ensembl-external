/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef nonema_io_h__
#define nonema_io_h__

#include <math.h>
#include <stdio.h>

#include "vector.h"
#include "matrix.h"

#include "util/file.h"
#include "util/types.h"


#define mclMatrixMagicNumber  0x4D545833     /* MTX3 */
#define mclVectorMagicNumber  0x56454331     /* VEC1 */


mclMatrix* mclMatrixRead
(  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mclMatrixFilePeek
(  mcxIOstream*      xfIn
,  int               *N_cols
,  int               *N_rows
,  mcxOnFail         ON_FAIL
)  ;


mclMatrix* mclMatrixMaskedRead
(  mcxIOstream*      xfIn
,  const mclVector*  selector
,  mcxOnFail         ON_FAIL
)  ;


mclMatrix* mclMatrixReadAscii
(  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus  mclMatrixWrite
(  const mclMatrix*  mtx
,  mcxIOstream*      xfOut
,  mcxOnFail         ON_FAIL
)  ;


void mcxPrettyPrint
(  const mclMatrix*        mx
,  FILE*                   fp
,  int                     width
,  int                     digits
,  const char              msg[]
)  ;


void mclFlowPrettyPrint
(  const mclMatrix*  mx
,  FILE*             fp
,  int               digits
,  const char        msg[]
)  ;


mcxstatus mclMatrixTaggedWrite
(  const mclMatrix*        mx
,  const mclVector*        vecTags
,  mcxIOstream*            xfOut
,  int                     valdigits
,  mcxOnFail               ON_FAIL
)  ;


mcxstatus mclMatrixWriteAscii
(  const mclMatrix*  mx
,  mcxIOstream*      xfOut
,  int               valdigits
,  mcxOnFail         ON_FAIL
)  ;


void  mclMatrixList
(  mclMatrix*        mx
,  FILE*             fp
,  int               x_lo
,  int               y_lo
,  int               x_hi
,  int               y_hi
,  int               width
,  int               digits
,  const char*       msg
)  ;


void                 mclMatrixBoolPrint
(  mclMatrix*        mx
,  int               mode
)  ;


mclVector* mclVectorRead
(  mclVector*        prealloc_vec
,  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mclVectorEmbedRead
(  mclVector*        vec
,  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mclVector* mclVectorReadAscii
(  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mclVectorWrite
(  const mclVector*  vec
,  mcxIOstream*      xfOut
,  mcxOnFail         ON_FAIL
)  ;


mcxstatus mclVectorEmbedWrite
(  const mclVector*  vec
,  mcxIOstream*      xfOut
)  ;


void mclVectorWriteAscii
(  const mclVector*  vec
,  FILE*             fp
,  int               valdigits
)  ;


void mclVectorDumpAscii
(  const mclVector*  vec
,  FILE*             fp
,  int               vindex          /* identifies vector */
,  int               idxwidth
,  int               valdigits
,  int               doHeader
)  ;


void  mclVectorList
(  mclVector*     vec
,  FILE*          fp
,  int            lo_bound
,  int            hi_bound
,  int            width
,  int            digits
,  const char*    pre
,  const char*    msg
)  ;

#endif /* NONEMA_IO_H */

