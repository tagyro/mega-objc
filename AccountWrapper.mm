//
//  AccountWrapper.m
//  testioslib
//

#import "AccountWrapper.h"

@implementation AccountDetailsWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    balances = [NSMutableArray array];
    sessions = [NSMutableArray array];
    purchases = [NSMutableArray array];
    transactions = [NSMutableArray array];
    
    return self;
}

@end

@implementation AccountBalanceWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

@end

@implementation AccountSessionWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    useragent = @"";
    ip = @"";
    
    return self;
}

@end

@implementation AccountPurchaseWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

@end

@implementation AccountTransactionWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

@end