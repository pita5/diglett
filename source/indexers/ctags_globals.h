#ifndef diglett_ctags_globals_h
#define diglett_ctags_globals_h

#import <stdio.h>
#ifndef SHOULD_NOT_IMPORT_READ
#import "read.h"
#endif

typedef struct {
    
    inputFile File;  /* globally read through macros */
    fpos_t StartOfLine;  /* holds deferred position of start of line */
    
} GlobalState;

extern GlobalState GSDG;

void init_global_state(void);
void destroy_global_state(void);

#endif
