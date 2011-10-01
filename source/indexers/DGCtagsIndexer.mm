#import "DGCtagsIndexer.h"

#import <deque>
#import <cstdlib>


#pragma mark Invocation

extern "C" {
    #import "entry.h"
    
    void DGExCtag_PushTagEntry(tagEntryInfo* tag);
    tagEntryInfo* DGExCtag_PopTagEntry();
    void DGDestroyTagEntry(const tagEntryInfo *const copytag);
}

// Ctags's main function
extern int ctags_main(int argc, char **argv);

// The queue that ctags pushes results into
std::deque<tagEntryInfo*> DGExCtag_TagEntryQueue;

// Turn a C string into an NSString string
static NSString *DGNSString(const char *ustr) { return ustr ? [NSString stringWithUTF8String:ustr] : @""; }

typedef std::vector<tagEntryInfo*> tag_vector;

void DGEntryPrint(tagEntryInfo entry);


@interface DGCtagsIndexer ()

- (tag_vector)parseFileContentsWithCtagsLanguage:(NSString *)ctagsLanguage;
- (tag_vector)parseFilePath:(NSString *)inputPath withCtagsLanguage:(NSString *)ctagsLanguage;
- (void)fillFrom:(tag_vector)entries;

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

- (void)index {
    
    // Get the language
    NSString *ctagsLanguage = [self ctagsLanguage];
    
    // Parse the file
    tag_vector tags =
        contents ? [self parseFileContentsCtagsLanguage:ctagsLanguage]
                : [self parseFilePath:path withCtagsLanguage:ctagsLanguage finishedBlock:NULL];
    
//    [self fillFrom:tags];
}

- (void)parseFileContentsWithCtagsLanguage:(NSString *)ctagsLanguage
{
    // Put contents in a CHTemporaryFile
    CHTemporaryFile *tempfile = [[CHTemporaryFile alloc] init];
	
    if (tempfile)
    {
        NSError *err = nil;
        BOOL worked = [contents writeToFile:tempfile.path atomically:NO encoding:NSUTF8StringEncoding error:&err];
        if (!worked)
            return;
        
        path = tempfile.path;
    }
    
    return [self parseFilePath:temppath ctagsLanguage:ctagsLanguage finishedBlock:^{
        [tempfile unlink];
    }];
}
- (void)parseFilePath:(NSString *)inputPath withCtagsLanguage:(NSString *)ctagsLanguage finishedBlock:(dispatch_block_t)finishedBlock
{    
    extern dispatch_queue_t DGCtagsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DGCtagsQueue = dispatch_queue_create(NULL, NULL);
    });
    
    dispatch_group_async([project indexingGroup], DGCtagsQueue, ^{

        tag_vector rv;
       
        const char * args[] = {
            "ctags",
            "--extra=+fq",
            "--fields=+afmikKlnsStz",
            "--filter=no",
            [[NSString stringWithFormat:@"--%@-kinds=+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", ctagsLanguage] UTF8String],
            [[NSString stringWithFormat:@"--language-force=%@", ctagsLanguage] UTF8String],
            "--sort=no",
            "-L", [inputPath UTF8String],
            NULL
            // put --langdef directives here, once gnuregex is working
            // #include "exuberant-options.h"
        };
        
        ctags_main(sizeof(args) / sizeof(const char *), args);
        
        std::copy(DGExCtag_TagEntryQueue.end(), DGExCtag_TagEntryQueue.end(), rv.begin());
        DGExCtag_TagEntryQueue.clear();
        
        [self fillFrom:rv];
    });
    
    return rv;
}

