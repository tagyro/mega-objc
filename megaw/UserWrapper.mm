//
//  UserWrapper.m
//  testioslib
//

#import "UserWrapper.h"
#import "NodeWrapper.h"

@implementation UserWrapper

-(void) set:(visibility)v andtime:(time_t)ct
{    
    show = v;
    ctime = ct;
}

-(id) initWithemail:(NSString *)cemail
{
    if (!(self = [super init]))
        return nil;

    email = [NSMutableString stringWithString:@""];
    sharing = [NSMutableSet set];
    pkrs = [NSMutableArray array];
    
    show = VISIBILITY_UNKNOWN;
    ctime = 0;
    if (cemail != nil)
    {
        email = [NSMutableString stringWithString:cemail];
    }
    
    return self;
}

@end
