/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>

#include "iomagic.h"


int IoExpectMagicNumber
(  FILE*                f_in
,  int                  number_expected
)
   {  int               number_found   =  IoReadInteger(f_in)

   ;  if (number_found != number_expected)
      {  fseek(f_in, -sizeof(int), SEEK_CUR)
      ;  return 0
   ;  }
      else
      return 1
;  }


void IoWriteMagicNumber
(  FILE*                f_out
,  int                  number
)
   {  IoWriteInteger(f_out, number)
;  }


int IoReadInteger
(  FILE*                f_in
)
   {  int               val      =  0
   ;  fread(&val, sizeof(int), 1, f_in)
   ;  return val
;  }


int IoWriteInteger
(  FILE*                f_out
,  int                  val
)
   {  return fwrite(&val, sizeof(int), 1, f_out)
;  }



