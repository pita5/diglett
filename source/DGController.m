//
//  DGController.m
//  diglett
//
//  Created by Alex Gordon on 29/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGController.h"
#import "DGProject.h"

// #define DIGLETT_DEBUG_MODE

@implementation DGController

+ (id)sharedController {
    static dispatch_once_t onceToken;
    static id sharedController;
    dispatch_once(&onceToken, ^{
        sharedController = [[DGController alloc] init];
    });
    return sharedController;
}

- (id)init
{
    self = [super init];
    if (self) {
        // A map from project identifier UUIDs to DGProject
        projectMap = [[NSMutableDictionary alloc] init];
        [self performSelector:@selector(registerForProcessQuit) withObject:nil afterDelay:0.0];
    }
    
    return self;
}
- (void)registerForProcessQuit {
    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, getppid(), DISPATCH_PROC_EXIT, dispatch_get_global_queue(0, 0));
    dispatch_source_set_event_handler(s, ^(void) {
        if ([NSTemporaryDirectory() length])
            [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"CHIndexTemps"] error:nil];
            
        kill(getpid(), 9);
    });
    dispatch_resume(s);
}
- (void)removeProject:(DGProject *)project {
    NSArray *keys = [projectMap allKeysForObject:project];
    if ([keys count])
        [projectMap removeObjectsForKeys:keys];
}

- (DGProject *)projectForMessageArgs:(NSDictionary *)args {
    // project_identifier
    NSString *projectIdentifier = [args valueForKey:@"project_identifier"];
    return [projectMap objectForKey:projectIdentifier];
}

#pragma mark Input Messages

