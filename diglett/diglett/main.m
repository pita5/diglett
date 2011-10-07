//
//  main.m
//  diglett
//
//  Created by Alex Gordon on 28/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DGController.h"

int main(int argc, const char * argv[])
{
    // Give ourselves less priority (higher nice value)
    // This will ensure we don't take over the computer
    int priority = getpriority(PRIO_PROCESS, getpid());
    priority += 5;
    if (priority > 20)
        priority = 20;
    setpriority(PRIO_PROCESS, getpid(), priority);
    
    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, getppid(), DISPATCH_PROC_EXIT, dispatch_get_global_queue(0, 0));
    dispatch_source_set_event_handler(s, ^(void) {
        kill(getpid(), 9);
    });
    dispatch_resume(s);
    
    [NSRunLoop currentRunLoop];
    
    DGController* controller = [DGController sharedController];
    [controller observeNotifs];

    [[NSRunLoop currentRunLoop] run];
    return 0;
}
