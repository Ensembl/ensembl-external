/*
 *    Copyright (C) 1999-2002 Jan van der Steen.
*/

#ifndef mempool_h__
#define mempool_h__

/*
 * Values for mp_flags
 */
#define MP_NONE 0x00
#define MP_MSG  0x01
#define MP_CHK  0x02

/*
 * Grow exponentially by setting parameter dn to MP_EXPONENTIAL
 */
#define MP_EXPONENTIAL 0

/*
 * Default pool dimension
 */
#define MP_N    1000            /* Initial    # of blocks */
#define MP_DN   MP_EXPONENTIAL  /* Additional # of blocks */


typedef struct mem_info {
    struct mem_info *   mem_next;       /* Next free block              */
} MEM;

typedef struct mp_info {
    long                mp_n;           /* # allocated blocks           */
    long                mp_dn;          /* block increment              */
    long                mp_sz;          /* sizeof(block)                */
    char *              mp_mem;         /* mp_n * (sizeof(MEM)+mp_sz)   */
    MEM  *              mp_free;        /* 1st free block               */
    struct mp_info *    mp_next;        /* Next allocation              */
    struct mp_info *    mp_last;        /* Last allocation              */
    short               mp_flags;       /* Behaviour flags              */
} MP;

MP   *  mp_init         (long n, long dn, long sz, int flags);
void *  mp_alloc        (MP *mp);
void *  mp_calloc       (MP *mp);
void    mp_free         (MP *mp, void *p);
MP *    mp_stat         (MP *mp);
void    mp_exit         (MP *mp);

#endif
