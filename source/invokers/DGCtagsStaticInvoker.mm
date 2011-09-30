//
//  DGCtagsStaticInvoker.m
//  diglett
//
//  Created by Alex Gordon on 29/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGCtagsStaticInvoker.h"
#import <deque>
#import <cstdlib>

extern "C" {
#import "entry.h"
}

extern int ctags_main(int argc, char **argv);


std::deque<tagEntryInfo*> DGExCtag_TagEntryQueue;

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


@implementation DGCtagsStaticInvoker

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

@end
