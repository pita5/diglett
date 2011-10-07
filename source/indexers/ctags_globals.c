#import "ctags_globals.h"
#import <stdio.h>
#import <string.h>

GlobalState GSDG;

void init_global_state(void) {
    memset(&GSDG, 0, sizeof(GlobalState));
}
void destroy_global_state(void) {
    memset(&GSDG, 0, sizeof(GlobalState));
}
