//
//  DGProject.h
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHXMainDatabase.h"

@class DGScanner;

@interface DGProject : NSObject
{
    NSString *directory;
    NSString *identifier;
    
    NSString *indexDBPath;
    CHXMainDatabase *indexDB;
    
    DGScanner *scanner;
    
    dispatch_group_t indexingGroup;
    dispatch_source_t scannerSource;
    
    NSTimeInterval lastScanned;
}

- (id)initWithArgs:(NSDictionary *)args;

- (void)makeSource;
- (void)open;

- (void)didScanIndexFile:(NSString *)path index:(NSInteger)index ofTotal:(NSInteger)total;
- (void)watcherDidNotifyForDirectory:(NSString *)directoryPath;

- (void)suspend;
- (void)resume;
- (void)rescan;
- (void)reindex;
- (void)discard;
- (void)close;

- (NSArray *)indexerNames;
- (Class)indexerForName:(NSString *)indexerName;

- (void)forceIndexFile:(NSString *)filePath args:(NSDictionary *)args;
- (void)indexFileAtPath:(NSString *)path contents:(NSString *)contents language:(NSString *)language withIndexer:(NSString *)indexerName rid:(int64_t)rid;

@end
