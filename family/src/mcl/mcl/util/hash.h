/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_hash_h__
#define util_hash_h__


#include "types.h"
#include "link.h"
#include "alloc.h"

extern mcxbool mcxHashShowHashing;

/*
 *    One option currently, which does not have a decent setter routine.
 *    option disables dynamic growing.
*/

#define MCX_HASH_OPT_DEFAULTS     0
#define MCX_HASH_OPT_CONSTANT     1


typedef struct
{
   int         n_buckets               /* 2^n_bits                         */
;  mcxHLink     *buckets
;  int         mask                    /* == buckets-1                     */
;  int         n_bits                  /* length of mask                   */
;  float       load
;  int         n_entries
;  int         options
;  int         (*cmp) (const void *a, const void *b)
;  u32         (*hash) (const void *a)
;
}  mcxHash     ;


mcxHash* mcxHashNew
(  int         n_buckets
,  u32         (*hash)  (const void *a)
,  int         (*cmp)   (const void *a, const void *b)
)  ;



/*
 * mcxHashSearch
 *
 *    action               returns
 *
 *    DATUM_DELETE   ->    deleted mcxKV* or NULL if not present
 *    DATUM_INSERT   ->    new or present mcxKV*
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
 *    You may want to destroy one of the two keys and decide what to do
 *    with the value.
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
(  void*       key
,  mcxHash*    hash
,  mcxmode     ACTION
)  ;


/*
 * mcxHashFree
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
 *    For large hashes, mcxTing seems to be an expensive key if it comes
 *    freeing the hash. Will try to do an mcxTing memory pool and see
 *    whether that makes a significant difference.
 *
 *    Both freekey and freeval may be NULL.
*/

void mcxHashFree
(  mcxHash**   hashpp
,  void        freekey(void* keypp)    /* (yourtype1** keypp)     */
,  void        freeval(void* valpp)    /* (yourtype2** valpp)     */
)  ;


/*
 *    Prints some information to stdout.
*/

void mcxHashStats
(  mcxHash*    hash
)  ;


typedef struct
{
   mcxHash*    hash
;  int         bucket  /* bucket */
;  mcxHLink*    link
;
}  mcxHashWalk ;


mcxHashWalk* mcxHashWalkNew
(  mcxHash  *hash
)  ;


mcxKV* mcxHashWalkStep
(  mcxHashWalk* walk
)  ;


void mcxHashWalkFree
(  mcxHashWalk  **walkpp
)  ;


                        /* UNIX ELF hash */
                        /* POOR! */
u32 mcxELFhash
(  const void *key
,  u32 len
)  ;

                        /* created by Bob Jenkins     */
u32 mcxBJhash
(  const void* key
,  u32         len
)  ;

                        /* created by Daniel Phillips */
u32 mcxDPhash
(  const void* key
,  u32         len
)  ;

                        /* "Berkely Database" hash (from Ozan Yigit's page) */
                        /* POOR! */
u32 mcxBDBhash
(  const void *key
,  u32        len
)  ;

                        /* Dan Bernstein hash (from Ozan Yigit's page) */
u32 mcxDJBhash
(  const void *key
,  u32        len
)  ;

                        /* created by Chris Torek */
u32 mcxCThash
(  const void* key
,  u32         len
)  ;

                        /* All experimental. */
u32   mcxSvDhash
(  const void        *key
,  u32               len
)  ;
u32   mcxSvD2hash
(  const void        *key
,  u32               len
)  ;
u32   mcxSvD1hash
(  const void        *key
,  u32               len
)  ;

                        /* uses mcxDPhash             */
u32 mcxStrHash
(  const void* s
)  ;


#endif

