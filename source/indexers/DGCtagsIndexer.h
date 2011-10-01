#import "DGIndexer.h"

@interface DGCtagsIndexer : DGIndexer
{
    
}

- (NSString *)ctagsLanguage;

- (void)parseFileContentsWithCtagsLanguage:(NSString *)ctagsLanguage;
- (void)parseFilePath:(NSString *)inputPath withCtagsLanguage:(NSString *)ctagsLanguage finishedBlock:(dispatch_block_t)finishedBlock;

@end
