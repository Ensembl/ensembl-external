
#include "util/txt.h"
#include "util/types.h"
#include <stdio.h>

#ifndef UTIL_FILE_H
#define UTIL_FILE_H


#define READLINE_DEFAULT      0
#define READLINE_CHOMP        1
#define READLINE_SKIP_EMPTY   2
#define READLINE_PAR          4
#define READLINE_BS_CONTINUES 8


typedef struct
{  
   mcxTxt*        fn
;  const char*    mode
;  FILE*          fp
;  int            lc
;  int            lo
;  int            bc
;  int            ateof
;  int            sys
;
}  mcxIOstream    ;


mcxIOstream* mcxIOstreamNew
(  
   const char*    str
,  const char*    mode
)  ;


void mcxIOstreamFree
(  
   mcxIOstream**  xf
)  ;


void mcxIOstreamRelease
(  
   mcxIOstream*   xf
)  ;


mcxstatus mcxIOstreamOpen
(  
   mcxIOstream*   xf
,  mcxOnFail      ON_FAIL
)  ;


void mcxIOstreamErr
(
   mcxIOstream*   xf
,  const char     *complainer
,  const char     *complaint
,  const char     *type
)  ;



void mcxIOstreamClose
(  
   mcxIOstream*    xf
)  ;


mcxTxt*  mcxIOstreamReadFile
(  
   mcxIOstream    *xf
,  mcxTxt         *fileTxt
)  ;


mcxTxt*  mcxIOstreamReadLine
(  
   mcxIOstream    *xf
,  mcxTxt         *lineTxt
,  mcxflags       flags
)  ;


void mcxIOstreamOtherName
(  
   mcxIOstream*    xf
,  const char*    newname
)  ;


void mcxIOstreamStep
(  
   mcxIOstream*    xf
,  short           c
)  ;


void mcxIOstreamReport
(  
   mcxIOstream*   xf
,  FILE*          channel
)  ;


void mcxIOstreamRewind
(  
   mcxIOstream*   xf
)  ;


extern __inline__ void     mcxIOstreamFree
(  
   mcxIOstream**  xf
)  
   {  if (*xf)
      {  mcxIOstreamRelease(*xf)
      ;  rqFree(*xf)
      ;  *xf   =  NULL
   ;  }
;  }

#endif

