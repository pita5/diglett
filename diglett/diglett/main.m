//
//  main.m
//  diglett
//
//  Created by Alex Gordon on 28/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[])
{
    // Give ourselves less priority (higher nice value)
    // This will ensure we don't take over the computer
    int priority = getpriority(PRIO_PROCESS, getpid());
    priority += 5;
    if (priority > 20)
        priority = 20;
    setpriority(PRIO_PROCESS, getpid(), priority);
    
    DGController* controller = [[DGController alloc] init];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:controller selector:@selector(didReceiveNotification:) name:nil object:@"Diglett"];
    
    [[NSRunLoop currentRunLoop] run];
    return 0;
}
