

#include <math.h>

#include "util/hash.h"
#include "util/link.h"
#include "util/minmax.h"
#include "util/types.h"
#include "util/txt.h"


#define BJmix(a,b,c)             \
{                                \
  a -= b; a -= c; a ^= (c>>13);  \
  b -= c; b -= a; b ^= (a<< 8);  \
  c -= a; c -= b; c ^= (b>>13);  \
  a -= b; a -= c; a ^= (c>>12);  \
  b -= c; b -= a; b ^= (a<<16);  \
  c -= a; c -= b; c ^= (b>> 5);  \
  a -= b; a -= c; a ^= (c>> 3);  \
  b -= c; b -= a; b ^= (a<<10);  \
  c -= a; c -= b; c ^= (b>>15);  \
}


static   int   (*hcmp)(const void*a, const void *b)   ;



/*
 *    mcxHashSearch sets hcmp = usrcmp (hash->cmp)
 *    usrcmp acts on user objects.
 *    since links store KV struct, we must embed usrcmp in a cmp
 *    acting on KV's.
*/

static int mcxHashCmp
(
   const void* a
,  const void* b
)  ;

__inline__ int  mcxHashCmp
(  const void* a
,  const void* b
)
   {  return (hcmp(((mcxKV*) a)->key, ((mcxKV*) b)->key))
;  }


mcxKV* mcxKVnew
(
   void *key
,  void *val
)
   {
      mcxKV*   kv       =  (mcxKV*) rqAlloc(sizeof(mcxKV), EXIT_ON_FAIL)
   ;  kv->key           =  key
   ;  kv->val           =  val

   ;  return kv
;  }


void mcxKVdestroy
(
   mcxKV**  kvpp
)
   {
      rqFree(*kvpp)
   ;  *kvpp =  NULL
;  }


void mcxHashStats
(
   mcxHash*    hash
)
   {
      int      buckets  =  hash->n
   ;  int      buckets_used   =  0
   ;  float    ctr      =  0.0
   ;  float    cb       =  0.0
   ;  int      max      =  0
   ;  int      entries  =  0

   ;  mcxLink* link     =  (mcxLink*)  hash->links->ls
   ;  int      i        =  hash->n

   ;  while(i--)
      {
         int   j        =  mcxLinkSize(link)

      ;  if (j)
         {  
            buckets_used++
         ;  entries    +=  j
         ;  ctr        +=  (float) j * j
         ;  cb         +=  (float) j * j * j
         ;  max         =  int_MAX(max, j)
      ;  }

      ;  link++
   ;  }

   ;  ctr               =  ctr / int_MAX(1, entries)
   ;  cb                =  sqrt(cb  / int_MAX(1, entries))

   ;  fprintf
      (  stdout
   ,  "[mcxHashStats] %5.2f bucket usage (%d available, %d used, %d entries)\n"
      "[mcxHashStats] bucket avg: %.2f, ctr: %.2f, cb: %.2f, max: %d\n"
   ,  ((float) buckets_used) / buckets ,  buckets ,  buckets_used, entries
   ,  entries / ((float) buckets_used),  ctr , cb , max
      )
;  }


void mcxHashFree
(
   mcxHash**   hashpp
,  void        freekey(void* key)
,  void        freeval(void* key)
)
   {
      mcxHash* hash        =  *hashpp
   ;  mcxLink* link        =  (mcxLink*)  hash->links->ls
   ;  int i                =  hash->n


   ;  while(--i)
      {
         mcxLink* next     =  link->next
      ;  link->next        =  NULL

      ;  while(next)
         {
            mcxLink* this  =  next
         ;  mcxKV*   kv    =  (mcxKV*) this->ob

         ;  next           =  this->next

         ;  if (kv)
            {
               if (freekey)
               freekey(&(kv->key))
            ;  if (freeval)
               freeval(&(kv->val))
            ;  mcxKVdestroy(&kv)
         ;  }

         ;  mcxLinkFree(&this)
      ;  }

      ;  link++
   ;  }

   ;  mcxArrayFree(&(hash->links), mcxLinkRelease)
   ;  rqFree(hash)
   ;  *hashpp              =  NULL
;  }


