//
//  DGController.m
//  diglett
//
//  Created by Alex Gordon on 29/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGController.h"

@implementation DGController

- (id)init
{
    self = [super init];
    if (self) {
        // A map from project identifier UUIDs to CHProjects
        projectMap = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (id)projectForArgs:(NSDictionary *)args {
    // project_identifier
    NSString *projectIdentifier = [args valueForKey:@"project_identifier"];
    return [projectMap objectForKey:projectIdentifier];
}

#pragma mark Input Messages

- (void)project_open:(NSDictionary *)args { // { project_identifier }
    
    // Open a project with project_identifier
    
    // Is there a project for this already?
    if ([self projectForArgs:args])
        return;
    
    CHProject *project = [[CHProject alloc] initWithArgs:args];
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
    
    [[self projectForMessageArgs:args] forceIndexFile:[args valueForKey:@"path"] args:args];
}

#pragma mark Messages from Diglett => Chocolat

- (void)send_file_did_index:(NSDictionary *)args { // { path, project_identifier, unique_job_identifier, unique_job_timestamp, language }
//Sent after a file.index has finished. Prompts Chocolat to refresh the Navigator, etc.
}

- (void)send_project_is_indexing:(NSDictionary *)args { // 
// Sent while the project is being indexed
}


@end
