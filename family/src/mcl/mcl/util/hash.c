/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#include <math.h>
#include <stdio.h>

#include "hash.h"
#include "link.h"
#include "minmax.h"
#include "types.h"
#include "compile.h"
#include "pool.h"
#include "txt.h"

mcxbool mcxHashShowHashing = 0;

            /* the distribution of bit counts over all 32-bit keys */
int promilles[32] = 
{  0,  0,  0,  0,  0,  0,  0,  0
,  2,  7, 15, 30, 53, 81,110,131
,140,131,110, 81, 53, 30, 15,  7
,  2,  0,  0,  0,  0,  0,  0,  0
}  ;

mcxbool mcxHashDouble
(  mcxHash* hash
)  ;

int bitprint
(  u32   key
,  FILE* fp
)  ;

int bitcount
(  u32   key
)  ;

void mcxHashStats
(  mcxHash*    hash
)
   {  int      buckets  =  hash->n_buckets
   ;  int      buckets_used   =  0
   ;  float    ctr      =  0.0
   ;  float    cb       =  0.0
   ;  int      max      =  0
   ;  int      entries  =  0

   ;  int      j, k, distr[32]
   ;  mcxHLink* link

   ;  for (j=0;j<32;j++)
      distr[j] = 0

   ;  for (link = hash->buckets; link<hash->buckets + hash->n_buckets; link++)
      {
         int   i        =  mcxHLinkSize(link)
      ;  mcxHLink* this =  link->next

      ;  if (i)
         {  buckets_used++
         ;  entries    +=  i
         ;  ctr        +=  (float) i * i
         ;  cb         +=  (float) i * i * i
         ;  max         =  MAX(max, i)
      ;  }

      ;  while(this && this->kv)
         {  u32   h     =  (hash->hash)(this->kv->key)
         ;  int   ct    =  bitcount(h)
         ;  this        =  this->next
         ;  distr[ct]++
      ;  }
   ;  }

   ;  ctr               =  ctr / MAX(1, entries)
   ;  cb                =  sqrt(cb  / MAX(1, entries))

   ;  fprintf
      (  stderr
   ,  "[mcxHashStats] %4.2f bucket usage (%d available, %d used, %d entries)\n"
      "[mcxHashStats] bucket average: %.2f, center: %.2f, cube: %.2f, max: %d\n"
   ,  ((float) buckets_used) / buckets
   ,  buckets
   ,  buckets_used
   ,  entries
   ,  entries / ((float) buckets_used)
   ,  ctr
   ,  cb
   ,  max
      )

   ;  fprintf(stderr, "[mcxHashStats] bit distribution (promilles):\n")
   ;  fprintf
      (  stderr
      ,  "  %-37s   %s\n"
      ,  "Current bit distribution"
      ,  "Ideally random distribution"
      )
   ;  for (k=0;k<4;k++)
      {  for (j=k*8;j<(k+1)*8;j++)
         fprintf(stderr, "%3.0f ",  (1000 * (float)distr[j]) / entries)
      ;  fprintf(stderr, "        ");
      ;  for (j=k*8;j<(k+1)*8;j++)
         fprintf(stderr, "%3d ",  promilles[j])
      ;  fprintf(stderr, "\n")
   ;  }
   ;  fprintf(stderr, "[mcxHashStats] done\n")
;  }


void mcxHashFree
(  mcxHash**   hashpp
,  void        freekey(void* key)
,  void        freeval(void* key)
)
   {  mcxHash* hash        =  *hashpp
   ;  mcxHLink* link       =  hash->buckets
   ;  int i                =  hash->n_buckets

   ;  while(i--)
      {
         mcxHLink* next    =  link->next
      ;  link->next        =  NULL

      ;  while(next)
         {
            mcxHLink* this =  next
         ;  mcxKV*   kv    =  this->kv

         ;  next           =  this->next
         ;  if (kv)
            {
               if (freekey)
               freekey(&(kv->key))
            ;  if (freeval)
               freeval(&(kv->val))
            ;  mcxKVfree(&(this->kv))    /* todo; this->kv still dangling?! */
         ;  }

         ;  mcxHLinkFree(&this)
      ;  }

      ;  link++
   ;  }

   ;  mcxFree(hash->buckets)
   ;  mcxFree(hash)
   ;  *hashpp              =  NULL
;  }


mcxKV*   mcxHashSearch
(  void*       key
,  mcxHash*    hash
,  mcxmode     ACTION
)
   {  mcxKV    *fkv     =  NULL
   ;  u32      hashval  =  (hash->hash)(key) & hash->mask
   ;  mcxHLink *flink   =  mcxHLinkSearch
                           ((hash->buckets)+hashval, key, hash->cmp, ACTION)

   ;  if (flink)
      {
         fkv            =  flink->kv

      ;  if( ACTION == MCX_DATUM_DELETE && flink)
         {  mcxHLinkFree(&flink)
         ;  hash->n_entries--
      ;  }
         else if (ACTION == MCX_DATUM_INSERT && (fkv->key == key))
         {  hash->n_entries++
      ;  }
   ;  }

   ;  if
      (  hash->load * hash->n_buckets < hash->n_entries
      && !(hash->options & MCX_HASH_OPT_CONSTANT)
      )
      {  mcxHashDouble(hash)
      ;  return fkv
   ;  }

   ;  return fkv
;  }


