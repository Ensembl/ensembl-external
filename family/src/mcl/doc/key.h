

#ifndef doc_key_h__
#define doc_key_h__

#include "util/txt.h"
#include "util/hash.h"


typedef struct yamSlice
{
   mcxTxt            *txt
;  int               linect      /* linecount corresponding with first char*/
;  int               offset      /* consider txt only from offset onwards  */
;  int               stack_size  /* cumulative size of previous expansions */
;  int               idx
;  struct yamSlice*  next
;
}  yamSlice ;


yamSlice*  yamSliceNew
(  mcxTxt   *txt
)  ;


typedef struct
{
   mcxHash*    tables[2]
;  int         n_tables
;
}  yamTables   ;


int   digest
(
   yamTables   *stack                           /* read/write symbols   */
,  mcxTxt      *txt                             /* interpret txt        */
,  int         filter(mcxTxt* txt, int offset, int bound)
)  ;



int   filter_html
(
   mcxTxt*     txt
,  int         offset
,  int         bound
)  ;


#endif


