/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef util_file_h__
#define util_file_h__

#include <stdio.h>

#include "txt.h"
#include "types.h"


#define MCX_READLINE_DEFAULT      0
#define MCX_READLINE_CHOMP        1
#define MCX_READLINE_SKIP_EMPTY   2
#define MCX_READLINE_PAR          4
#define MCX_READLINE_BS_CONTINUES 8


typedef struct
{  
   mcxTing*       fn
;  const char*    mode
;  FILE*          fp
;  int            lc                /*    line count     */
;  int            lo                /*    line offset    */
;  int            bc                /*    byte count     */
;  int            ateof
;  int            stdio
;  void*          ufo               /*    user fondled object */
;
}  mcxIOstream    ;


mcxIOstream* mcxIOstreamNew
(  const char*    str
,  const char*    mode
)  ;


void mcxIOstreamFree
(  mcxIOstream**  xf
)  ;


void mcxIOstreamRelease
(  mcxIOstream*   xf
)  ;


mcxstatus mcxIOstreamOpen
(  mcxIOstream*   xf
,  mcxOnFail      ON_FAIL
)  ;


void mcxIOstreamErr
(  mcxIOstream*   xf
,  const char     *complainer
,  const char     *complaint
,  const char     *type
)  ;



void mcxIOstreamClose
(  mcxIOstream*    xf
)  ;


mcxTing*  mcxIOstreamReadFile
(  mcxIOstream    *xf
,  mcxTing         *fileTxt
)  ;


mcxTing*  mcxIOstreamReadLine
(  mcxIOstream    *xf
,  mcxTing         *lineTxt
,  mcxflags       flags
)  ;


void mcxIOstreamOtherName
(  mcxIOstream*    xf
,  const char*    newname
)  ;


void mcxIOstreamStep
(  mcxIOstream*    xf
,  short           c
)  ;


void mcxIOstreamReport
(  mcxIOstream*   xf
,  FILE*          channel
)  ;


void mcxIOstreamRewind
(  mcxIOstream*   xf
)  ;

#endif

