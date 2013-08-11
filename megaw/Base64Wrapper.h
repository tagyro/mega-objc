//
//  Base64Wrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#include "megacpp/mega.h"
#include "megacpp/megacrypto.h"

@interface Base64Wrapper : NSObject

+(char*) btoa:(const byte*)b oflength:(int)blen tobuf:(char*)a;
+(byte*) atob:(const char*)a tobytes:(byte*)b withlen:(int)blen;

@end

static const int SEGSIZE = 131072;

@interface ChunkedHashWrapper : NSObject

+(off_t) chunkfloor:(off_t)p;

+(off_t) chunkceil:(off_t)p;

@end