//
//  DGScanner.h
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DGProject;
@class CHXMainDatabase;

@interface DGScanner : NSObject {
    DGProject *project;

	NSMutableDictionary *languages;
    
	BOOL indexHiddenFiles;
	BOOL indexPackages;
	
	BOOL isCountLimited;
	BOOL hasStopped;
	
	void (^indexingCompletionBlock)(CGFloat progress, BOOL hasFinished);
    
    dispatch_queue_t scanqueue;
}

@property (assign) BOOL indexHiddenFiles;
@property (assign) BOOL indexPackages;
@property (assign) BOOL isCountLimited;
@property (assign) BOOL hasStopped;
@property (copy) void (^indexingCompletionBlock)(CGFloat progress, BOOL hasFinished);

@property (assign) DGProject *project;

- (void)scanDirectory:(NSString *)dirpath database:(CHXMainDatabase *)database;

- (void)rescan;

- (void)pause;
- (void)clear;
- (void)resume;

- (void)doPass:(NSString *)filePath generator:(NSString *)generator language:(NSString *)language database:(CHXMainDatabase *)database resourceID:(int64_t)rid;
- (NSString *)detectLanguageForPath:(NSString *)p;
- (NSArray *)generatorsForLanguage:(NSString *)lang;
- (BOOL)checkStopped;

@end
