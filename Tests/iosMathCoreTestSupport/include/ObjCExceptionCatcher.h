#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject
/// Returns YES if the block raised an NSException, NO if it returned normally.
+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))block;
@end

NS_ASSUME_NONNULL_END
