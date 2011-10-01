//
//  DGScanner.h
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DGProject;

@interface DGScanner : NSObject {
    DGProject *project;
}

@property (assign) DGProject *project;

- (void)rescan;

@end
