//
//  ShareWrapper.m
//  testioslib
//

#import "ShareWrapper.h"
#import "UserWrapper.h"

@implementation ShareWrapper

-(id)initWithuser:(UserWrapper*)u access:(accesslevel)a andtime:(time_t)t
{
    if (!(self = [super init]))
        return nil;
    
    user = u;
	access = a;
	ts = t;
    
    return self;
}

-(void) removeshare:(handle)sh
{
    [user->sharing removeObject:[NSNumber numberWithUnsignedLongLong:sh]];
}

-(void) update:(accesslevel)a withtime:(time_t)t
{
    access = a;
    ts = t;
}

@end

@implementation NewShareWrapper

-(id)initWithshare:(ShareWrapper*)s andsymcipher:(SymmCipher*)k
{
    if (!(self = [super init]))
        return nil;
    
    share = s;
	sharekey = k;
    
    return self;
}

@end