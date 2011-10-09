//
//  DGCtagsIndexerC.m
//  diglett
//
//  Created by Alex Gordon on 05/10/2011.
//  Copyright 2011 Fileability. All rights reserved.
//



#import <Foundation/Foundation.h>
#import "CHXMainDatabase.h"

#import "entry.h"
#import "DGCtagsIndexerC.h"

static NSString *DGNSString(const char *ustr) { return ustr ? [NSString stringWithUTF8String:ustr] : @""; }

void DGEntryPrint(void* const entry_p) {
    tagEntryInfo entry = *(tagEntryInfo* const)entry_p;
    NSLog(@"lineNumberEntry: %d\n", entry.lineNumberEntry);
    NSLog(@"lineNumber: %lul\n", entry.lineNumber);
    //NSLog(@"language: %@\n", DGNSString(entry.language));
    NSLog(@"isFileScope: %d\n", entry.isFileScope);
    NSLog(@"isFileEntry: %d\n", entry.isFileEntry);
    NSLog(@"truncateLine: %d\n", entry.truncateLine);
    NSLog(@"sourceFileName: %@\n", DGNSString(entry.sourceFileName));
    NSLog(@"name: %@\n", DGNSString(entry.name));
    NSLog(@"kindName: %@\n", DGNSString(entry.kindName));
    NSLog(@"kind: %d\n", entry.kind);
    
    NSLog(@"access @: %@\n", DGNSString(entry.extensionFields.access));
    NSLog(@"fileScope: %@\n", DGNSString(entry.extensionFields.fileScope));
    //NSLog(@"implementation: %@\n", DGNSString(entry.extensionFields.implementation));
    NSLog(@"inheritance: %@\n", DGNSString(entry.extensionFields.inheritance));
    NSLog(@"scope 0: %@\n", DGNSString(entry.extensionFields.scope[0]));
    NSLog(@"scope 1: %@\n", DGNSString(entry.extensionFields.scope[1]));
    NSLog(@"signature: %@\n", DGNSString(entry.extensionFields.signature));
    NSLog(@"typeRef 0: %@\n", DGNSString(entry.extensionFields.typeRef[0]));
    NSLog(@"typeRef 1: %@\n", DGNSString(entry.extensionFields.typeRef[1]));
    NSLog(@"sourceLine = %@\n", DGNSString(entry.extensionFields.sourceLine));
}
void DGDestroyTagEntry(void* const copytag_v) {
    tagEntryInfo* const copytag = (tagEntryInfo* const)copytag_v;
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
    
    free((void*)(copytag->extensionFields.sourceLine));
    
    free((void*)copytag);
}

void DGProcessTag(int64_t pass_id, CHXMainDatabase* db, void* const tag_p) {
    tagEntryInfo tag = *(tagEntryInfo* const)tag_p;
    //DGEntryPrint(tag_p);
    
    int64_t lineNumber = ((int64_t)(tag.lineNumber)) - 1;
    if (lineNumber < 0)
        return;
    
    NSString *tQualifiedName = DGNSString(tag.name);
    NSString *tPattern = DGNSString(tag.extensionFields.sourceLine); // ??
    NSString *tKind = DGNSString(tag.kindName);
    if ([tKind isEqual:@"file"])
        return;
    
    short fileScope = tag.isFileScope;
    
    /*
     if ([tPattern length] >= 3 && tag.address.pattern && (tag.address.pattern[0] == '/' || tag.address.pattern[0] == '?'))
     tPattern = [tPattern substringWithRange:NSMakeRange(1, [tPattern length] - 2)];
     else
     tPattern = @"";
     */
    NSString *tName = [[tQualifiedName componentsSeparatedByString:@"::"] lastObject];
    
    //insertcount++;
    [db.db executeUpdate:@"INSERT INTO symbols (pass, name, qualified_name, regex, type_code,   parent_id, parent_name, parent_type_code,   range_line, range_column, range_length) "
     @" VALUES (?, ?, ?, ?, ?,   -1, -1, -1,   ?, -1, -1)",
     [NSNumber numberWithLongLong:pass_id],
     tName, tQualifiedName, tPattern, tKind,
     //minusOne, minusOne, minusOne, 
     [NSNumber numberWithLongLong:lineNumber] //, minusOne, minusOne
     
     ];
}

