//
//  DGCtagsStaticInvoker.h
//  diglett
//
//  Created by Alex Gordon on 29/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DGInvoker.h"
@interface DGCtagsStaticInvoker : DGInvoker

- (std::vector<tagEntryInfo*>)parseFileContents:(NSString *)contents ctagsLanguage:(NSString *)ctagsLanguage;
- (std::vector<tagEntryInfo*>)parseFilePath:(NSString *)path ctagsLanguage:(NSString *)ctagsLanguage;

@end
