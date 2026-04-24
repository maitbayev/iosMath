#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher
+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))block {
    @try {
        block();
        return NO;
    }
    @catch (NSException *) {
        return YES;
    }
}
@end
