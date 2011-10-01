#import <Foundation/Foundation.h>

@interface DGIndexer : NSObject
{
    CHProject *project;
    NSString *path;
    NSString *contents;
    NSString *language;
    int64_t rid; // resource_id
    dispatch_block_t completionBlock;
}

@property (assign) CHProject *project;
@property (assign) NSString *path;
@property (assign) NSString *contents;
@property (assign) NSString *language;
@property (assign) int64_t rid; // resource_id
@property (copy) dispatch_block_t completionBlock;

@end
