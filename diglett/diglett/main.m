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
    // The main thread listens for messages via stdin
    // Messages take the form:
    //   <message_name><space><argument_data_length><space><argument_plist_data>
    
    // Give ourselves a less priority (higher nice value)
    // This will ensure we don't take over the computer
    int priority = getpriority(PRIO_PROCESS, getpid());
    priority += 5;
    if (priority > 20)
        priority = 20;
    setpriority(PRIO_PROCESS, getpid(), priority);
    
    
    
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Do a runloop
    
    // Listen for messages
    
    // insert code here...
    NSLog(@"Hello, World!");

    [pool drain];
    
    
    return 0;
}
