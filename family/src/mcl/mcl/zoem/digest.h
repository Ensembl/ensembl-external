/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_digest_h__
#define zoem_digest_h__

#include "filter.h"

#include "util/txt.h"


/*
 * yamOutput expands and filters. It can be given the arguments
 * yamFilterDefaultFilter() and yamFilterDefaultFd(), which must have
 * been set previously by yamFilterSetDefaults().
 *
 * An output file is fully described by its yamFilterData descriptor.
 * This descriptor is stored in the 'ufo' member of an mcxIOstream descriptor.
*/

void yamOutput
(
   mcxTing      *txtin
,  int          filter(yamFilterData* fd, mcxTing* txt, int offset, int length)
,  yamFilterData*   fd
)  ;


/*
 * yamDigest only expands and does not filter.  txtout can be the same as
 * txtin; in that case, txtin is overwritten with its expanded image.
 *
*/

mcxTing*  yamDigest
(
   mcxTing         *txtin
,  mcxTing         *txtout
)  ;

#endif

