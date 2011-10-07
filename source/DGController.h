//
//  DGController.h
//  diglett
//
//  Created by Alex Gordon on 29/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DGProject;

@interface DGController : NSObject
{
    NSMutableDictionary *projectMap;
}

+ (id)sharedController;
- (DGProject *)projectForMessageArgs:(NSDictionary *)args;
- (void)didReceiveNotification:(NSNotification *)notif;
- (void)removeProject:(DGProject *)project;


- (void)project_open:(NSDictionary *)args; // { project_identifier }
// Open a project with project_identifier

- (void)project_suspend:(NSDictionary *)args; // { project_identifier }
//Suspend any indexing behaviour

- (void)project_resume:(NSDictionary *)args; // { project_identifier }
//Resume any indexing behaviour

- (void)project_rescan:(NSDictionary *)args; // { project_identifier }
//Force diglett to rescan the project for changes.

- (void)project_reindex:(NSDictionary *)args; // { project_identifier }
//Force diglett to drop the tables for project_identifier, vacuum, and rescan it

- (void)project_discard:(NSDictionary *)args; // { project_identifer }
//Force diglett to drop the tables for project_identifier, vacuum, and close the project

- (void)project_close:(NSDictionary *)args; // { project_identifier }
//Suspend indexing and close the project.

- (void)file_index:(NSDictionary *)args; // { path, project_identifier, unique_job_identifier, unique_job_timestamp, contents, language }
//Force diglett to index a file, ignoring its representation on disk, and instead taking a contents string

#pragma mark Messages from Diglett => Chocolat

- (void)didScanIndexFile:(NSString *)path index:(NSInteger)index ofTotal:(NSInteger)total;

- (void)send_file_did_index:(NSDictionary *)args; // { path, project_identifier, unique_job_identifier, unique_job_timestamp, language }
//Sent after a file.index has finished. Prompts Chocolat to refresh the Navigator, etc.

- (void)send_project_is_indexing:(NSDictionary *)args; // 
// Sent while the project is being indexed

@end
