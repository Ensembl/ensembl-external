
#ifndef util_hash__
#define util_hash__

#include "util/array.h"
#include "util/types.h"
#include "util/alloc.h"


/*
 *    There is some documentation to be found further on.
*/


typedef struct
{  
   void*       key
;  void*       val
;
}  mcxKV    ;


mcxKV* mcxKVnew
(
   void *key
,  void *val
)  ;


void mcxKVdestroy
(  
   mcxKV**     kvpp
)  ;


typedef struct
{
   int         n                       /* yields 2^[ceil(2log(n))] buckets */
;  int         (*cmp) (const void *a, const void *b)
;  u32         (*hash) (const void *a)
;  int         shift                   /* defines the key-bits to use      */
;  int         mask                    /* keybits & mask define  bucket    */
;  mcxArray    *links                  /* contents is mcxLink*             */
;
}  mcxHash     ;


mcxHash* mcxHashNew
(
   int         n
,  u32         (*hash)  (const void *a)
,  int         (*cmp)   (const void *a, const void *b)
)  ;


/*
 *    Prints some information to stdout.
*/

void mcxHashStats
(
   mcxHash*    hash
)  ;


/*
 * mcxHashSearch:
 *
 *    action               returns
 *
 *    DATUM_DELETE   ->    deleted mcxKV* or NULL if not present
 *    DATUM_INSERT   ->    new or present(!!) mcxKV*
 *    DATUM_FIND     ->    mcxKV* if present NULL otherwise.
 * 
 * usage:
 *
 *    Values have to be inserted by the caller into the returned KV struct.
 *    Make sure that keys point to objects that are constant
 *    (with respect to the cmp function) during the lifetime of the hash.
 *    YOU have to ensure the integrity of both keys and values.
 *    This enables you to do whatever suits you, such as appending to
 *    values.
 *
 *    When inserting, check whether kv->key != key (where kv is returned value)
 *    if this is the case, an identically comparing key is already present.
 *    You may want to destroy one of the two keys.
 *
 *    When deleting, the key-value pair is removed from the hash
 *    *AND RETURNED TO CALLER* - you have to decide yourself what to do
 *    with it. If the key was not present, a value of NULL is returned.
 *
 *    When finding, life is simple. NULL if absent, matching kv otherwise.
 *
 * note:
 *
 *    memory management of keys and values is totally up to caller.
 *    If usage is clean, you can use mcxHashFree for disposal of hash.
*/

mcxKV*   mcxHashSearch
(
   void*       key
,  mcxHash*    hash
,  mcxmode     ACTION
)  ;


/*
 * usage:
 *
 *    This one is tricky, especially in the kind of free routines it
 *    expects. The free routines must cast the keypp and valpp
 *    to type (type**) which must correspond with the address of a variable.
 *    They will be applied as, for instance, keyfree(&(kv->key)).
 *    keyfree and valfree are expected to check whether their argument
 *    points to a NULL variable (this is nice for the caller who does
 *    not have to worry), and after freeing they are expected
 *    to set the pointee to NULL (this is not strictly necessary though).
 *
 *    It only works of course if all keys are of the same type and
 *    all values are of the same type, and if your  objects were
 *    created as expected by the free routines (presumably malloced
 *    heap memory) - be careful with constant objects like constant strings.
 *
 *    Both freekey and freeval may be NULL.
*/

void mcxHashFree
(
   mcxHash**   hashpp
,  void        freekey(void* keypp)    /* (yourtype1** keypp)     */
,  void        freeval(void* valpp)    /* (yourtype2** valpp)     */
)  ;


                        /* created by Bob Jenkins     */
u32      mcxBJhash
(
   const void* key
,  u32         len
)  ;

                        /* created by Daniel Phillips */
u32      mcxDPhash
(
   const void* key
,  u32         len
)  ;

                        /* uses mcxDPhash             */
u32      mcxStrHash
(
   const void* s
)  ;


#endif