- (void)didReceiveNotification:(NSNotification *)notif {
//    NSLog(@"RECEIVED NOTIFICATION DIGLETT:: %@", notif);
    NSString *name = [[notif userInfo] valueForKey:@"kind"];//[notif name];
    if ([name isEqual:@"CHDiglettProjectOpen"])
        [self project_open:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectSuspend"])
        [self project_suspend:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectResume"])
        [self project_resume:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectRescan"])
        [self project_rescan:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectReindex"])
        [self project_reindex:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectDiscard"])
        [self project_discard:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettProjectClose"])
        [self project_close:[notif userInfo]];
    else if ([name isEqual:@"CHDiglettFileIndex"])
        [self file_index:[notif userInfo]];

    [self reobserveNotifs];
}

- (void)observeNotifs {
    
    NSArray *notificationNames = [NSArray arrayWithObjects:@"CHDiglettProjectOpen", @"CHDiglettProjectSuspend", @"CHDiglettProjectResume", @"CHDiglettProjectRescan", @"CHDiglettProjectReindex", @"CHDiglettProjectDiscard", @"CHDiglettProjectClose", @"w", nil];
//    for (NSString *notifName in notificationNames) {
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(didReceiveNotification:)
                                                                name:@"CHDiglett"//notifName
#ifdef DIGLETT_DEBUG_MODE
    object:[NSString stringWithFormat:@"diglett-ld", getppid()]];
#else
    object:[NSString stringWithFormat:@"diglett-%ld", getppid()]];
#endif
    //    }
    //[[NSDistributedNotificationCenter defaultCenter] setSuspended:NO];
}
- (void)reobserveNotifs {
    
    //[[NSDistributedNotificationCenter defaultCenter] setSuspended:YES];
    
    //[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    
    //[self performSelector:@selector(observeNotifs) withObject:nil afterDelay:0.0];
}

- (void)project_open:(NSDictionary *)args { // { project_identifier }
    
    // Open a project with project_identifier
    
    // Is there a project for this already?
    if ([self projectForMessageArgs:args])
        return;
    
    if (![[args valueForKey:@"project_identifier"] length])
        return;
    
    if ([projectMap valueForKey:[args valueForKey:@"project_identifier"]])
        return;
    
    DGProject *project = [[DGProject alloc] initWithArgs:args];
    if (project)
        [projectMap setValue:project forKey:[args valueForKey:@"project_identifier"]];
}

- (void)project_suspend:(NSDictionary *)args { // { project_identifier }
    //Suspend any indexing behaviour
    
    [[self projectForMessageArgs:args] suspend];
}

- (void)project_resume:(NSDictionary *)args { // { project_identifier }
    //Resume any indexing behaviour
    
    [[self projectForMessageArgs:args] resume];
}

- (void)project_rescan:(NSDictionary *)args { // { project_identifier }
    //Force diglett to rescan the project for changes.
    
    [[self projectForMessageArgs:args] rescan];
}

- (void)project_reindex:(NSDictionary *)args { // { project_identifier }
    //Force diglett to drop the tables for project_identifier, vacuum, and rescan it
    
    [[self projectForMessageArgs:args] reindex];
}

- (void)project_discard:(NSDictionary *)args { // { project_identifer }
    //Force diglett to drop the tables for project_identifier, vacuum, and close the project
    
    [[self projectForMessageArgs:args] discard];
}

- (void)project_close:(NSDictionary *)args { // { project_identifier }
    //Suspend indexing and close the project.
    
    [[self projectForMessageArgs:args] close];
    [projectMap removeObjectForKey:[self projectForMessageArgs:args]];
}
- (void)file_index:(NSDictionary *)args { // { path, project_identifier, unique_job_identifier, unique_job_timestamp, contents, language }
    
    //Force diglett to index a file, ignoring its representation on disk, and instead taking a contents string
    DGProject *proj = [self projectForMessageArgs:args];
    if (!proj) {
        [self project_open:args];
        proj = [self projectForMessageArgs:args];
    }
    
//    NSLog(@"[self projectForMessageArgs:args] = %@", proj);
//    NSLog(@"proj = %@", proj);
//    NSLog(@"args = %@", args);
    [proj forceIndexFile:[args valueForKey:@"path"] args:args];
}

#pragma mark Messages from Diglett => Chocolat

- (void)didScanIndexFile:(NSString *)path project:(DGProject *)proj index:(NSInteger)index ofTotal:(NSInteger)total {
    
    // If this is not a final thing
    if (index != total && total != 0 && floor(((double)total) / 100) > 1) {
        if (((int)index % (int)floor(((double)total) / 100)) != 0) {
            return;
        }
    }
    
    NSMutableDictionary *messageUserInfo = [NSMutableDictionary dictionary];
    
    [messageUserInfo setValue:path ?: @"" forKey:@"path"];
    [messageUserInfo setValue:[NSNumber numberWithInteger:index] forKey:@"index"];
    [messageUserInfo setValue:[NSNumber numberWithInteger:total] forKey:@"total"];
    
    [self sendChocolatMessage:@"chocolat.file-did-index" project:proj dictionary:messageUserInfo];
}

- (void)send_file_did_index:(NSDictionary *)args { // { path, project_identifier, unique_job_identifier, unique_job_timestamp, language }
    //Sent after a file.index has finished. Prompts Chocolat to refresh the Navigator, etc.
}

- (void)send_project_is_indexing:(NSDictionary *)args { // 
    // Sent while the project is being indexed
}

- (void)sendChocolatMessage:(NSString *)msg project:(DGProject *)project dictionary:(NSDictionary *)dict {
    
    NSMutableDictionary *messageUserInfo = [NSMutableDictionary dictionary];
    
    if ([project identifier])
        [messageUserInfo setValue:[project identifier] forKey:@"project_identifier"];
    if ([project directory])
        [messageUserInfo setValue:[project directory] forKey:@"project_directory"];
    if ([project indexDBPath])
        [messageUserInfo setValue:[project indexDBPath] forKey:@"project_index_database"];
    
    [messageUserInfo addEntriesFromDictionary:dict];
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:msg object:[NSString stringWithFormat:@"chocolat-%ld", getppid()] userInfo:messageUserInfo];

}


@end
