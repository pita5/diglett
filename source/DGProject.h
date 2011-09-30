//
//  DGProject.h
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DGProject : NSObject
{
    NSString *directory;
    NSString *identifier;
    
    NSString *indexDBPath;
    CHIndexDatabase *indexDB;
    
    NSOperationQueue
    
    dispatch_group_t workGroup;
}

@end
