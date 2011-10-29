#import <Foundation/Foundation.h>

#import "entry.h"
//#import "DGCtagsIndexerC.h"
void DGDestroyTagEntry(void *const copytag);

int ctags_main(int argc, const char **argv);
    
void DGEntryPrint(void* const entry);

#import "DGCtagsIndexer.h"

#import "CHTemporaryFile.h"
#import "DGProject.h"
#import "CHXMainDatabase.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#import "arena/arena.h"
#import "arena/proto.h"
#import "arena/queue.h"

#pragma mark Invocation


// Turn a C string into an NSString string
static NSString *DGNSString(const char *ustr) { return ustr ? [NSString stringWithUTF8String:ustr] : @""; }


// The queue that ctags pushes results into
static NSPointerArray* DGExCtag_TagEntryQueue;

void DGExCtag_PushTagEntry(void* const tag) 
{
    if (!DGExCtag_TagEntryQueue)
        DGExCtag_TagEntryQueue = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory];                                   
//    NSLog(@"PUSH BACK: %d", tag);
    [DGExCtag_TagEntryQueue addPointer:tag];
    //DGExCtag_TagEntryQueue.push_back(tag);
}


@interface DGCtagsIndexer ()

- (void)fillFrom:(NSPointerArray*)entries finishedBlock:(dispatch_block_t)finishedBlock;

@end

@implementation DGCtagsIndexer

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
- (NSString *)ctagsLanguage {
    return language;
}
- (void)index {
    
    // Get the language
    NSString *ctagsLanguage = [self ctagsLanguage];
    
    // Parse the file
    if (contents)
        [self parseFileContentsWithCtagsLanguage:ctagsLanguage];
    else
        [self parseFilePath:path withCtagsLanguage:ctagsLanguage finishedBlock:NULL];
    
//    [self fillFrom:tags];
}

- (void)parseFileContentsWithCtagsLanguage:(NSString *)ctagsLanguage
{
    // Put contents in a CHTemporaryFile
    CHTemporaryFile *tempfile = [[CHTemporaryFile alloc] initInDirectory:[NSTemporaryDirectory() stringByAppendingPathComponent:@"CHIndexTemps"]];
	
    BOOL worked = NO;
    if (tempfile)
    {
        NSError *err = nil;
        worked = [contents writeToFile:tempfile.path atomically:NO encoding:NSUTF8StringEncoding error:&err];
    }
    
    if (worked)
        [self parseFilePath:tempfile.path withCtagsLanguage:ctagsLanguage finishedBlock:^{
            
            completionBlock();
            
            [tempfile unlink];
        }];
    else
        dispatch_async(dispatch_get_main_queue(), completionBlock);
}

struct arena* ctags_arena;
const struct arena_prototype* ctags_arena_exported;

- (void)parseFilePath:(NSString *)inputPath withCtagsLanguage:(NSString *)ctagsLanguage finishedBlock:(dispatch_block_t)finishedBlock
{  
//    NSLog(@"PARSE: %@ %@ %d", inputPath, ctagsLanguage, finishedBlock);
    
    
    static dispatch_queue_t DGCtagsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DGCtagsQueue = dispatch_queue_create(NULL, NULL);
    });
    
    dispatch_group_async([project indexingGroup], DGCtagsQueue, ^{
        
        NSPointerArray* rv = nil;
       
        const char * args[] = {
            "ctags",
            "--extra=+fq",
            "--fields=+afmikKlnsStz",
            "--filter=no",
            [[NSString stringWithFormat:@"--%@-kinds=+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", ctagsLanguage] UTF8String],
            [[NSString stringWithFormat:@"--language-force=%@", [ctagsLanguage lowercaseString]] UTF8String],
            "--sort=no",
            // put --langdef directives here, once gnuregex is working
            // #include "exuberant-options.h"
            "-f /dev/null",
            [inputPath UTF8String],
            NULL
        };
        
        const struct arena_options aropt;
        const struct arena_prototype arprot;
        ctags_arena = arena_open(&arena_defaults, 0);
        ctags_arena_exported = arena_export(ctags_arena);
        
        int stdin = dup(0);  int stdout = dup(1);  int stderr = dup(2);
        int null = open("/dev/null", O_RDWR);
        dup2(null, 0);  dup2(null, 1);  dup2(null, 2);
        close(null); null = -1;
        
        // TODO: Put this into a dylib, then dlopen/dlclose on each iteration to clear globals
        ctags_main(sizeof(args) / sizeof(const char *) - 1, args);
        
        dup2(stdin, 0);  dup2(stdout, 1);  dup2(stderr, 2);
        close(stdin);  close(stdout);  close(stderr);
        
        rv = [DGExCtag_TagEntryQueue copy];
        [DGExCtag_TagEntryQueue setCount:0];
        
        [self fillFrom:rv finishedBlock:finishedBlock];
        
        arena_close(ctags_arena);
        ctags_arena = NULL;
    });
}

