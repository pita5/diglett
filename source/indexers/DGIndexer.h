#import <Foundation/Foundation.h>

@class DGProject;

@interface DGIndexer : NSObject
{
    DGProject *project;
    NSString *path;
    NSString *contents;
    NSString *language;
    int64_t rid; // resource_id
    dispatch_block_t completionBlock;
}

@property (assign) DGProject *project;
@property (assign) NSString *path;
@property (assign) NSString *contents;
@property (assign) NSString *language;
@property (assign) int64_t rid; // resource_id
@property (copy) dispatch_block_t completionBlock;

- (void)index;

@end