- (void)fillFrom:(tag_vector)entries {
    
    __block int64_t pass_id = -1;
	
	dispatch_group_async([project indexingGroup], db.queue, ^{
		if (!db.db)
			return;
        
		[db.db beginTransaction];
		
		//[db.db executeUpdate:@"DELETE FROM symbols LEFT JOIN passes ON symbols.pass = passes.id WHERE passes.rid = ? AND passes.generator_type = 'index' AND passes.generator_name = 'ctags'", [NSNumber numberWithLongLong:rid]];		
		
		[db.db executeUpdate:@"DELETE FROM passes WHERE resource = ? AND generator_type = 'index' AND generator_name = 'ctags'", [NSNumber numberWithLongLong:rid]];
		
		[db.db executeUpdate:@"INSERT INTO passes (resource, timestamp, generator_type, generator_name) "
         @" VALUES (?, ?, 'index', 'ctags')",
         [NSNumber numberWithLongLong:rid],
         [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]]
         
         ];
        
		pass_id = [db.db lastInsertRowId];
		NSNumber *minusOne = [NSNumber numberWithInt:-1];
		
		for (tag_vector::iterator it = entries.begin(), et = entries.end(); it != et; ++it)
		{
			tagEntryInfo tag = **it;
            
            DGEntryPrint(entry);
            
			int64_t lineNumber = ((int64_t)(tag.lineNumber)) - 1;
            if (lineNumber < 0)
                continue;
            
			NSString *tQualifiedName = DGNSString(entry.name);
			NSString *tPattern = DGNSString(NULL); // ??
			NSString *tKind = DGNSString(entry.kindName);
			if ([tKind isEqual:@"file"])
				continue;
			
			short fileScope = entry.isFileScope;
            
			if ([tPattern length] >= 3 && entry.address.pattern && (entry.address.pattern[0] == '/' || entry.address.pattern[0] == '?'))
				tPattern = [tPattern substringWithRange:NSMakeRange(1, [tPattern length] - 2)];
			else
				tPattern = @"";
			
			NSString *tName = [[tQualifiedName componentsSeparatedByString:@"::"] lastObject];
            
            insertcount++;
			[db.db executeUpdate:@"INSERT INTO symbols (pass, name, qualified_name, regex, type_code,   parent_id, parent_name, parent_type_code,   range_line, range_column, range_length) "
             @" VALUES (?, ?, ?, ?, ?,   ?, ?, ?,   ?, ?, ?)",
             [NSNumber numberWithLongLong:pass_id],
             tName, tQualifiedName, tPattern, tKind,
             minusOne, minusOne, minusOne, 
             [NSNumber numberWithLongLong:lineNumber], minusOne, minusOne
             
             ];

		    DGDestroyTagEntry(*it);
        }
        
        commitcount++;
		[db.db commit];
        
        if (finishedBlock)
            dispatch_async(dispatch_get_main_queue(), finishedBlock);
	});
}



@end


extern "C" void DGExCtag_PushTagEntry(tagEntryInfo* tag) {
    DGExCtag_TagEntryQueue.push_back(tag);
}
extern "C" tagEntryInfo* DGExCtag_PopTagEntry() {
    
    tagEntryInfo* front =  DGExCtag_TagEntryQueue.empty() ? (tagEntryInfo*)NULL : DGExCtag_TagEntryQueue.front();
    if (front)
        DGExCtag_TagEntryQueue.pop_front();
    return front;
}

extern "C" void DGDestroyTagEntry(const tagEntryInfo *const copytag) {
    free((void*)(copytag->language));
    
    free((void*)(copytag->sourceFileName));
    free((void*)(copytag->name));
    free((void*)(copytag->kindName));
    
    free((void*)(copytag->extensionFields.access));
    free((void*)(copytag->extensionFields.fileScope));
    free((void*)(copytag->extensionFields.implementation));
    
    free((void*)(copytag->extensionFields.inheritance));
    free((void*)(copytag->extensionFields.scope[0]));
    free((void*)(copytag->extensionFields.scope[1]));
    
    free((void*)(copytag->extensionFields.signature));
    free((void*)(copytag->extensionFields.typeRef[0]));
    free((void*)(copytag->extensionFields.typeRef[1]));
    
    free((void*)copytag);
}

void DGEntryPrint(tagEntryInfo entry) {
    NSLog(
          @"lineNumberEntry: %d\n"
          @"lineNumber: %ul\n"
          @"language: %@\n"
          @"isFileScope: %d\n"
          @"isFileEntry: %d\n"
          @"truncateLine: %d\n"
          @"sourceFileName: %@\n"
          @"name: %@\n"
          @"kindName: %@\n"
          @"kind: %d\n"
          
          @"access: %@\n"
          @"fileScope: %@\n"
          @"implementation: %@\n"
          @"inheritance: %@\n"
          @"scope 0: %@\n"
          @"scope 1: %@\n"
          @"signature: %@\n"
          @"typeRef 0: %@\n"
          @"typeRef 1: %@\n", entry.lineNumberEntry, entry.lineNumber, DGNSString(entry.language), entry.isFileScope, entry.isFileEntry, entry.truncateLine, DGNSString(entry.sourceFileName), DGNSString(entry.name), DGNSString(entry.kindName), entry.kind, DGNSString(entry.extensionFields.access), DGNSString(entry.extensionFields.fileScope), DGNSString(entry.extensionFields.implementation), DGNSString(entry.extensionFields.inheritance), DGNSString(entry.extensionFields.scope[0]), DGNSString(entry.extensionFields.scope[1]), DGNSString(entry.extensionFields.signature), DGNSString(entry.extensionFields.typeRef[0]), DGNSString(entry.extensionFields.typeRef[1]));
}
