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
    
    BOOL isScanning;
}

@property (readonly) NSString *directory;
@property (readonly) NSString *identifier;

@property (readonly) NSString *indexDBPath;
@property (readonly) CHXMainDatabase *indexDB;

@property (readonly) DGScanner *scanner;

@property (readonly) dispatch_group_t indexingGroup;
@property (readonly) dispatch_source_t scannerSource;

@property (readonly) NSTimeInterval lastScanned;


- (id)initWithArgs:(NSDictionary *)args;

- (void)makeSource;
- (void)open;

- (BOOL)checkStopped;

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

- (void)indexFileAtPath:(NSString *)path contents:(NSString *)contents language:(NSString *)language withIndexer:(NSString *)indexerName rid:(int64_t)rid index:(int64_t)index total:(int64_t)total forced:(BOOL)wasForced;
@end
