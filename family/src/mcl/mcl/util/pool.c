/*
 *    Copyright (C) 2001-2002 Jan van der Steen.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TRUE  1
#define FALSE 0
#define BOOL int

#include "pool.h"

#define BLKSZ(mp)    (sizeof(MEM) + mp->mp_sz)


/***********************************************************************
* Function      : mp_check()
* Purpose       : Check validity of m
* Method        : Boundary checking
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : TRUE (valid) or FALSE (invalid).
*
*/
static BOOL
mp_check(MP *root, MEM *m)
{
    MP *p;

    for (p = root; p; p = p->mp_next) {
    if ((char *) m >= p->mp_mem &&
        (char *) m <  p->mp_mem +
         BLKSZ(root) * ((p == root) ? p->mp_n : p->mp_dn)) return TRUE;
    }
    return FALSE;
}


/***********************************************************************
* Function      : mp_new()
* Purpose       : Initialise a new memory pool of n elements
* Method        : malloc
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : MP handle
*
*/
static MP *
mp_new(MP *root, long n, long dn, long sz)
{
    MP *parent, *new;

    if (!sz || (new = malloc(sizeof(MP))) == NULL) return NULL;
    new->mp_n     = n;
    new->mp_dn    = dn;
    new->mp_sz    = sz;
    new->mp_mem   = NULL;
    new->mp_free  = NULL;
    new->mp_next  = NULL;
    new->mp_last  = NULL;
    new->mp_flags = MP_NONE;

    if (root && (parent = root->mp_last) != NULL) {
    new->mp_n += parent->mp_n;
    parent->mp_next = new;
    root->mp_last   = new;
    } else
    new->mp_last    = new;    /* Self */

    /*
     * sizeof(MEM) is our administration,
     * sz is the requested block
     */
    if ((new->mp_mem = calloc(n, sizeof(MEM)+sz)) == NULL) {
    free(new);
    return NULL;
    }
    return new;
}


/***********************************************************************
* Function      : mp_insert()
* Purpose       : Add n new free blocks to a memory pool
* Method        : Create a linked list of free blocks
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : Newly allocated block
*
* Notes         : The parameters:
*
*                    mp = Master pool
*                    mq = Pool containing new memory
*/
static MEM *
mp_insert(MP *mp, MP *mq, long n)
{
    char *p = mq->mp_mem;

    /*
     * Firstly, convert the n MEM blocks into a linked list
     */
    while (n-- > 0) {
       ((MEM *) p)->mem_next = (MEM *) (p + BLKSZ(mp));
       p += BLKSZ(mp);
    }

    /*
     * Set stopper at the tail of the list
     */
    ((MEM *)(p - BLKSZ(mp)))->mem_next = NULL;

    return (MEM *)(mq->mp_mem);
}


/***********************************************************************
* Function      : mp_init()
* Purpose       : Initialise a memory pool with n elements of sz bytes
*                 in size. When reallocation is necessary it will grow
*                 with dn elements.
* Method        : mp_new() for allocation and mp_insert() for the
*                 update of the administration
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : MP handle or NULL in case of failure.
*
*/
MP *
mp_init(long n, long dn, long sz, int flags)
{
    MP *mp;

    n   = (n  == 0) ? MP_N  : n;
    dn  = (dn == 0) ? MP_DN : dn;
    sz += (sz & 0x03) ? (4 - (sz & 0x03)) : 0;    /* 4 byte alignment */
    if (!sz || (mp = mp_new(NULL, n, dn, sz)) == NULL) return NULL;

    mp->mp_free  = mp_insert(mp, mp, mp->mp_n);
    mp->mp_flags = flags;

    return mp;
}


/***********************************************************************
* Function      : mp_stat()
* Purpose       : Return last allocated memory pool
* Method        : Straightforward
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : MP handle to memory pool
*
*/
MP *
mp_stat(MP *root)
{
    return (root) ? root->mp_last : NULL;
}