mcxKV* mcxHashWalkStep
(  mcxHashWalk  *walk
)
   {  mcxHLink* step =  walk->link->next
   ;  int       b    =  walk->bucket

   ;  while ((!step || !step->kv) && b < walk->hash->n_buckets)
      {
         if (step && !step->kv)  /* signifies anchor of bucket */
         step = step->next
      ;  else if (!step && (++b < walk->hash->n_buckets))
         step = ((walk->hash->buckets)+b)->next
      ;  else
         break
   ;  }

   ;  if (step && step->kv)
      {  walk->link     =  step
      ;  walk->bucket   =  b
      ;  return step->kv
   ;  }

   ;  return NULL
;  }


mcxHashWalk* mcxHashWalkNew
(  mcxHash  *hash
)
   {  mcxHashWalk* walk    = (mcxHashWalk*)
                              mcxAlloc(sizeof(mcxHashWalk), EXIT_ON_FAIL)
   ;  walk->hash    =  hash

   ;  if (!hash || !hash->buckets)
      return NULL

   ;  walk->bucket  =  0
   ;  walk->link    =  (hash->buckets)+0
   ;  return walk
;  }


void mcxHashWalkFree
(  mcxHashWalk  **walkpp
)
   {  mcxFree(*walkpp)
   ;  *walkpp =  NULL
;  }


mcxHash* mcxHashNew
(  int         n_buckets
,  u32         (*hash)(const void *a)
,  int         (*cmp) (const void *a, const void *b)
)
   {  mcxHash  *h       =  mcxAlloc(sizeof(mcxHash), EXIT_ON_FAIL)
   ;  int      n_bits   =  0

   ;  h->mask           =  --n_buckets

   ;  while(n_buckets)
      {
         h->mask       |=  n_buckets
      ;  n_buckets    >>=  1
      ;  n_bits++
   ;  }

   ;  h->load           =  1.0
   ;  h->n_entries      =  0
   ;  h->n_bits         =  n_bits
   ;  h->n_buckets      =  (1 << n_bits)
   ;  h->cmp            =  cmp
   ;  h->hash           =  hash
   ;  h->options        =  MCX_HASH_OPT_DEFAULTS

   ;  h->buckets        =  (mcxHLink*) mcxNAlloc
                           (  h->n_buckets
                           ,  sizeof(mcxHLink)
                           ,  mcxHLinkInit
                           ,  EXIT_ON_FAIL
                           )
   ;  return h
;  }


mcxbool mcxHashDouble
(  mcxHash* h
)
   {  mcxHLink* olelink    =  h->buckets
   ;  mcxHLink* olebase    =  h->buckets
   ;  int i                =  h->n_buckets
   ;  int fail             =  0

   ;  h->n_buckets        *=  2
   ;  h->n_bits           +=  1
   ;  h->mask              =  (h->mask << 1) | 1

   ;  h->buckets           =  mcxNAlloc
                              (  h->n_buckets
                              ,  sizeof(mcxHLink)
                              ,  mcxHLinkInit
                              ,  EXIT_ON_FAIL
                              )
   ;  while(i--)
      {
         mcxHLink* next    =  olelink->next
      ;  olelink->next     =  NULL

      ;  while(next)
         {
            mcxHLink* this =  next
         ;  mcxKV*   kv    =  this->kv

         ;  next           =  this->next

         ;  if (kv)
            {
               u32   hval  =  (h->hash)(kv->key) & h->mask

            ;  if (mcxHLinkInsert(h->buckets+hval, this, h->cmp) != this)
               fail++
         ;  }
            else
            {  mcxHLinkFree(&this)
            ;  fail++
         ;  }
      ;  }

      ;  olelink++
   ;  }

   ;  if (fail)
      fprintf
      (  stderr
      ,  "___ [mcxHashDouble warning (internals)]\n"
         "______ [%d] reinsertion failures in hash with [%d] entries\n"
      ,  fail
      ,  h->n_entries
      )

   ;  mcxFree(olebase)
   ;  return TRUE
;  }


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


/*
 * Thomas Wang says Robert Jenkins says this is a good integer hash function:
 *unsigned int inthash(unsigned int key)
 *{
 *   key += (key << 12);
 *   key ^= (key >> 22);
 *   key += (key << 4);
 *   key ^= (key >> 9);
 *   key += (key << 10);
 *   key ^= (key >> 2);
 *   key += (key << 7);
 *   key ^= (key >> 12);
 *   return key;
 *}
*/

                        /* created by Bob Jenkins */
