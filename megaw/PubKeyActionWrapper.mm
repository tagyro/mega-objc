//
//  PubKeyActionWrapper.m
//  megaiosapp
//

#import "PubKeyActionWrapper.h"
#import "NodeWrapper.h"
#import "CommandWrapper.h"
#include "megacpp/megacrypto.h"

@implementation PubKeyActionWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

@end

@implementation PubKeyActionCreateShareWrapper

-(id)initWithHandle:(handle)sh andaccesslevel:(accesslevel)sa
{
    if (!(self = [super init]))
        return nil;

    h = sh;
	a = sa;
    
    return self;
}

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u
{
    NodeWrapper* n;
	int newshare;
    
	// node vanished: bail
    if (!(n = [client nodebyhandle:h])) return;
    
	// do we already have a share key for this node?
	if ((newshare = !n->sharekey))
	{
		// no: create
		byte key[SymmCipher::KEYLENGTH];
        
		PrnGen::genblock(key,sizeof key);
        
		n->sharekey = new SymmCipher(key);
	}
    
	// we have all ingredients ready: the target user's public key, the share key and all nodes to share
    [client->reqs[client->req_sn] add:[[CommandSetShareWrapper alloc] initWithClient:client withNode:n anduser:u andaccesslevel:a andnewshare:newshare]];
}

@end

@implementation PubKeyActionSendShareKeyWrapper

-(id)initWithHandle:(handle)h
{
    if (!(self = [super init]))
        return nil;
    
    sh = h;
    
    return self;
}

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u
{
    NodeWrapper* n;
    
    // only the share owner distributes share keys
	if (u && (n = [client nodebyhandle:sh]) && n->outshare)
	{
		int t;
		byte buf[AsymmCipher::MAXKEYLENGTH];
        
		if ((t = u->pubk.encrypt(n->sharekey->key,SymmCipher::KEYLENGTH,buf,sizeof buf))) [client->reqs[client->req_sn] add:[[CommandShareKeyUpdateWrapper alloc] initWithClient:client andsharehandle:sh anduid:u->uid andkeybuffer:buf andkeylen:t]];
	}
}

@end

@implementation PubKeyActionAddNodesWrapper

-(id)initWithNewNode:(NewNodeWrapper *)n andidx:(int)idx
{
    if (!(self = [super init]))
        return nil;
    
    nn = n;
    nc = idx;
    
    return self;
}

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u
{
    
}

@end