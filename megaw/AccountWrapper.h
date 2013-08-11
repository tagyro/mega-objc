//
//  AccountWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>

@interface AccountDetailsWrapper : NSObject
{
    @public
    off_t storage_used, storage_max;
	off_t transfer_own_used, transfer_srv_used, transfer_max;
	double srv_ratio;
    
	int pro_level;
	char subscription_type;
    
	time_t pro_until;
    
	NSMutableArray* balances;
	NSMutableArray* sessions;
	NSMutableArray* purchases;
	NSMutableArray* transactions;
}

-(id) init;

@end

@interface AccountBalanceWrapper : NSObject
{
    @public
    double amount;
	char currency[3];
}

-(id) init;

@end

@interface AccountSessionWrapper : NSObject
{
    @public
    time_t timestamp, mru;
	NSString* useragent;
	NSString* ip;
	char country[2];
	int current;
}

-(id) init;

@end

@interface AccountPurchaseWrapper : NSObject
{
    @public
    time_t timestamp;
	char local_handle[11];
	char currency[3];
	double amount;
	int method;
}

-(id) init;

@end

@interface AccountTransactionWrapper : NSObject
{
    @public
    time_t timestamp;
	char local_handle[11];
	char currency[3];
	double delta;
}

-(id) init;

@end