- (void)fillFrom:(NSPointerArray*)entries finishedBlock:(dispatch_block_t)finishedBlock {
    
    __block int64_t pass_id = -1;
	
    CHXMainDatabase *db = [project indexDB];
//    NSLog(@"Adding n entries: %d", [entries count]);
    
	dispatch_group_async([project indexingGroup], db.queue, ^{
		if (!db.db)
			return;
        
		[db.db beginTransaction];
		
		//[db.db executeUpdate:@"DELETE FROM symbols LEFT JOIN passes ON symbols.pass = passes.id WHERE passes.rid = ? AND passes.generator_type = 'index' AND passes.generator_name = 'ctags'", [NSNumber numberWithLongLong:rid]];		
		
        // Find a resource id
        if (rid == -1) {
            
            long idx = 0;
            if ([self.path length])
                idx = [db.db longForQuery:@"SELECT id FROM resources WHERE path = ?", self.path];
            
            if (idx <= 0) {
                [db.db executeUpdate:@"DELETE FROM resources WHERE path = ?", [[self path] lastPathComponent] ?: @""];
                
                [db.db executeUpdate:@"INSERT INTO resources (name, path, language, is_ignored) VALUES (?, ?, ?, ?)", [[self path] lastPathComponent] ?: @"", self.path ?: @"", language, [NSNumber numberWithBool:NO]];
                
                idx = [db.db lastInsertRowId];
            }
            
            if (idx > 0)
                rid = idx;
        }
        
        
		[db.db executeUpdate:@"DELETE FROM symbols WHERE pass in (SELECT id FROM passes WHERE resource = ? AND generator_type = 'index' AND generator_name = 'ctags')", [NSNumber numberWithLongLong:rid]];
		[db.db executeUpdate:@"DELETE FROM passes WHERE resource = ? AND generator_type = 'index' AND generator_name = 'ctags'", [NSNumber numberWithLongLong:rid]];
		[db.db executeUpdate:@"DELETE FROM symbols WHERE pass not in (SELECT id FROM passes)"];
		
		[db.db executeUpdate:@"INSERT INTO passes (resource, timestamp, generator_type, generator_name) "
         @" VALUES (?, ?, 'index', 'ctags')",
         [NSNumber numberWithLongLong:rid],
         [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]]
         
         ];
        
		pass_id = [db.db lastInsertRowId];
		//NSNumber *minusOne = [NSNumber numberWithInt:-1];
		
		NSInteger i = 0;
        NSInteger c = [entries count];
		for (i = 0; i < c; i++)
        {
			void* const tag = [entries pointerAtIndex:i];
            
            DGProcessTag(pass_id, db, tag);
		    DGDestroyTagEntry(tag);
        }
        
       // commitcount++;
		[db.db commit];
        
        if (finishedBlock)
            dispatch_async(dispatch_get_main_queue(), finishedBlock);
	});
}



@end



