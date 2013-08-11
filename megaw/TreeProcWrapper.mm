//
//  TreeProcWrapper.m
//  megaiosapp
//

#import "TreeProcWrapper.h"
#import "NodeWrapper.h"
#import "CommandWrapper.h"
#import "Base64Wrapper.h"
#import "ShareWrapper.h"
#import "UserWrapper.h"

static const char* accesslevels[] = { "read-only", "read/write", "full access" };

@implementation ShareNodeKeysWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    shares = [NSMutableArray array];
    items = [NSMutableArray array];
    keys = [NSMutableArray array];
    
    return self;
}

-(int) addshare:(NodeWrapper *)sn
{
    for (int i = [shares count]; i--; ) if ([shares objectAtIndex:i] == sn) return i;
    
	[shares addObject:(sn)];
    
	return [shares count]-1;
}

-(void) add:(MegaClientWrapper *)client withn:(NodeWrapper *)n withsn:(NodeWrapper *)sn andspecific:(int)specific
{
    if (!sn) sn = n;
    
    [self add:client withn:(NodeCoreWrapper*)n withsn:sn andspecific:specific anditem:NULL andlength:0];
}

-(void) add:(MegaClientWrapper *)client withn:(NodeCoreWrapper *)n withsn:(NodeWrapper *)sn andspecific:(int)specific anditem:(const byte *)item andlength:(int)itemlen
{
    char buf[96];
	byte key[FILENODEKEYLENGTH];
    
	int addnode = 0;
    
	// emit all share nodekeys for known shares
	do {
		if (sn->sharekey)
		{
            [keys addObject:[NSNumber numberWithInt:[self addshare:sn]]];
            [keys addObject:[NSNumber numberWithUnsignedInteger:[items count]]];
			//we are NSArray, and we don't need this.
            //sprintf(buf,",%d,%d,\"",addshare(sn),(int)items.size());
            
			sn->sharekey->ecb_encrypt(n->nodekey,key,n->keylen);
            
            [Base64Wrapper btoa:key oflength:n->keylen tobuf:buf];
			[keys addObject:[NSString stringWithUTF8String:buf]];
			addnode = 1;
		}
	} while (!specific && !ISUNDEF(sn->parent) && (sn = [client nodebyhandle:sn->parent]));
    
	if (addnode)
	{
		if (item) [items addObject:[NSData dataWithBytes:item length:itemlen]];
		else [items addObject:[NSData dataWithBytes:(const char*)&n->nodehandle length:6]];
	}
}

-(void)get:(CommandWrapper *)c
{
    NSMutableArray *rsharehandlearray = [NSMutableArray array];
    NSMutableArray *rnodehandlearray = [NSMutableArray array];
    
    NSEnumerator *enumerator = [shares objectEnumerator];
    NodeWrapper *n;
    while ((n = [enumerator nextObject])) {
        char buf[12];
        handle h = n->nodehandle;
        [Base64Wrapper btoa:(const byte*)&h oflength:6 tobuf:buf];
        [rsharehandlearray addObject:[NSString stringWithUTF8String:buf]];
    }
    
    enumerator = [items objectEnumerator];
    NSData* d;
    while ((d = [enumerator nextObject])) {
        char buf[50];
        [Base64Wrapper btoa:(const byte*)[d bytes] oflength:[d length] tobuf:buf];
        [rnodehandlearray addObject:[NSString stringWithUTF8String:buf]];
    }
    
    NSMutableArray* big_array = [NSMutableArray array];
    [big_array addObject:rsharehandlearray];
    [big_array addObject:rnodehandlearray];
    [big_array addObject:keys];
    
    [c arg_array:@"cr" witharray:big_array];

}

@end

@implementation TreeProcWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

@end

@implementation TreeProcDelWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
 
}

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n
{
    n->removed = YES;
	[client notifynode:n];
}

@end

@implementation TreeProcListOutShresWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
    
}

-(void) proc:(MegaClientWrapper *)client andnode:(NodeWrapper *)n
{
    NSEnumerator *enumerator = [n->outshares keyEnumerator];
    NSNumber* num_key;
    while ((num_key = [enumerator nextObject])) {
        ShareWrapper* share = [n->outshares objectForKey:num_key];
        handle h = [num_key unsignedLongLongValue];
        
        cout << "\t" << [n displayname];
        
		if (h) cout << ", shared with " << [[client finduser:h withnew:0]->email UTF8String] << " (" << accesslevels[share->access] << ")" << endl;
		else cout << ", shared as exported folder link" << endl;
    }
}

@end

@implementation TreeProcCopyWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    nn = nil;
    nc = 0;
    
    return self;
}

-(void) proc:(MegaClientWrapper *)client andnode:(NodeWrapper *)n
{
    if (nn && ([nn count] > 0))
	{
		string attrstring;
		SymmCipher key;
		NewNodeWrapper* t = [nn objectAtIndex:nc];
        
		// copy node
		t->source = NEW_NODE;
		t->type = n->type;
		t->nodehandle = n->nodehandle;
		t->parent = n->parent;
		t->mtime = n->mtime;
		t->ctime = n->ctime;
        
		// copy key (if file) or generate new key (if folder)
		if (n->type == FILENODE) memcpy(t->nodekey,n->nodekey,FILENODEKEYLENGTH);
		else PrnGen::genblock(t->nodekey,FOLDERNODEKEYLENGTH);
        
		key.setkey(t->nodekey,n->type);
        
        NSError* err;
        NSData* attr_data = [NSJSONSerialization dataWithJSONObject:n->attrs options:0 error:&err];
        
        [client makeattr:&key withoutput:t->attrdata andinput:attr_data];
    }
    
	nc++;
}

-(void) allocnodes
{
    nn = [NSMutableArray array];
    for (int idx = 0; idx < nc; idx ++)
    {
        [nn addObject:[[NewNodeWrapper alloc] init]];
    }
}

@end

@implementation TreeProcDUWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    numbytes = 0;
	numfiles = 0;
	numfolders = 0;
    
    return self;
    
}

-(void) proc:(MegaClientWrapper *)client andnode:(NodeWrapper *)n
{
    if (n->type == FILENODE)
	{
		numbytes += n->size;
		numfiles++;
	}
	else numfolders++;
}

@end

@implementation TreeProcShareKeysWrapper

-(id) initWithNode:(NodeWrapper *)n
{
    if (!(self = [super init]))
        return nil;
    
    sn = n;
    snk = [[ShareNodeKeysWrapper alloc] init];
    
    return self;
}

-(void) proc:(MegaClientWrapper *)client andnode:(NodeWrapper *)n
{
    [snk add:client withn:n withsn:sn andspecific:(sn != nil)];
}

-(void) get:(CommandWrapper *)c
{
    [snk get:c];
}

@end