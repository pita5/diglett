//
//  DGProject.m
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGProject.h"

@implementation DGProject

- (id)initWithArgs:(NSDictionary *)args
{
    self = [super init];
    if (self) {
        // Initialization code here.
        directory = ...
        identifier = ...
        indexDBPath = ...
        [self open];
    }
    
    return self;
}

- (void)open {
    ... indexDBPath
}

- (void)watcherDidNotifyForDirectory:(NSString *)directoryPath {
    
}

- (void)suspend {
    
}
- (void)resume {
    
}
- (void)rescan {
    //Force diglett to rescan the project for changes.
    [scanner rescan];
}
- (void)reindex {
    //Force diglett to drop the tables for project_identifier, vacuum, and rescan it
    
    /*
    dispatch_async(db.queue, ^{
		if (!db.db)
			return;
        
		[db.db beginTransaction];
				
		[db.db executeUpdate:@"DROP TABLE foo"];
		[db.db executeUpdate:@"DROP TABLE bar"];
		[db.db executeUpdate:@"DROP TABLE baz"];
        
     
        [db buildTablesNoLock];
        
        [db.db commit];

        
        [scanner rescan];
    });
     */
}
- (void)discard {
    //Force diglett to drop the tables for project_identifier, vacuum, and close the project
    
}
- (void)close {
    //Suspend indexing and close the project.
    
    [controller removeProject:self];
    
    [self suspend];
    
    // TODO: We need to make sure nothing will attempt to change the DB after it has been closed.
    // Perhaps submit a barrier on the relevant concurrent queue (using dispatch_barrier_sync) in which we close everything
    
    [indexDB close];
    
}
- (void)forceIndexFile:(NSString *)filePath args:(NSDictionary *)args {
    // args = { path, project_identifier, unique_job_identifier, unique_job_timestamp, contents, language }
    
    NSString *contents = [args valueForKey:@"contents"];
    
    NSString *language = [args valueForKey:@"language"];
    
    
}
- (void)indexFileAtPath:(NSString *)path contents:(NSString *)contents language:(NSString *)language withIndexer:(NSString *)indexerName {
    
    DGIndexer *indexer = [self indexerForName:indexerName];
    
}




@end
