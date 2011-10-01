//
//  DGIndexer.m
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGIndexer.h"

@implementation DGIndexer

@synthesize project;
@synthesize path;
@synthesize contents;
@synthesize language;
@synthesize rid; // resource_id
@synthesize completionBlock;

- (void)index {
    
}

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

@end
