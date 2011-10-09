#ifndef diglett_ctags_globals_h
#define diglett_ctags_globals_h

#import <stdio.h>
#ifndef SHOULD_NOT_IMPORT_READ
#import "read.h"
#endif
#ifndef SHOULD_NOT_IMPORT_ENTRY
#import "entry.h"
#endif

typedef struct {
    
    inputFile File;  /* globally read through macros */
    fpos_t StartOfLine;  /* holds deferred position of start of line */
    
    tagFile TagFile;
    
} GlobalState;

extern GlobalState GSDG;

void init_global_state(void);
void destroy_global_state(void);

#endif
