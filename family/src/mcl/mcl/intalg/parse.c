/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include    <string.h>

#include    "parse.h"
#include    "ilist.h"

#include    "util/txt.h"
#include    "util/buf.h"
#include    "util/types.h"


char mcxIntalgRangeToken =  '-';


Ilist*   ilParseIntSet
(  const char*    string
,  mcxOnFail      ON_FAIL
)
   {  mcxBuf   ibuf
   ;  mcxTing   *itxt
   ;  char     *token
   ;  const char   *msg
   ;  int      left, right, i
   ;  int      *ip
   ;  Ilist    *il

   ;  il             =  ilInit(NULL)
   ;  mcxBufInit(&ibuf, &il->list, sizeof(int), 20)

   ;  itxt           =  mcxTingNew(string)

   ;  token          =  strtok(itxt->str, ",")

   ;  while(token)
      {
         int   tokenlen       =  strlen(token)

      ;  if (strchr(token, mcxIntalgRangeToken))
         {  
            mcxTing  *fmtTxt   =  mcxTingNew("%d.%d")
         ;  *(fmtTxt->str+2)  =  mcxIntalgRangeToken

         ;  if (sscanf(token, fmtTxt->str, &left, &right) == 2)
            {  for (i=left;i<=right;i++)
               {  ip          =  (int *)  mcxBufExtend(&ibuf, 1)
               ;  *ip         =  i
            ;  }
         ;  }
            else
            {  msg   =  "invalid range specification in string"
            ;  goto parseError
         ;  }
         ;  mcxTingFree(&fmtTxt)
      ;  }

         else if (tokenlen)
         {  
            int   n  =  0  
         ;  ip       =  (int *)  mcxBufExtend(&ibuf, 1)

         ;  if ((sscanf(token, "%d%n", ip, &n) != 1) || n != tokenlen)
            {  msg   =  "invalid int specification in string"
            ;  goto parseError
         ;  }
      ;  }

         else if (0)
         {  
            parseError:
            fprintf
            (  stderr
            ,  "[parseIntSet] %s [%s]\n"
            ,  msg
            ,  token
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return(NULL)
         ;  else
            exit(1)
      ;  }

         else
         {  msg   =  "empty string with comma-boundary not allowed"
         ;  goto parseError

        /*  we actually never reach this place because strtok
         *  skips the empty records for us. It has no consistent way of giving
         *  us a correct offset.
         */
      ;  }

      ;  token          =  strtok(NULL, ",")
   ;  }

   ;  mcxTingFree(&itxt)
   ;  il->n       =  mcxBufFinalize(&ibuf)

   ;  return(il)
;  }


