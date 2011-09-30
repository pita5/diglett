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

extern int ctags_main(int argc, char **argv);

std::deque<tagEntryInfo*> DGExCtag_TagEntryQueue;

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
    
}


- (std::vector<tagEntryInfo*>)parseFileContents:(NSString *)contents ctagsLanguage:(NSString *)ctagsLanguage;
{
    // Put contents in a CHTemporaryFile
    return [self parseFilePath:temppath ctagsLanguage:ctagsLanguage];
}
- (std::vector<tagEntryInfo*>)parseFilePath:(NSString *)path ctagsLanguage:(NSString *)ctagsLanguage;
{
    std::vector<tagEntryInfo*> rv;
    
    extern dispatch_queue_t DGCtagsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DGCtagsQueue = dispatch_queue_create(NULL, NULL);
    });
    
    dispatch_sync(DGCtagsQueue, ^{
        
        const char * args[] = {
            "ctags",
            "--extra=+fq",
            "--fields=+afmikKlnsStz",
            "--filter=no",
            [[NSString stringWithFormat:@"--%@-kinds=+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", ctagsLanguage] UTF8String],
            [[NSString stringWithFormat:@"--language-force=%@", ctagsLanguage] UTF8String],
            "--sort=no",
            "-L", [path UTF8String],
            NULL
            // put --langdef directives here, once gnuregex is working
        };
        
        ctags_main(sizeof(args) / sizeof(const char *), args);
        
        std::copy(DGExCtag_TagEntryQueue.end(), DGExCtag_TagEntryQueue.end(), rv.begin());
        DGExCtag_TagEntryQueue.clear();
        
    });
    
    return rv;
}



static NSString *DGNSString(const char *ustr) {
    return ustr ? [NSString stringWithUTF8String:ustr] : @"";
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

- (void)fillFrom:(std::vector<tagEntryInfo*>)entries {
    
    __block int64_t pass_id = -1;
	
	dispatch_sync(db.queue, ^{
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
		
		for (std::vector<tagEntryInfo*>::iterator it = entries.begin(), et = entries.end(); it != et; ++it)
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
		}
        
        commitcount++;
		[db.db commit];
        
	});
	
    DGDestroyTagEntry(tags);
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
