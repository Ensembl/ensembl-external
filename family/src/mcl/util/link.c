

#include "util/link.h"
#include "util/types.h"
#include "util/alloc.h"


void* mcxLinkInit
(  void          *link
)
   {
      if ( !link)
      link           =  (mcxLink*) rqAlloc(sizeof(mcxLink), EXIT_ON_FAIL)

   ;  ((mcxLink*) link)->ob       =  NULL
   ;  ((mcxLink*) link)->next     =  NULL
   ;  return(link)
;  }


int mcxLinkSize
(
   mcxLink*        link
)
   {
      int   s        =  0
   
   ;  while((link = link->next))
      s++

   ;  return(s)
;  }


void mcxLinkRelease
(  void            *link
)
   {
;  }


void mcxLinkFree
(  void            *linkpp
)
   {  rqFree(*((mcxLink**) linkpp))
   ;  *((mcxLink**)linkpp)  =     NULL
;  }


mcxLink* mcxLinkNew
(  mcxLink*          link
,  void*             ob
)  
   {
      if (!link)
      link           =  (mcxLink*) rqAlloc(sizeof(mcxLink), EXIT_ON_FAIL)
   ;  link->ob       =  ob
   ;  link->next     =  NULL
   ;  return   link
;  }



/*
 *    The first link is the handle to the list and will never be deleted.
 *    It's ob member is never inspected.
*/

mcxLink* mcxLinkSearch
(
   mcxLink*    link
,  void*       ob
,  int         (*cmp)(const void* a, const void *b)
,  mcxmode     ACTION
)
   {
      int      c           =  1
   ;  mcxLink* prev        =  link

   ;  link                 =  NULL  

   ;  while
      (  (link =  prev->next)
      &&  link->ob                              /* safety check */
      && (c    =  cmp(ob, link->ob)) > 0
      ) 
      prev     =  link
   ;

      if (!c)
      {
         if (ACTION == DATUM_FIND || ACTION == DATUM_INSERT)
         return link

      ;  else if (ACTION == DATUM_DELETE)
         {
            mcxLink* next  =  link->next
         ;  prev->next     =  next
         ;  return link
      ;  }
   ;  }

     /*
      *    End of list
     */
      else if (!link || c < 0)
      {
         if (ACTION == DATUM_FIND || ACTION == DATUM_DELETE)
         return NULL

      ;  else if (ACTION == DATUM_INSERT)
         {
            mcxLink* new   =  mcxLinkNew(NULL, ob)
         ;  prev->next     =  new
         ;  new->next      =  link
         ;  return   new
      ;  }
   ;  }

   ;  return NULL
;  }