/***********************************************************************
* Function      : mp_alloc()
* Purpose       : Return next free block, realloc pool if necessary
* Method        : Return next free item from the free list.
*                 In case the free list is exhausted we mp_new() for
*                 allocation and mp_insert for the adminstration update.
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : Allocated item or NULL in case of failure.
*
*/
void *
mp_alloc(MP *mp)
{
    MEM *m;

    if (!mp) return NULL;

    if ((m = mp->mp_free) == NULL) {
       /*
        * Reallocation needed: mp->mp_dn extra elements
            * are added. In case mp_dn is zero we add what's
            * currently in the pool (exponential scheme).
        */
       MP *new = NULL;
           long dn = (mp->mp_dn) ? mp->mp_dn : mp->mp_last->mp_n;

       if ((new = mp_new(mp, dn, mp->mp_dn, mp->mp_sz)) == NULL) {
               return NULL;
           }
       m = mp->mp_free = mp_insert(mp, new, dn);

       if ((mp->mp_flags & MP_MSG) != 0) {
          fprintf(stderr, "MP: Allocation of %ld blocks\n", dn);
       }
    }
    mp->mp_free = mp->mp_free->mem_next;

    return (void *)(((char *) m) + sizeof(MEM));
}


/***********************************************************************
* Function      : mp_calloc
* Purpose       : An mp_alloc() and the clearance of the memory 
* Method        : mp_alloc() and memset()
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : Allocated item or NULL in case of failure
*
*/
void *
mp_calloc(MP *mp)
{
    void *p = mp_alloc(mp);

    if (p) memset(p, 0, mp->mp_sz);

    return p;
}


/***********************************************************************
* Function      : mp_free()
* Purpose       : Return an previously allocated item to the pool
* Method        : Insert the item in the free list.
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : Nothing
*
*/
void
mp_free(MP *mp, void *p)
{
    MEM *m;

    if (!mp || !p) return;

    m = (MEM *)((char *) p - sizeof(MEM));
    if ((mp->mp_flags & MP_CHK) == 0 || mp_check(mp, m)) {
    /*
     * Move this element to head of the list
     */
    m->mem_next = mp->mp_free;
    mp->mp_free = m;
    } else {
    /*
     * Freeing a non-member....
     */
    fprintf(stderr, "MP: *** Freeing a non-member ***\n");
    /* abort(); */
    }
}


/***********************************************************************
* Function      : mp_exit()
* Purpose       : Release the whole pool
* Method        : Recursion and free()
* History       :
*    2001-10-29 : jansteen : Creation
* Returns       : Nothing
*
*/
void
mp_exit(MP *mp)
{
    if (mp) {
    if (mp->mp_next) mp_exit(mp->mp_next);
    if (mp->mp_mem ) free(mp->mp_mem);
    free(mp);
    }
}


#if (0||SAMPLE_OF_USE)

#define HUGE_NUMBER 10

int
main(int argc, char *argv[])
{
    MP  * mp    = NULL;
    int   n     = 0;
    int * int_p[HUGE_NUMBER] = {NULL};

    if ((mp = mp_init(1, MP_EXPONENTIAL, sizeof(int), MP_MSG)) == NULL) {
        fprintf(stderr, "Cannot allocate buffer\n");
        exit(EXIT_FAILURE);
    }
    for (n = 0; n < HUGE_NUMBER; n++) {
        int_p[n] = mp_alloc(mp);
        *int_p[n] = n;
    }
    for (n = 0; n < HUGE_NUMBER; n++) {
        fprintf(stdout, "Freeing int_p[%d] = %d\n", n, *int_p[n]);
        mp_free(mp, int_p[n]);
    }
    mp_exit(mp);

    return EXIT_SUCCESS;
}

#undef TRUE
#undef FALSE
#endif /* SAMPLE_OF_USE */

