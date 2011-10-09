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
    // Give ourselves a lower priority (higher nice value)
    setpriority(PRIO_PROCESS, getpid(), 19);
    
    [NSRunLoop currentRunLoop];
    
    DGController* controller = [DGController sharedController];
    [controller observeNotifs];

    [[NSRunLoop currentRunLoop] run];
    return 0;
}
