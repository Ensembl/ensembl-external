/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef types_h__
#define types_h__

#include "inttypes.h"


typedef int mcxflags ;
typedef int mcxmode  ;


typedef enum
{  STATUS_FAIL    =  0
,  STATUS_OK      =  1
}
   mcxstatus ;


#ifndef FALSE
   typedef enum
   {  FALSE          =  0
   ,  TRUE           =  1
   }  mcxbool ;
#else
   typedef int mcxbool ;
#endif


typedef enum
{  RETURN_ON_FAIL =  1960
,  EXIT_ON_FAIL
,  SLEEP_ON_FAIL
}
   mcxOnFail ;


#define  MCX_DATUM_THREADING  1
#define  MCX_DATUM_FIND       2
#define  MCX_DATUM_INSERT     4
#define  MCX_DATUM_DELETE     8


#endif

