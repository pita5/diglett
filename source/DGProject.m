//
//  DGProject.m
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGProject.h"

static const double delayBetweenSuccessful = 120;

@implementation DGProject

- (id)initWithArgs:(NSDictionary *)args
{
    self = [super init];
    if (self) {
        // Initialization code here.
        directory = [args valueForKey:@"project_directory"];
        identifier = [args valueForKey:@"project_identifier"];
        indexDBPath = [args valueForKey:@"project_index_database"];
        indexingGroup = dispatch_group_create();
        lastScanned = 0.0;
        
        [self scannerSource];
        [self open];
    }
    
    return self;
}

- (void)makeSource {
    scannerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(scannerSource, ^(void) {
        if ([NSDate timeIntervalSinceReferenceDate] - lastScanned > delayBetweenSuccessful) {
            
            // Set the last scanned date to something ridiculous, so we can't be invoked again until it finishes
            lastScanned = [NSDate dateWithTimeIntervalSinceReferenceDate:60 * 60 * 24 * 365 * 10];
            [scanner rescan];
        }
        
    });
    
    dispatch_source_set_timer(scannerSource, dispatch_time(DISPATCH_TIME_NOW, (delayBetweenSuccessful / 2.0) * NSEC_PER_SEC), 0, 10);
}
- (void)open {
    indexDB = [[CHXMainDatabase alloc] initWithPath:indexDBPath];
}

- (void)didScanIndexFile:(NSString *)path index:(NSInteger)index ofTotal:(NSInteger)total {
    
    // We don't know the index of the final file, so
    // index == total is sent at the end when all files have been either indexed or ignored
    if (index == total) {
        lastScanned = [NSDate timeIntervalSinceReferenceDate];
    }
    
    [[DGController sharedController] didScanIndexFile:path index:index ofTotal:total];
}

- (void)watcherDidNotifyForDirectory:(NSString *)directoryPath {
    
}

- (void)suspend {
    // Suspend the scanner source
    dispatch_source_cancel(scannerSource);
    dispatch_release(scannerSource);
    scannerSource = NULL;
}
- (void)resume {
    if (!scannerSource) {
        [self makeSource];
    }
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
        
    [self suspend];
    
     // We need to make sure nothing will attempt to change the DB after it has been closed.
    dispatch_group_notify(indexingGroup, dispatch_get_main_queue(), ^(void) {
        
        [indexDB close];
        
        [controller removeProject:self];
    })
    
    
}

- (NSArray *)indexerNames {
    return [NSArray arrayWithObjects:@"ctags", nil];
}
- (Class)indexerForName:(NSString *)indexerName {
    if ([indexerName isEqual:@"ctags"])
        return [DGCTagsIndexer class];
}

- (void)forceIndexFile:(NSString *)filePath args:(NSDictionary *)args {
    // args = { path, project_identifier, unique_job_identifier, unique_job_timestamp, contents, language }
    
    NSString *contents = [args valueForKey:@"contents"];
    
    NSString *language = [args valueForKey:@"language"];
    
    for (NSString *indexerName in [self indexerNames])
        [self indexFileAtPath:filePath contents:contents langauge:language withIndexer:indexerName rid:-1];
}
- (void)indexFileAtPath:(NSString *)path contents:(NSString *)contents language:(NSString *)language withIndexer:(NSString *)indexerName rid:(int64_t)rid {
    
    DGIndexer *indexer = [[[self indexerForName:indexerName] alloc] init];
    indexer.project = self;
    indexer.path = path;
    indexer.contents = contents;
    indexer.language = langauge;;
    indexer.rid = rid;
    indexer.completionBlock = ^{
        ...
    };
    
    [indexer index];
}




@end
