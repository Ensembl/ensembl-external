/*
//                      Strings, sorting and searching
*/ 

#ifndef PRINT_H
#define PRINT_H        

#include <stdlib.h>  


/*                   
// "Something in the Linux version of string.h combined with GNU C
//  larger than 2.0 is not satisfactory."
//
*/
#ifdef __linux__     
extern int           memcmp(const void*, const void*, size_t);
#endif
#ifndef __unix__
#define strcasecmp   stricmp
#define strncasecmp  strnicmp
#endif

/*
*/

int print_int
(  char*                str
,  int                  k
)  ;

int print_float
(  char*                str
,  double               x
)  ;



#endif /* PRINT_H */