mcxHash* mcxHashNew
(
   int         n
,  u32         (*hash) (const void *a)
,  int         (*cmp) (const void *a, const void *b)
)
   {
      mcxHash  *h       =  rqAlloc(sizeof(mcxHash), EXIT_ON_FAIL)
   ;  int      n_bits   =  0

   ;  h->mask           =  --n

   ;  while(n)
      {
         h->mask       |=  n       /* make h->n one less than a power of 2 */
      ;  n              =  n >> 1
      ;  n_bits++
   ;  }

   ;  h->n              =  h->mask + 1
   ;  h->cmp            =  cmp
   ;  h->hash           =  hash
   ;  h->shift          =  (32 - n_bits) / 2

   ;  h->links          =  mcxArrayInit
                           (NULL, h->n+1, sizeof(mcxLink), mcxLinkInit)
   ;  return h
;  }


mcxKV*   mcxHashSearch
(
   void*       key
,  mcxHash*    hash
,  mcxmode     ACTION
)
   {
      mcxLink *src, *res
   ;  mcxKV    *kv      =  mcxKVnew(key, NULL)
   ;  mcxKV    *reskv   =  NULL

   ;  u32      hashval  =  ((hash->hash)(key) >> hash->shift) & hash->mask
   ;  hcmp              =  hash->cmp      /* hcmp called by mcxHashCmp */

   ;  src               =  ((mcxLink*) (hash->links->ls))+hashval

   ;  if ((res = mcxLinkSearch(src, kv, mcxHashCmp, ACTION)))
      {
         reskv          =  (mcxKV*) res->ob

      ;  if
         (  ACTION == DATUM_DELETE
         || ACTION == DATUM_FIND
         || (ACTION == DATUM_INSERT && (reskv != kv))
         )
         mcxKVdestroy(&kv)

      ;  if
         (  ACTION == DATUM_DELETE
         && res
         )
         mcxLinkFree(&res)
   ;  }

   ;  return reskv
;  }



                        /* created by Bob Jenkins */
u32      mcxBJhash
(
   register const void*    key
,  register u32            len
)
   {
      register u32      a, b, c, l
   ;  char* k     =  (char *) key

   ;  l           =  len
   ;  a = b       =  0x9e3779b9
   ;  c           =  0xabcdef01

   ;  while (l >= 12)
      {
         a += k[0] + (k[1]<<8) + (k[2]<<16) + (k[3]<<24)
      ;  b += k[4] + (k[5]<<8) + (k[6]<<16) + (k[7]<<24)
      ;  c += k[8] + (k[9]<<8) + (k[10]<<16)+ (k[11]<<24)
      ;  BJmix(a,b,c)
      ;  k += 12
      ;  l -= 12
   ;  }

      c += len
   ;  switch(l)         /* all the case statements fall through */
      {
         case 11: c+= k[10]<<24
      ;  case 10: c+= k[9]<<16
      ;  case 9 : c+= k[8]<<8
                        /* the first byte of c is reserved for the length */
      ;  case 8 : b+= k[7]<<24
      ;  case 7 : b+= k[6]<<16
      ;  case 6 : b+= k[5]<<8
      ;  case 5 : b+= k[4]
      ;  case 4 : a+= k[3]<<24
      ;  case 3 : a+= k[2]<<16
      ;  case 2 : a+= k[1]<<8
      ;  case 1 : a+= k[0]
                        /* case 0: nothing left to add */
   ;  }

   ;  BJmix(a,b,c)
   ;  return c
;  }


                        /* created by Daniel Phillips */
u32   mcxDPhash
(
   const void        *key
,  u32               len
)
   {
      u32   h0    =  0x12a3fe2d
   ,        h1    =  0x37abe8f9
   ;  char* k     =  (char *) key

   ;  while (len--)
      {
         u32 h    =  h1 + (h0 ^ (*k++ * 71523))
      ;  h1       =  h0
      ;  h0       =  h
   ;  }
      return h0
;  }


u32      mcxStrHash
(
   const void* s
)
   {  
      int   l  =  strlen((char*) s)
   ;  return(mcxDPhash(s, l))
;  }


