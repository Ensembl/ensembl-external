

#ifndef TYPES_H__
#define TYPES_H__


typedef unsigned int    u32;
typedef unsigned char   u8;


typedef  int   mcxbool     ;
typedef  int   mcxstatus   ;
typedef  int   mcxflags    ;
typedef  int   mcxmode     ;
typedef  int   mcxOnFail   ;


#define  STATUS_OK   0
#define  STATUS_FAIL 1

#define  mcxFALSE    0
#define  mcxTRUE     1


enum
{
   RETURN_ON_FAIL       =  1444
,  EXIT_ON_FAIL
,  SLEEP_ON_FAIL
}  ;


enum
{
   DATUM_FIND            =  1969
,  DATUM_INSERT
,  DATUM_DELETE
}  ;


#endif

