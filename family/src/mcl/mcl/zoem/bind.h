
/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_bind_h
#define zoem_bind_h


#include "util/txt.h"
#include "util/types.h"

/*
 * assumes a vararg is stored in key_and_args_g.
 * val contains what must be stored. If val contains a vararg,
 * it is interpreted as a set of key/value pairs. If not,
 * it is interpreted as a single value.
 *
 * THIS ROUTINE TAKES OWNERSHIP OF ITS ARGUMENT.
*/

void yamDataSet
(  mcxTing* val
)  ;


/*
 * assumes a vararg is stored in key_and_args_g.
*/

const char* yamDataGet
(  void
)  ;


/*
 * assumes a vararg is stored in key_and_args_g.
*/

mcxbool yamDataFree
(  void
)  ;


/*
*/

mcxbool yamDataPrint
(  void
)  ;

#endif