u32      mcxBJhash
(  register const void*    key
,  register u32            len
)
   {  register u32      a, b, c, l
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


                        /* created by Chris Torek */
u32   mcxCThash
(  const void *key
,  u32        len
)
#define ctHASH4a   h = (h << 5) - h + *k++;
#define ctHASH4b   h = (h << 5) + h + *k++;
#define ctHASH4 ctHASH4b

   {   u32 h               =  0
   ;   unsigned char *k    =  (unsigned char*) key

   ;   if (len > 0)
   ;   {
           unsigned loop = (len + 8 - 1) >> 3
       ;   switch (len & (8 - 1))
           {
               case 0:
                  do
                  {        /* All fall through */
                             ctHASH4
                     case 7: ctHASH4
                     case 6: ctHASH4
                     case 5: ctHASH4
                     case 4: ctHASH4
                     case 3: ctHASH4
                     case 2: ctHASH4
                     case 1: ctHASH4
                  }
                  while (--loop)
               ;
           }
       }
   ;  return h
;  }


/* All 3 hash fies below play on a similar theme.  Interesting: as long as only
 * << >> and ^ are used, a hash function does a partial homogeneous fill of all
 * 2^k different strings of length k built out of two distinct characters --
 * not all buckets need be used. E.g. for k=15, such a hash function might fill
 * 2^13 buckets with 4 entries each, or it might fill 2^10 buckets with 32
 * entries each.  This was observed, not proven.
*/

u32   mcxSvDhash
(  const void        *key
,  u32               len
)
   {  u32   h     =  0x7cabd53e /* 0x7cabd53e */
   ;  char* k     =  (char *) key

   ;  h           =  0x0180244a

   ;  while (len--)
      {  u32  g   =  *k
      ;  u32  gc  =  0xff ^ g
      ;  u32  hc  =  0xffffffff ^ h

      ;  h        =  (  (h << 2) +  h +  (h >> 3))
                  ^  ( (g << 25) + (gc << 18) + (g << 11) + (g << 5) + g )
      ;  k++
   ;  }

   ;  return h
;  }


                        /* created by me */
u32   mcxSvD2hash
(  const void        *key
,  u32               len
)
   {  u32   h     =  0x7cabd53e /* 0x7cabd53e */
   ;  char* k     =  (char *) key

   ;  while (len--)
      {  u32  g   =  *k
      ;  u32  gc  =  0xff ^ g

      ;  h        =  (  (h << 3) ^ h ^ (h >> 5) )
                  ^  ( (g << 25) ^ (gc << 18) ^ (g << 11) ^ (gc << 5) ^ g )
      ;  k++
   ;  }

   ;  return h
;  }


                        /* created by me */
u32   mcxSvD1hash
(  const void        *key
,  u32               len
)
   {  u32   h     =  0xeca96537
   ;  char* k     =  (char *) key

   ;  while (len--)
      {  u32  g   =  *k
      ;  h        =  (  (h << 3)  ^ h ^ (h >> 5) )
                  ^  ( (g << 21) ^  (g << 12)   ^ (g << 5) ^ g )
      ;  k++
   ;  }

   ;  return h
;  }


                        /* created by Daniel Phillips */
u32   mcxDPhash
(  const void        *key
,  u32               len
)
   {  u32   h0    =  0x12a3fe2d
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


                           /* Berkely Database hash */
u32 mcxBDBhash
(  const void *key
,  u32        len
)
   {  char* k     =  (char *) key
   ;  u32   hash  =  0

   ;  while (len--)
      {  hash = *k++ + (hash << 6) + (hash << 16) - hash
   ;  }
      return hash
;  }


                           /* by Dan Bernstein  */
u32 mcxDJBhash
(  const void *key
,  u32        len
)
   {  char* k     =  (char *) key
   ;  u32   hash  =  5381
   ;  while (len--)
      {  hash = *k++ + (hash << 5) + hash
   ;  }
      return hash
;  }


                           /* UNIX ELF hash */
u32 mcxELFhash
(  const void *key
,  u32        len
)
   {  char* k     =  (char *) key
   ;  u32   hash  =  0
   ;  u32   g

   ;  while (len--)
      {  hash = *k++ + (hash << 4)
      ;  if ((g = (hash & 0xF0000000)))
         hash ^= g >> 24

      ;  hash &= ~g
   ;  }
      return hash
;  }



u32 mcxStrHash
(  const void* s
)
   {  int   l  =  strlen((char*) s)
   ;  return(mcxDPhash(s, l))
;  }



int bitprint
(  u32   key
,  FILE* fp
)
   {  do
      {  fputc(key & 1 ? '1' : '0',  fp)
   ;  }  while
         ((key = key >> 1))
;  }


int bitcount
(  u32   key
)
   {  int ct = key & 1
   ;  while ((key = key >> 1))
      {  if (key & 1)
         ct++
   ;  }               
   ;  return ct
;  }


