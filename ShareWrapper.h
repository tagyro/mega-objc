//
//  ShareWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"

@class UserWrapper;

@interface ShareWrapper : NSObject
{
    @public
    accesslevel access;
	UserWrapper* user;
	time_t ts;
}

-(id)initWithuser:(UserWrapper*)u access:(accesslevel)a andtime:(time_t)t;

-(void) removeshare:(handle)sh;

-(void) update:(accesslevel)a withtime:(time_t)t;

@end

@interface NewShareWrapper : NSObject
{
    @public
    ShareWrapper* share;
	SymmCipher* sharekey;

}

-(id)initWithshare:(ShareWrapper*)s andsymcipher:(SymmCipher*)k;

@end
