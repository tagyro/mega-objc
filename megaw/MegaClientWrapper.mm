//
//  MegaClientWrapper.m
//  megaios
//

#import "MegaClientWrapper.h"
#import "MegaAppWrapper.h"
#import "NodeWrapper.h"
#import "CommandWrapper.h"
#import "UserWrapper.h"
#import "Base64Wrapper.h"
#import "ShareWrapper.h"
#import "HttpIOWrapper.h"
#import "RequestWrapper.h"
#import "FileTransferWrapper.h"
#import "TreeProcWrapper.h"
#import "PubKeyActionWrapper.h"
#import "AccountWrapper.h"

@implementation MegaClientWrapper

-(id) initWithApp:(MegaAppWrapper *)app andHttpIO:(HttpIOWrapper *)httpio andAppkey:(char *)k
{
    if (!(self = [super init]))
        return nil;
    //self->inner_client = new MegaClient(app, httpio);
    
    apiurl = @"https://staging.api.mega.co.nz/";
    
    pending_lock = [NSObject new];
    pending = nil;
    nextattempt = 0;
    backoff = 1;
    
    pendingsc_lock = [NSObject new];
    pendingsc = nil;
    nextattemptsc = 0;
    backoffsc = 1;
    
    nextattemptputfa = 0;
    backoffputfa = 1;
    
    http_queue = [NSOperationQueue new];
    
    app_wrapper = app;
    httpio_wrapper = httpio;
    req_sn = 0;
    
    reqs[0] = [[RequestWrapper alloc] init];
    reqs[1] = [[RequestWrapper alloc] init];
    scnotifyurl = @"";
    nodekeyrewrite = [NSMutableArray array];
    sharekeyrewrite = [NSMutableArray array];
    nodenotify = [NSMutableArray array];
    usernotify = [NSMutableArray array];
    nodes = [NSMutableDictionary dictionary];
    newshares = [NSMutableDictionary dictionary];
    userpubk = [NSMutableDictionary dictionary];
    users = [NSMutableDictionary dictionary];
    uhindex = [NSMutableDictionary dictionary];
    umindex = [NSMutableDictionary dictionary];
    
    ft[0] = [[FileTransferWrapper alloc] initWithIndex:0];
    ft[1] = [[FileTransferWrapper alloc] initWithIndex:1];
    
    pendingfa = [NSMutableDictionary dictionary];
    fileattrs = [NSMutableDictionary dictionary];
    newfa = [NSMutableArray array];
    
    curfa = -1;
    
    scsn = @"";
    
    children = [NSMutableDictionary dictionary];
    uhnh = [NSMutableDictionary dictionary];
    
    json = [NSData data];
    jsonsc = [NSData data];
    
    int i;
    
	// initialize random client application instance ID
	for (i = sizeof sessionid; i--; ) sessionid[i] = 'a'+PrnGen::genuint32(26);
    
	// initialize random API request sequence ID
	for (i = sizeof reqid; i--; ) reqid[i] = 'a'+PrnGen::genuint32(26);
    
	for (i = sizeof rootnodes/sizeof *rootnodes; i--; ) rootnodes[i] = UNDEF;
    reqid[10] = 0;
    
    auth=[NSMutableString string];
    
	for (int i = sizeof(rootnodes)/sizeof(*rootnodes); i--; ) rootnodes[i] = UNDEF;
    
    warned = 0;
    
    userid = 0;
    
    nextuh = 0;
    
    appkey = [NSString stringWithFormat:@"&ak=%s",k];
    
    return self;
}

-(void) pendingattrstring:(handle)h tofa:(NSMutableString *)fa
{
    char buf[128];
    
    NSMutableDictionary* dict_obj = [pendingfa objectForKey:[NSNumber numberWithUnsignedLongLong:h]];
    if (dict_obj == nil)
    {
        return;
    }
    NSEnumerator* enumerator = [dict_obj keyEnumerator];
    NSNumber *key_num, *value_num;
    while ((key_num = [enumerator nextObject])) {
        value_num = [dict_obj objectForKey:key_num];
        sprintf(buf,"/%u*",[key_num unsignedShortValue]);
        handle value_handle = [value_num unsignedLongLongValue];
        [Base64Wrapper btoa:(byte*)&value_handle oflength:sizeof(handle) tobuf:strchr(buf+3,0)];
        [fa appendFormat:@"%s", buf+![fa lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [pendingfa removeObjectForKey:[NSNumber numberWithUnsignedLongLong:h]];
}

-(int) alloctd
{
    for (int i = 0; i < 2; i++)
    {
        if (!ft[i]->inuse)
        {
            ft[i]->inuse = 1;
            return i;
        }
    }
    
    return API_ETOOMANY;
}

-(void) purgenodes:(NSArray*)affected
{
    for (id node_key in [nodes allKeys])
    {
        id value = [nodes objectForKey:node_key];
        NodeWrapper* node_value = (NodeWrapper *)value;
        if ((affected == nil) || (node_value->removed))
        {
            [nodes removeObjectForKey:node_key];
        }
    }
    
    [children removeAllObjects];
}

-(void) purgeusers:(NSArray*)affected
{
    [users removeAllObjects];
    [uhindex removeAllObjects];
    [umindex removeAllObjects];
    
    userid = 0;
}

-(int) readusers:(id)j
{
    NSError *error;
    id json_obj;
    if ([j isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:j options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = j;
    BOOL is_array = [json_obj isKindOfClass:[NSArray class]];
    if (!is_array)
    {
        return 0;
    }
    NSArray* json_array = (NSArray *)json_obj;
    NSEnumerator *enumerator = [json_array objectEnumerator];
    id obj_item;
    while (obj_item = [enumerator nextObject]) {
        if (![obj_item isKindOfClass:[NSDictionary class]])
        {
            return 0;
        }
        
        NSDictionary* json_dict = (NSDictionary *)obj_item;
        handle uh = 0;
		visibility v = HIDDEN;
		time_t ts = 0;
		NSString* m = nil;
        
        
        for (NSString* dict_key in [json_dict allKeys])
        {
            id value = [json_dict objectForKey:dict_key];
            if ([dict_key isEqualToString:@"u"])
            {
                uh = [self convert_base64str_handle:(NSString *)value];
            } else if ([dict_key isEqualToString:@"c"])
            {
                v = (visibility)[(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"m"])
            {
                m = (NSString*)value;
            }else if ([dict_key isEqualToString:@"ts"])
            {
                ts = [(NSNumber *)value intValue];
            }
        }
        
        if (!uh) [self warn:@"Missing contact user handle"];

		if (!m) [self warn:@"Unknown contact user e-mail address"];
        
		if (![self warnlevel])
		{
			if (v == ME)
			{
				me = uh;
                [NodeWrapper copystring:myemail from:[m UTF8String]];
			}
			else
            {
                UserWrapper* u;
                
                if ((u = [self finduser:uh withnew:0]))
                {
                    [self mapuser:uh withemail:m];
                    [u set:v andtime:ts];
                    
                    [self notifyuser:u];
                }
            }
            
            [self mapuser:uh withemail:m];
		}
    }
    return 1;
}

-(void) exec
{
    uint32_t ds = [app_wrapper dstime];
    @synchronized (pending_lock)
    {
        int action = 1;
        if (pending)
        {
            action = 0;
        }
        
        if (action == 1)
        {
            if (!nextattempt || ds >= nextattempt)
            {
                if (nextattempt) req_sn ^= 1;
            } else {
                [app_wrapper notify_retry:self intime:nextattempt-ds];
                action = 0;
            }
        }
        
        if ([reqs[req_sn] cmdspending] && action == 1)
        {
            pending = [[HttpRequestWrapper alloc] init];
        
            [reqs[req_sn] get:pending->out];
        
            pending->posturl = [NSMutableString stringWithString:apiurl];
        
            [pending->posturl appendString:@"cs?id="];
            NSString* reqid_str = [NSString stringWithUTF8String:reqid];
            [pending->posturl appendString:reqid_str];
            [pending->posturl appendString:auth];
            [pending->posturl appendString:appkey];
            
            pending->type = REQ_JSON;
            pending->direction = 0; //Client to server
            
            [httpio_wrapper post:pending isbulk:0 withdata:NULL andlen:0];
            
            req_sn ^= 1;
        }
    }

    @synchronized (pendingsc_lock)
    {
        if (pendingsc == nil && [scsn lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0 && (!nextattemptsc || ds > nextattemptsc))
        {
            pendingsc = [[HttpRequestWrapper alloc] init];
            if ([scnotifyurl lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0)
            {
                pendingsc->posturl = [NSMutableString stringWithString:scnotifyurl];
            } else
            {
                pendingsc->posturl = [NSMutableString stringWithString:apiurl];
                [pendingsc->posturl appendFormat:@"sc?sn=%@%@", scsn, auth];
            }
            
            pendingsc->type = REQ_JSON;
            pendingsc->direction = 1; //Server to client
            
            [httpio_wrapper post:pendingsc isbulk:0 withdata:NULL andlen:NULL];
        }
    }
    
    for (int i = sizeof(ft)/sizeof(*ft); i--; ) if (ft[i]->inuse) [ft[i] doio:self];
    
    if ([newfa count] > 0 && curfa == -1 && (!nextattemptputfa || ds > nextattemptputfa))
    {
        // dispatch most recent file attribute put
        curfa = 0;
        [reqs[req_sn] add:[newfa objectAtIndex:curfa]];
    }
}

-(void) exec_process_success:(HttpRequestWrapper*)http_req withdata:(NSData *)data
{
    if (http_req->direction == 0)
    {
        NSError* err;
        id json_obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&err];
        if ([json_obj isKindOfClass:[NSNumber class]])
        {
            error e = (error)[(NSNumber *)json_obj intValue];
            if (e == API_EAGAIN)
                return [self exec_process_failure:http_req witherr:e];
            [app_wrapper request_error:self witherror:e];
            return;
        }
        json = [NSData dataWithData:data];
        [reqs[req_sn^1] procresult:self];
        
        @synchronized (pending_lock)
        {
            pending = nil;
    
            for (int i = 9; i>=0; i--) if (reqid[i]++ < 'z') break;
            else reqid[i] = 'a';
        
            nextattempt = 0;
            backoff = 1;
        }
    } else if (http_req->direction == 1)
    {
        if ([scnotifyurl lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0)
        {
            scnotifyurl = @"";
        } else
        {
            NSError* err;
            id json_obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&err];
            if ([json_obj isKindOfClass:[NSNumber class]])
            {
                error e = (error)[(NSNumber *)json_obj intValue];
                return [self exec_process_failure:http_req witherr:e];
            }
            
            jsonsc = [NSData dataWithData:data];
            [self procsc];
        }
        
        @synchronized (pendingsc_lock)
        {
            pendingsc = nil;
            
            nextattemptsc = 0;
            backoffsc = 1;
        }
    } else if (http_req->direction == 3)
    {
        if ([data length] == sizeof(handle))
        {
            handle h = *(handle*)[data bytes];
            // successfully wrote file attribute - store handle & remove from list
            [(HttpReqCommandPutFAWrapper*)[newfa objectAtIndex:curfa] sethandle:self withhandle:h];
            [newfa removeObjectAtIndex:curfa];
        }
        nextattemptputfa = 0;
        backoffputfa = 1;
        curfa = -1;
    }
}

-(void) exec_process_failure:(HttpRequestWrapper*)http_req witherr:(error)err
{
    uint32_t ds = [app_wrapper dstime];
    if (http_req->direction == 0)
    {
        @synchronized (pending_lock)
        {
            pending = nil;
            
            nextattempt = ds+backoff;
            if (backoff < 36000) backoff <<= 1;
        }
    } else if (http_req->direction == 1)
    {
        if ([scnotifyurl lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0)
        {
            scnotifyurl = @"";
        }        
        @synchronized (pendingsc_lock)
        {
            pendingsc = nil;
            
            nextattemptsc = ds+backoffsc;
            if (backoffsc < 36000) backoffsc <<= 1;
        }
    } else if (http_req->direction == 3)
    {
        [(HttpRequestWrapper*)[newfa objectAtIndex:curfa] init];
        curfa = -1;
        
        nextattemptputfa = ds+backoffputfa;
        if (backoffputfa < 36000) backoffputfa <<= 1;
    }

}

// wait for I/O or other events
-(void) wait
{
    //need_func wait();
}

-(void) loginWithEmail: (NSString *)email andpw_key:(byte *)pwkey
{
    key.setkey((byte*)pwkey);
	byte strhash[SymmCipher::KEYLENGTH];
    
    NSString* nemail = [email lowercaseString];
    
    [self stringhash:[nemail UTF8String] withhash:strhash andcipher:&key];
    
    [reqs[req_sn] add:[[CommandLoginWrapper alloc] initWithClient:self andemail:email andemailhash:strhash]];
}

-(void) fetchnodes
{
    [reqs[req_sn] add:[[CommandWrapper alloc] init]];
}

-(void) getaccountdetails:(AccountDetailsWrapper *)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro withtransactions:(int)transactions withpurchases:(int)purchases withsessions:(int)sessions
{
    [reqs[req_sn] add:[[CommandGetUserQuotaWrapper alloc] initWithClient:self withaccount:ad withstorage:storage withtransfer:transfer withpro:pro]];
	if (transactions) [reqs[req_sn] add:[[CommandGetUserTransactionsWrapper alloc] initWithClient:self withaccount:ad]];
	if (purchases) [reqs[req_sn] add:[[CommandGetUserPurchasesWrapper alloc] initWithClient:self withaccount:ad]];
	if (sessions) [reqs[req_sn] add:[[CommandGetUserSessionsWrapper alloc] initWithClient:self withaccount:ad]];
}

-(void) setattr:(NodeWrapper*)n withnewattr:(NSMutableDictionary*)newattr
{
    if ([newattr count] > 0)
    {
        [n->attrs addEntriesFromDictionary:newattr];
    }
    
    [reqs[req_sn] add:[[CommandSetAttrWrapper alloc] initWithClient:self andnode:n]];
}

-(void) makeattr:(SymmCipher*)attr_key withoutput:(NSMutableData*)attrstring andinput:(NSData*)attr_json
{
    //Because using NSJSONSerialization, json already contains the big bracer. {}
    int ll = ([attr_json length]+4+SymmCipher::KEYLENGTH-1)&-SymmCipher::KEYLENGTH;
    attrstring = [NSMutableData dataWithLength:ll];
    
    memcpy([attrstring mutableBytes], "MEGA", 4); // magic number
    memcpy((byte*)[attrstring mutableBytes]+4, [attr_json bytes], [attr_json length]);
    
    attr_key->cbc_encrypt((byte *)[attrstring mutableBytes], ll);
}

-(int) loggedin
{
    return !![myemail lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

-(error) folderaccess:(NSString *)f withk:(NSString *)k
{
    handle h = 0;
	byte folderkey[SymmCipher::KEYLENGTH];
	if ([Base64Wrapper atob:[f UTF8String] tobytes:(byte*)&h withlen:6]-(byte*)&h != 6) return API_EARGS;
	if ([Base64Wrapper atob:[k UTF8String] tobytes:folderkey withlen:sizeof(folderkey)]-folderkey != sizeof folderkey) return API_EARGS;
    
	[self setrootnode:h];
	key.setkey(folderkey);
    
	return API_OK;
}

-(error) changepw:(const byte *)oldpwkey tonewpw:(const byte *)newpwkey
{
    if (![self loggedin]) return API_EACCESS;
    
	byte oldkey[SymmCipher::KEYLENGTH];
	byte newkey[SymmCipher::KEYLENGTH];
	byte hash[SymmCipher::KEYLENGTH];
    
	SymmCipher pwcipher;
    
	memcpy(oldkey,key.key,sizeof oldkey);
	memcpy(newkey,oldkey,sizeof newkey);
    
	pwcipher.setkey((byte*)oldpwkey);
	pwcipher.ecb_encrypt(oldkey);
    
	pwcipher.setkey((byte*)newpwkey);
	pwcipher.ecb_encrypt(newkey);
    
	NSString* email = [myemail lowercaseString];
    
    [self stringhash:[email UTF8String] withhash:hash andcipher:&pwcipher];
    
    [reqs[req_sn] add:[[CommandSetMasterKeyWrapper alloc] initWithClient:self andok:oldkey andnk:newkey andhash:hash]];
    
	return API_OK;
}

// returns 1 if node has accesslevel a or better, 0 otherwise
-(int) checkaccess:(NodeWrapper *)n andaccess:(accesslevel)a
{
    // folder link access is always read-only
	if (![self loggedin]) return 0;
    
	// trace back to root node (always full access) or share node
	while (n != nil)
	{
		if (n->inshare) return a >= n->inshare->access;
		n = [self nodebyhandle:(n->parent)];
	}
    
	return 1;
}

// returns API_OK if a move operation is permitted, API_EACCESS or API_ECIRCULAR otherwise
-(error) checkmove:(NodeWrapper *)fn tonode:(NodeWrapper *)tn
{
    // a no-op move is always permitted
	if (fn == tn) return API_OK;
    
	NodeWrapper* n;
    
	// condition 1: must have full access to fn's parent
	if ((n = [self nodebyhandle:(fn->parent)]) && ![self checkaccess:n andaccess:FULL]) return API_EACCESS;
    
	// condition 2: target must be folder
	if (tn->type == FILENODE) return API_EACCESS;
    
	// condition 3: must have write access to target
	if (![self checkaccess:tn andaccess:RDWR]) return API_EACCESS;
    
	// condition 4: tn must not be below fn (would create circular linkage)
	for (;;)
	{
		if (tn->inshare) break;
		if (!(n = [self nodebyhandle:tn->parent])) break;
		if (n == fn) return API_ECIRCULAR;
		tn = n;
	}
    
	// condition 5: fn and tn must be in the same tree (same ultimate parent node or shared by the same user)
	for (;;)
	{
		if (fn->inshare) break;
		if (!(n = [self nodebyhandle:fn->parent])) break;
		fn = n;
	}
    
	if (fn == tn) return API_OK;
    
	if (fn->inshare && tn->inshare && fn->inshare->user == tn->inshare->user) return API_OK;
    
	return API_EACCESS;
}

-(error) unlink:(NodeWrapper*)n
{
    if (![self checkaccess:n andaccess:FULL]) return API_EACCESS;
    
    [reqs[req_sn] add:[[CommandDelNodeWrapper alloc] initWithClient:self withnode:n->nodehandle]];
    
    TreeProcDelWrapper* td;
    [self proctree:n withproc:td];
    [self notifypurge];
    
    return API_OK;
}

-(error) rename:(NodeWrapper*)n tonode:(NodeWrapper*)t
{
    error e;
    
	if ((e = [self checkmove:n tonode:t])) return e;
    
	if (n == t) return API_OK;
    
    [self setparent:n withandle:t->nodehandle];
	[self notifypurge];
    
    [reqs[req_sn] add:[[CommandMoveNodeWrapper alloc] initWithClient:self withnode:n tonode:t]];
    
    return API_OK;
}

-(int) topen:(NSString *)localpath withms:(int)ms andconn:(int)c
{
    int td;
    
	if ((td = [self alloctd]) < 0) return td;
    
    // generate random encryption key/CTR IV for this file
	byte keyctriv[SymmCipher::KEYLENGTH+sizeof(int64_t)];
	PrnGen::genblock(keyctriv,sizeof keyctriv);
    
	ft[td]->key.setkey(keyctriv);
	ft[td]->ctriv = *(uint64_t*)(keyctriv+SymmCipher::KEYLENGTH);
    
    NSFileHandle* file = [NSFileHandle fileHandleForReadingAtPath:localpath];
    
    if (file != nil)
    {
        [ft[td] init:[file seekToEndOfFile] andfilename:nil andconnection:c];
        [reqs[req_sn] add:[[CommandPutFileWrapper alloc] initWithtd:td andfile:file andms:ms andconn:c]];
    } else
    {
        [self tclose:td];
        
        return API_ENOENT;
    }
    
    return td;
}

-(int) topen:(handle)h withkey:(const byte*)k andstart:(off_t)start andlen:(off_t)len andconn:(int)c
{
    NodeWrapper* n;
	int td;
	int priv;
    
	if ((priv = !k))
	{
		if (!(n = [self nodebyhandle:h])) return API_ENOENT;
		if (n->type != FILENODE) return API_EACCESS;
		k = n->nodekey;
	}
    
	if ((td = [self alloctd]) < 0) return td;
    
	ft[td]->key.setkey(k,FILENODE);
	ft[td]->ctriv = *(int64_t*)(k+SymmCipher::KEYLENGTH);
	ft[td]->metamac = *(int64_t*)(k+SymmCipher::KEYLENGTH+sizeof(int64_t));
    
	ft[td]->startpos = start;
	ft[td]->endpos = (len >= 0) ? start+len : -1;
    ft[td]->startblock = [ChunkedHashWrapper chunkfloor:start];
	
	[reqs[req_sn] add:[[CommandGetFileWrapper alloc] initWithtd:td andhandle:h andp:priv andconn:c]];
	
	return td;
}

-(void) tclose:(int)td
{
    [ft[td] close];
}

-(handle) uploadhandle:(int)td
{
    if (!ft[td]->uploadhandle)
    {
        byte* ptr = (byte*)(&nextuh+1);
        
		while (!++(*--ptr));
        
        ft[td]->uploadhandle = nextuh;
    }
    
    return ft[td]->uploadhandle;
}

-(void) putfa:(SymmCipher*)filekey withhandle:(handle)th andtype:(fatype)t anddata:(const byte*)data andlen:(unsigned)len
{
	// build encrypted file attribute data block
	byte* cdata;
	unsigned clen = (len+SymmCipher::BLOCKSIZE-1)&-SymmCipher::BLOCKSIZE;
    
	cdata = new byte[clen];
    
	memcpy(cdata,data,len);
	memset(cdata+len,0,clen-len);
    
	filekey->cbc_encrypt(cdata,clen);
    
    [newfa addObject:[[HttpReqCommandPutFAWrapper alloc] initWithHandle:th withctype:t withdata:cdata andlen:clen]];
    
	// no other file attribute storage request currently in progress? POST this one.
	if (curfa == -1)
	{
		curfa = 0;
        [reqs[req_sn] add:[newfa objectAtIndex:curfa]];
	}
}

-(void) dlopen:(int)td withfilename:(NSString*)tmpfilename
{
    ft[td]->file = [NSFileHandle fileHandleForWritingAtPath:tmpfilename];
    
    if (ft[td]->file == nil) return [app_wrapper transfer_failed:self withtd:td withfilename:ft[td]->filename witherror:API_EWRITE];
    
    if (ft[td]->size == 0) return [app_wrapper transfer_complete:self withtd:td withchunk:nil withfilename:ft[td]->filename];

}

-(error) putnodes:(handle)h withtargettype:(targettype)t withnewnode:(NSMutableArray *)n
{
    switch (t)
	{
		case USER_HANDLE:
			// FIXME: add support for dropping nodes into other users' inboxes
			break;
            
		case NODE_HANDLE:
            if ([auth lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0 || ISUNDEF(me)) return API_EACCESS;
            
			[reqs[req_sn] add:[[CommandPutNodesWrapper alloc] initWithClient:self withhandle:h withtargettype:t withnewnode:n]];
	}
    
    return API_OK;
}

-(void) setshare:(NodeWrapper*)n touser:(NSString*)user withaccess:(accesslevel)a
{
    [self queuepubkeyreq:[self finduser:user withadd:1] andpubkey_action:[[PubKeyActionCreateShareWrapper alloc] initWithHandle:n->nodehandle andaccesslevel:a]];
}

-(error) exportnode:(NodeWrapper*)n withdel:(int)del
{
    if (![self checkaccess:n andaccess:OWNER]) return API_EACCESS;
    
	// exporting folder - create share
	if (n->type == FOLDERNODE) [self setshare:n touser:nil withaccess:del ? ACCESS_UNKNOWN : RDONLY];
    
	// export node
    if (n->type == FOLDERNODE || n->type == FILENODE) [reqs[req_sn] add:[[CommandSetPHWrapper alloc] initWithClient:self withNode:n anddel:del]];
	else return API_EACCESS;
    
	return API_OK;
}

-(error) openfilelink:(NSString *)link
{
    const char* ptr;
	handle ph = 0;
	byte local_key[FILENODEKEYLENGTH];
    
	if ((ptr = strstr([link UTF8String],"#!"))) ptr += 2;
	else ptr = [link UTF8String];
    
    if ([Base64Wrapper atob:ptr tobytes:(byte*)&ph withlen:8]-(byte*)&ph == 8)
	{
		ptr += 8; // changed, this is buggy in original. atob = 8 means a > 8.
        ptr = strstr(ptr, "!");
        
		if (ptr!=NULL)
		{
            ptr ++;
            if ([Base64Wrapper atob:ptr tobytes:local_key withlen:sizeof(local_key)]-local_key == sizeof(local_key))
			{
                [reqs[req_sn] add:[[CommandGetPHWrapper alloc] initWithClient:self withhandle:ph andkey:local_key]];
				return API_OK;
			}
		}
	}
    
	return API_EARGS;
}

-(void) notifynode:(NodeWrapper *)n
{
    if (!n->notified)
    {
        n->notified = YES;
        [nodenotify addObject:n];
    }
}

-(void) notifyuser:(UserWrapper *)u
{
    [usernotify addObject:u];
}

-(void) notifypurge
{
    @synchronized (nodes)
    {
        int t = [nodenotify count];
        if (t > 0)
        {
            [self applykeys];
            [app_wrapper nodes_updated:self withnodes:nodenotify withcount:t];
        
            NSEnumerator *enumerator = [nodenotify objectEnumerator];
            NodeWrapper* n;
            while (n = [enumerator nextObject]) {
                if (n->removed)
                {
                    [PairWrapper delPair:children withfirst:n->parent andSecond:n->nodehandle];
                    [nodes removeObjectForKey:[NSNumber numberWithUnsignedLongLong:n->nodehandle]];
                }
                else n->notified = NO;
            }
        
            [nodenotify removeAllObjects];
        }
        
        t = [usernotify count];
        if (t > 0)
        {
            [app_wrapper user_updated:self withusers:usernotify withcount:[usernotify count]];
            [usernotify removeAllObjects];
        }
    }
}

-(NodeWrapper*) nodebyhandle:(handle)h
{
    NSNumber* h_num = [NSNumber numberWithUnsignedLongLong:h];
    return (NodeWrapper*)[nodes objectForKey:h_num];
}

-(int) readnodes: (id)jsonresponse withnotify:(int)notify andhandles:(NSArray *)ulhandles
{
    NSError *error;
    id json_obj;
    if ([jsonresponse isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:jsonresponse options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = jsonresponse;
    BOOL is_array = [json_obj isKindOfClass:[NSArray class]];
    if (!is_array)
    {
        return 0;
    }
    NSArray* json_array = (NSArray *)json_obj;
    NSEnumerator *enumerator = [json_array objectEnumerator];
    id obj_item;
    while (obj_item = [enumerator nextObject]) {
        if (![obj_item isKindOfClass:[NSDictionary class]])
        {
            return 0;
        }
        NSDictionary* json_dict = (NSDictionary *)obj_item;
        handle h = UNDEF, p = UNDEF;
        handle u = 0, su = UNDEF;
        nodetype t = TYPE_UNKNOWN;
        NSString* a = nil;
        NSString* k = nil;
        NSString* fa = nil;
        accesslevel r = ACCESS_UNKNOWN;
        const char *sk = NULL;
        size_t s = ~(size_t)0;
        time_t tm = 0, ts = 0;
        int idx = 0;
        for (NSString* dict_key in [json_dict allKeys])
        {
            id value = [json_dict objectForKey:dict_key];
            if ([dict_key isEqualToString:@"h"])
            {
                h = [self convert_base64str_handle:(NSString *)value];
                if (ulhandles && ([ulhandles count] > idx))
                {
                    handle ulhandle_obj = [(NSNumber*)[ulhandles objectAtIndex:idx] longLongValue];
                    if (ulhandle_obj) [PairWrapper addPair:uhnh withfirst:ulhandle_obj andSecond:h];
                    idx ++;
                }
            } else if ([dict_key isEqualToString:@"p"])
            {
                p = [self convert_base64str_handle:(NSString *)value];
            } else if ([dict_key isEqualToString:@"u"])
            {
                u = [self convert_base64str_handle:(NSString *)value];
            } else if ([dict_key isEqualToString:@"t"])
            {
                t = (nodetype)[(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"a"])
            {
                a = [NSString stringWithString:(NSString *)value];
            } else if ([dict_key isEqualToString:@"k"])
            {
                k = [NSString stringWithString:(NSString *)value];
            } else if ([dict_key isEqualToString:@"s"])
            {
                s = [(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"tm"])
            {
                tm = [(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"ts"])
            {
                ts = [(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"fa"])
            {
                fa = [NSString stringWithString:(NSString *)value];
            } else if ([dict_key isEqualToString:@"r"])
            {
                r = (accesslevel)[(NSNumber *)value intValue];
            } else if ([dict_key isEqualToString:@"sk"])
            {
                sk = [(NSString *)value UTF8String];
            } else if ([dict_key isEqualToString:@"su"])
            {
                su = [self convert_base64str_handle:(NSString *)value];
            }
        }
        if (ISUNDEF(h)) [self warn:@"Missing node handle"];
        else
        {
            if (ISUNDEF(*rootnodes)) me = *rootnodes = h;
            
            if (t == TYPE_UNKNOWN) [self warn:@"Unknown node type"];
            else if (t == FILENODE || t == FOLDERNODE)
            {
                if (ISUNDEF(p)) [self warn:@"Missing parent"];
                else if (!a) [self warn:@"Missing node attributes"];
                else if (!k) [self warn:@"Missing node key"];
            
                if (t == FILENODE && ISUNDEF(s)) [self warn:@"File node without file size"];
            }
            else if (t >= ROOTNODE && t <= MAILNODE) rootnodes[t-ROOTNODE] = h;
        }
        
        if (fa && t != FILENODE) [self warn:@"Spurious file attributes"];
        
        if (![self warnlevel])
        {
            NSNumber* h_num = [NSNumber numberWithUnsignedLongLong:h];
            id node_obj = [nodes objectForKey:h_num];
            NodeWrapper* node;
            if (node_obj != nil)
            {
                node = (NodeWrapper *)node_obj;
                if (node->removed)
				{
					// node marked for deletion is being resurrected, possibly with a new parent (server-client move operation)
                    node->removed = NO;
                    [self setparent:node withandle:p];
				}
                
				// node already present - check for race condition
				if (node->parent != p || node->type != t) [app_wrapper reload:self withreason:@"Node inconsistency"];
                
            } else
            {
                ShareWrapper* share = nil;
				byte keybuf[SymmCipher::KEYLENGTH];
                
				if (!ISUNDEF(su))
				{
					if (t != FOLDERNODE) [self warn:@"Invalid share node type"];
					if (r == ACCESS_UNKNOWN) [self warn:@"Missing access level"];
					if (!sk) [self warn:@"Missing share key for inbound share"];
                    
					if (![self warnlevel])
					{
                        share = [[ShareWrapper alloc] initWithuser:[self finduser:su withnew:1] access:r andtime:ts];
                        [self decryptkey:sk withtk:keybuf withtl:sizeof(keybuf) withsc:&key withtype:1 withnode:h];
					}
				}
                
				NodeWrapper* node = [[NodeWrapper alloc] initWithHandle:h parent:p withtype:t withsize:s withowner:u withattrstr:a withkeystr:k withfileattrstr:fa withmodtime:tm withcreatetime:ts withshare:share];
                [nodes setObject:node forKey:h_num];
                
                if (notify) [self notifynode:node];
                
                if (ISUNDEF(p)) [PairWrapper addPair:children withfirst:p andSecond:h];
                
                if (share != nil)
				{
                    
					[share->user->sharing addObject:h_num];
					node->sharekey = new SymmCipher();
					node->sharekey->setkey(keybuf);
				}
            }
        }
    }
    return 1;
}

-(int) readshares: (id)j withmode:(sharereadmode)mode andnotify:(int)notify
{
    NSError *error;
    id json_obj;
    if ([j isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:j options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = j;
    BOOL is_array = [json_obj isKindOfClass:[NSArray class]];
    if (!is_array)
    {
        return 0;
    }
    NSArray* json_array = (NSArray *)json_obj;
    NSEnumerator *enumerator = [json_array objectEnumerator];
    id obj_item;
    while (obj_item = [enumerator nextObject]) {
        if (![obj_item isKindOfClass:[NSDictionary class]])
        {
            return 0;
        }
        [self readshare:obj_item withmode:mode andnotify:notify];
    }
    return 1;
}

-(void) readshare: (id)j withmode:(sharereadmode)mode andnotify:(int)notify
{
    NSError *error;
    id json_obj;
    if ([j isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:j options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = j;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    handle h = UNDEF;
	accesslevel r = ACCESS_UNKNOWN;
	byte ha[SymmCipher::BLOCKSIZE];
	int have_ha = 0;
	time_t ts = 0;
	handle u = UNDEF, o = UNDEF;
	const char* k = NULL;
	const char* ok = NULL;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"n"]||[dict_key isEqualToString:@"h"])
        {
            h = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"o"])
        {
            o = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"u"])
        {
            if ([(NSString *)value isEqualToString:@"EXP"])
            {
                u = 0;
            } else
            {
                u = [self convert_base64str_handle:(NSString *)value];
            }
        } else if ([dict_key isEqualToString:@"r"])
        {
            r = (accesslevel)[(NSNumber *)value intValue];
        } else if ([dict_key isEqualToString:@"k"])
        {
            k = [(NSString *)value UTF8String];
        } else if ([dict_key isEqualToString:@"ha"])
        {
            have_ha = ([Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:ha withlen:sizeof(ha)]-ha)==sizeof(ha);
        } else if ([dict_key isEqualToString:@"ok"])
        {
            ok = [(NSString *)value UTF8String];
        } else if ([dict_key isEqualToString:@"ts"])
        {
            ts = [(NSNumber *)value intValue];
        }
    }
    
    if (ISUNDEF(h))
	{
        [app_wrapper debug_log:self withmsg:@"Missing outgoing share handle"];
        return;
	}
	
	NodeWrapper* n;
    
	if (!(n = [self nodebyhandle:h]))
	{
		[app_wrapper debug_log:self withmsg:@"Outgoing share on unknown node - ignoring"];
		return;
	}
    
	if (have_ha)
	{
        // check if an alleged outgoing share is legit
        byte authbuf[SymmCipher::BLOCKSIZE];
        
        [self handleauth:h withauth:authbuf];
        
        if (memcmp(ha, authbuf, sizeof(authbuf)))
        {
            [app_wrapper debug_log:self withmsg:@"Invalid outgoing share signature"];
            return;
        }
	}
    
	if (mode == SHAREOWNERKEY)
	{
		if (have_ha)
		{
			n->sharekey = new SymmCipher();
			[self setkey:n->sharekey withkey:k];
			n->outshare = 1;
		}
		else [app_wrapper debug_log:self withmsg:@"Invalid share owner key"];
        
		return;
	}
    
	if (ISUNDEF(u))
	{
		[app_wrapper debug_log:self withmsg:@"Missing peer user"];
        return;
	}
    
	if (mode == OUTSHARE)
	{
		if (!n->outshare)
		{
			[app_wrapper debug_log:self withmsg:@"Outgoing share without share owner key"];
			return;
		}
		
		o = me;
	}
    
	if (r == ACCESS_UNKNOWN)
	{
		// share was deleted (n, o, u)
		if (o == me)
		{
			// outgoing share to user u
            NSNumber* u_num = [NSNumber numberWithUnsignedLongLong:u];
			[n->outshares removeObjectForKey:u_num];
            [self notifynode:n];
		}
		else if (u == me)
		{
            TreeProcDelWrapper* td = [[TreeProcDelWrapper alloc] init];
            [self proctree:n withproc:td];
			[self notifypurge];
		}
		else [app_wrapper debug_log:self withmsg:@"Unrelated share deletion"];
	}
    
	if (mode == SHARE)
	{
		if (!k && ok) k = ok;
        
		if (!k)
		{
			[app_wrapper debug_log:self withmsg:@"Missing share key"];
			return;
		}
        
		if (!n->sharekey)
		{
			n->sharekey = new SymmCipher();
            [self setkey:n->sharekey withkey:k];
		}
		else
		{
			[app_wrapper debug_log:self withmsg:@"Share key overwrite foiled"];
			return;
		}
	}
    
	if (o == me)
	{
		if (n->outshare)
		{
			// add outgoing share to peer u
            NSNumber* u_num = [NSNumber numberWithUnsignedLongLong:u];
            id share_obj = [n->outshares objectForKey:u_num];
            if (share_obj == nil)
            {
                [n->outshares setObject:[[ShareWrapper alloc] initWithuser:[self finduser:u withnew:1] access:r andtime:ts] forKey:u_num];
            } else
            {
                [(ShareWrapper *)share_obj update:r withtime:ts];
            }            
		}
		else
		{
			[app_wrapper debug_log:self withmsg:@"Invalid outbound share notification"];
			exit(0);
		}
	}
	else
	{
		// add incoming share from peer o
		n->inshare = [[ShareWrapper alloc] initWithuser:[self finduser:o withnew:1] access:r andtime:ts];
	}
    
	if (notify)
    {
        [self notifynode:n];
    }
}

-(void) proccr:(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_array = [json_obj isKindOfClass:[NSArray class]];
    if (!is_array)
    {
        [app_wrapper debug_log:self withmsg:@"Malformed CR - outer array"];
        return;
    }
    NSArray* json_array = (NSArray *)json_obj;
    
    NSMutableArray *local_shares, *local_nodes;
    handle h;
    
    NSMutableArray* response;
    
    local_shares = [NSMutableArray array];
    local_nodes = [NSMutableArray array];
    response = [NSMutableArray array];
    
    if ([json_array count] < 3)
        return;
    
    id inner_obj = [json_array objectAtIndex:0];
    if (![inner_obj isKindOfClass:[NSArray class]])
    {
        return;
    }
    NSArray* inner_array = (NSArray *)inner_obj;
    
    NSEnumerator *enumerator = [inner_array objectEnumerator];
    id obj_item;
    while (obj_item = [enumerator nextObject]) {
        if (![obj_item isKindOfClass:[NSString class]])
            break;
        h = [self convert_base64str_handle:(NSString *)obj_item];
        if (!ISUNDEF(h)) [local_shares addObject:[self nodebyhandle:h]];
        else break;
    }
    
    inner_obj = [json_array objectAtIndex:1];
    if (![inner_obj isKindOfClass:[NSArray class]])
    {
        [app_wrapper debug_log:self withmsg:@"Malformed CR - nodes part"];
        return;
    }
    inner_array = (NSArray *)inner_obj;
    
    enumerator = [inner_array objectEnumerator];
    while (obj_item = [enumerator nextObject]) {
        if (![obj_item isKindOfClass:[NSString class]])
            break;
        h = [self convert_base64str_handle:(NSString *)obj_item];
        if (!ISUNDEF(h)) [local_nodes addObject:[self nodebyhandle:h]];
        else break;
    }
    
    inner_obj = [json_array objectAtIndex:2];
    if (![inner_obj isKindOfClass:[NSArray class]])
    {
        [app_wrapper debug_log:self withmsg:@"Malformed CR - linkage part"];
        return;
    }
    inner_array = (NSArray *)inner_obj;
    [self cr_response:local_shares withnodes:local_nodes anddata:inner_array];
}

-(void) procsr:(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_array = [json_obj isKindOfClass:[NSArray class]];
    if (!is_array)
    {
        return;
    }
    NSArray* json_array = (NSArray *)json_obj;
    
    int last_count = [json_array count];
    
    handle sh, uh;
    
    for (int idx = 0; idx < last_count; idx += 2)
    {
        if (idx == last_count - 1)
        {
            break;
        }
        sh = [self convert_base64str_handle:(NSString *)[json_array objectAtIndex:idx]];
        uh = [self convert_base64str_handle:(NSString *)[json_array objectAtIndex:idx+1]];
        if (!ISUNDEF(sh) && !ISUNDEF(uh))
        {
            UserWrapper* u;
            
            if ([self nodebyhandle:sh] && (u=[self finduser:uh withnew:0]))
            {
                [self queuepubkeyreq:u andpubkey_action:[[PubKeyActionSendShareKeyWrapper alloc] initWithHandle:sh]];
            }
        }
    }
}

-(int) applykeys
{
    int t = 0;
    
    for (id node_key in [nodes allKeys])
    {
        id value = [nodes objectForKey:node_key];
        if (value == nil)
        {
            [app_wrapper debug_log:self withmsg:@"NULL node detected!"];
            continue;
        }
        NodeWrapper* node_value = (NodeWrapper *)value;
        [node_value applykey:self with:[(NSNumber*)node_key unsignedLongLongValue]];
    }
    
    if ([sharekeyrewrite count])
    {
        [reqs[req_sn] add:[[CommandShareKeyUpdateWrapper alloc] initWithClient:self andhandlevalue:sharekeyrewrite]];
        [sharekeyrewrite removeAllObjects];
    }
    
    if ([nodekeyrewrite count])
    {
        [reqs[req_sn] add:[[CommandNodeKeyUpdateWrapper alloc] initWithClient:self andhandlevalue:nodekeyrewrite]];
        [nodekeyrewrite removeAllObjects];
    }
        
	return t;
}

-(void) setparent:(NodeWrapper*)n withandle:(handle)h
{
    [PairWrapper delPair:children withfirst:n->parent andSecond:n->nodehandle];
    [PairWrapper addPair:children withfirst:h andSecond:n->nodehandle];
    
    n->parent = h;
    [self notifynode:n];
}

-(UserWrapper *) finduser:(NSString*)uid withadd:(int)add
{
    if (!uid|| [uid lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) return nil;
    
    if ([uid rangeOfString:@"@"].location == NSNotFound)
    {
        // not an e-mail address: must be ASCII handle
		handle uh;
        
        if (([Base64Wrapper atob:[uid UTF8String] tobytes:(byte*)&uh withlen:sizeof uh]-(byte*)&uh) == sizeof uh) return [self finduser:uh withnew:add];
		return nil;
    }
    
    NSString* nuid;
    UserWrapper* u;
    
    [NodeWrapper copystring:nuid from:[uid UTF8String]];
    nuid = [nuid lowercaseString];
    
    id um_obj = [umindex objectForKey:nuid];
    
    if (um_obj == nil)
    {
        if (!add) return nil;
        
        u = [[UserWrapper alloc] initWithemail:nil];
        [users setObject:u forKey:[NSNumber numberWithInt:(++userid)]];
        u->uid = nuid;
        [NodeWrapper copystring:u->email from:[uid UTF8String]];
        [umindex setObject:[NSNumber numberWithInt:userid] forKey:nuid];
        
        return u;
    }
    
    return [users objectForKey:um_obj];
}

-(UserWrapper *) finduser:(handle)uh withnew:(int)add
{
    char uid1[12];
    [Base64Wrapper btoa:(byte*)&uh oflength:sizeof uh tobuf:uid1];
    uid1[11] = 0;
    
    UserWrapper* u;
    
    id uh_obj = [uhindex objectForKey:[NSNumber numberWithUnsignedLongLong:uh]];
    
    if (uh_obj == nil)
    {
        if (!add) return nil;
        
        u = [[UserWrapper alloc] initWithemail:nil];
        [users setObject:u forKey:[NSNumber numberWithInt:(++userid)]];
        
        char uid[12];
        [Base64Wrapper btoa:(byte*)&uh oflength:sizeof uh tobuf:uid];
        uid[11]=0;

        u->uid = [NSString stringWithUTF8String:uid];
        [uhindex setObject:[NSNumber numberWithInt:userid] forKey:[NSNumber numberWithUnsignedLongLong:uh]];
        
        return u;
    }
    
    return [users objectForKey:uh_obj];
}

-(void) mapuser:(handle)uh withemail:(NSString *)email
{
    if ([email lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) return;
    
    UserWrapper* u;
    NSString* nuid;
    
    [NodeWrapper copystring:nuid from:[email UTF8String]];
    nuid = [nuid lowercaseString];

    id uh_obj = [uhindex objectForKey:[NSNumber numberWithUnsignedLongLong:uh]];
    
    if (uh_obj != nil)
    {
       
        u = [users objectForKey:uh_obj];
        if ([u->email lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0)
        {
            [NodeWrapper copystring:u->email from:[email UTF8String]];
            [umindex setObject:uh_obj forKey:nuid];
        }
        
        return;
    }
    
    id um_obj = [umindex objectForKey:nuid];
    
    if (um_obj != nil)
    {
        
        u = [users objectForKey:um_obj];
        [uhindex setObject:um_obj forKey:[NSNumber numberWithUnsignedLongLong:uh]];
        
        char uid[12];
        [Base64Wrapper btoa:(byte*)&uh oflength:sizeof uh tobuf:uid];
        uid[11]=0;
        
        u->uid = [NSString stringWithUTF8String:uid];
        return;
    }
}

-(void) queuepubkeyreq:(UserWrapper *)u andpubkey_action:(PubKeyActionWrapper *)pka
{
    if (!u || u->pubk.isvalid())
	{
        [pka proc:self anduser:u];
	}
	else
	{
        [u->pkrs addObject:pka];
	 	if (!u->pubkrequested) [reqs[req_sn] add:[[CommandPubKeyRequestWrapper alloc] initWithClient:self anduser:u]];
	}
}

-(void) stringhash:(const char*)s withhash:(byte*)hash andcipher:(SymmCipher*)cipher
{
    int t;
    
	t = strlen(s) & -SymmCipher::BLOCKSIZE;
    
	strncpy((char*)hash,s+t,SymmCipher::BLOCKSIZE);
	
	while (t)
	{
		t -= SymmCipher::BLOCKSIZE;
		SymmCipher::xorblock((byte*)s+t,hash);
	}
    
	for (t = 16384; t--; ) cipher->ecb_encrypt(hash);
    
	memcpy(hash+4,hash+8,4);
}

-(void) pw_key:(const char*)pw withkey:(byte*)pwkey
{
    int t = strlen(pw);
	int n = (t+15)/16;
	SymmCipher* keys = new SymmCipher[n];
	
	for (int i = 0; i < n; i++)
	{
		strncpy((char*)pwkey,pw+i*SymmCipher::BLOCKSIZE,SymmCipher::BLOCKSIZE);
		keys[i].setkey(pwkey);
	}
    
	memcpy(pwkey,"\x93\xC4\x67\xE3\x7D\xB0\xC7\xA4\xD1\xBE\x3F\x81\x01\x52\xCB\x56",SymmCipher::BLOCKSIZE);
    
	for (int r = 65536; r--; )
		for (int i = 0; i < n; i++)
			keys[i].ecb_encrypt(pwkey);
}

-(void) setsid:(const char*)sid
{
    auth = [NSMutableString stringWithString:@"&sid="];
    [auth appendString:[NSString stringWithUTF8String:sid]];
}

-(void) setrootnode:(handle)h
{
    char buf[12];
    
    [Base64Wrapper btoa:(byte*)&h oflength:6 tobuf:buf];
    
    auth = [NSMutableString stringWithString:@"&n="];
    [auth appendString:[NSString stringWithUTF8String:buf]];
}

-(handle) convert_base64str_handle: (NSString *)stringvalue
{
    handle handle_data;
    [Base64Wrapper atob:[stringvalue UTF8String] tobytes:(byte *)&handle_data withlen:8];
    return handle_data;
}

-(void) procsc
{
    NSError* error;
    id json_obj = [NSJSONSerialization JSONObjectWithData:jsonsc options:NSJSONReadingMutableLeaves error:&error];
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"w"])
        {
            scnotifyurl = (NSString *)value;
        } else if ([dict_key isEqualToString:@"a"])
        {
            if ([value isKindOfClass:[NSArray class]])
            {
                NSArray* value_array = (NSArray *)value;
                NSEnumerator *enumerator = [value_array objectEnumerator];
                id obj_item;
                while (obj_item = [enumerator nextObject]) {
                    if ([obj_item isKindOfClass:[NSDictionary class]])
                    {
                        NSDictionary* inner_dict = (NSDictionary *)obj_item;
                        NSDictionary* copy_inner_dict = [NSDictionary dictionaryWithDictionary:inner_dict];
                        for (NSString* inner_key in [inner_dict allKeys])
                        {
                            id inner_value = [inner_dict objectForKey:inner_key];
                            if ([inner_key isEqualToString:@"a"])
                            {
                                NSString* inner_value_str = (NSString *)inner_value;
                                if ([inner_value_str isEqualToString:@"u"])
                                {
                                    // node update
                                    [self sc_updatenode:copy_inner_dict];
                                } else if ([inner_value_str isEqualToString:@"t"])
                                {
                                    // node addition
                                    [self sc_newnodes:copy_inner_dict];
                                    [self mergenewshares];
                                    [self applykeys];
                                } else if ([inner_value_str isEqualToString:@"d"])
                                {
                                    // node deletion
                                    [self sc_deltree:copy_inner_dict];
                                } else if ([inner_value_str isEqualToString:@"s"])
                                {
                                    // share addition/update/revocation
                                    [self sc_shares:copy_inner_dict];
                                } else if ([inner_value_str isEqualToString:@"c"])
                                {
                                    // contact addition/update
                                    [self sc_contacts:copy_inner_dict];
                                } else if ([inner_value_str isEqualToString:@"k"])
                                {
                                    // crypto key request
                                    [self sc_keys:copy_inner_dict];
                                } else if ([inner_value_str isEqualToString:@"fa"])
                                {
                                    // file attribute update
                                }
                            }
                        }
                    }
                }
                
            }
        }  else if ([dict_key isEqualToString:@"sn"])
        {
            scsn = (NSString*)value;
        }
    }
    
    [self notifypurge];
}

-(void) sc_updatenode :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;

	handle h = UNDEF;
	handle u = 0;
	const char* a = NULL;
	const char* k = NULL;
	time_t ts = 0;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"n"])
        {
            h = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"u"])
        {
            u = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"at"])
        {
            a = [(NSString *)value UTF8String];
        } else if ([dict_key isEqualToString:@"k"])
        {
            k = [(NSString *)value UTF8String];
        } else if ([dict_key isEqualToString:@"cr"])
        {
            [self proccr:value];
        } else if ([dict_key isEqualToString:@"ts"])
        {
            ts = [(NSNumber *)value intValue];
        }
    }
    
    if (!ISUNDEF(h))
    {
        NodeWrapper* n = [self nodebyhandle:h];
        if (n == nil)
        {
            return;
        }
    
        if (u) n->owner = u;
        if (a) [NodeWrapper copystring:n->attrstring from:a];
        if (k) [NodeWrapper copystring:n->keystring from:k];
        if (ts+1) n->mtime = ts;
    
        [n applykey:self with:h];
    
        [self notifynode:n];
    }
}

-(void) readtree :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"f"])
        {
            [self readnodes:value withnotify:1 andhandles:nil];
        } else if ([dict_key isEqualToString:@"u"])
        {
            [self readusers:value];
        }
    }
}

-(void) sc_deltree :(id)json_data
{
    handle h = UNDEF;
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"n"])
        {
            h = [self convert_base64str_handle:(NSString *)value];
        }
    }
    
    if (!ISUNDEF(h))
    {
        NodeWrapper* n;
        
        if ((n = [self nodebyhandle:h]))
        {
            TreeProcDelWrapper* td = [[TreeProcDelWrapper alloc] init];
            [self proctree:n withproc:td];
        }
    }
}

-(void) sc_newnodes :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
       
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"t"])
        {
            [self readtree:value];
        } else if ([dict_key isEqualToString:@"u"])
        {
            [self readusers:value];
        }
    }
}

-(void) sc_shares :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    handle h = UNDEF;
	handle oh = UNDEF;
	handle uh = UNDEF;
	const char* k = NULL;
	byte ha[SymmCipher::BLOCKSIZE];
	int have_ha = 0;
	accesslevel r = ACCESS_UNKNOWN;
	time_t ts = 0;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"n"])
        {
            h = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"o"])
        {
            oh = [self convert_base64str_handle:(NSString *)value];
        } else if ([dict_key isEqualToString:@"u"])
        {
            if ([(NSString *)value isEqualToString:@"EXP"])
            {
                uh = 0;
            } else
            {
                uh = [self convert_base64str_handle:(NSString *)value];
            }
        } else if ([dict_key isEqualToString:@"ok"])
        {
            k = [(NSString *)value UTF8String];
        } else if ([dict_key isEqualToString:@"ha"])
        {
            have_ha = [Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:ha withlen:sizeof(ha)]-ha == sizeof(ha);
        } else if ([dict_key isEqualToString:@"r"])
        {
            r = (accesslevel)[(NSNumber *)value intValue];
        } else if ([dict_key isEqualToString:@"ts"])
        {
            ts = [(NSNumber *)value intValue];
        } else if ([dict_key isEqualToString:@"k"])
        {
            k = [(NSString *)value UTF8String];
        }
    }

    if (!ISUNDEF(h))
    {
        if (!have_ha)
        {
            if (r == ACCESS_UNKNOWN)
            {
                NodeWrapper* n;
                
                if (!ISUNDEF(oh))
                {
                    if ((n = [self nodebyhandle:h]))
                    {
                        if (k && ISUNDEF(uh))
                        {
                            byte buf[SymmCipher::KEYLENGTH];
                            
                            if (!n->sharekey)
                            {
                                if ([Base64Wrapper atob:k tobytes:buf withlen:sizeof(buf)] - buf != sizeof(buf)) return;
                                n->sharekey = new SymmCipher(buf);
                            }
                        }
                    }
                }
                else
                {
                    if (!k && !ISUNDEF(uh))
                    {
                      
                        if (oh == me)
                        {
                            // outbound share revocation
                            ShareWrapper* share = [n->outshares objectForKey:[NSNumber numberWithUnsignedLongLong:uh]];
                            
                            if (share != nil)
                            {
                                [share removeshare:uh];
                                [n->outshares removeObjectForKey:[NSNumber numberWithUnsignedLongLong:uh]];
                            }
                            else [app_wrapper debug_log:self withmsg:@"Revoked unknown outbound share"];
                            
                            if ([n->outshares count] == 0)
                            {
                                n->outshare = 0;
                                
                                if (n->sharekey)
                                {
                                    delete n->sharekey;
                                    n->sharekey = NULL;
                                    [self notifynode:n];
                                }
                            }
                        }
                        
                        if (uh == me)
                        {
                            // incoming share deleted
                            TreeProcDelWrapper* td = [[TreeProcDelWrapper alloc] init];
                            [self proctree:n withproc:td];
                        }
                    }
                }
            }
        }
        else if (!ISUNDEF(oh) && !ISUNDEF(uh) && have_ha && k && r != ACCESS_UNKNOWN)
        {            
            if (have_ha)
            {
                if (oh == me && uh != me)
                {
                    // new outgoing share: node will always exist
                    NodeWrapper* n;
                    byte authkey[SymmCipher::KEYLENGTH];
                    
                    [self handleauth:h withauth:authkey];
                    
                    if (!memcmp(authkey,ha,sizeof ha))
                    {
                        if ((n = [self nodebyhandle:h]))
                        {
                            if (!n->outshare)
                            {
                                if (!n->sharekey)
                                {
                                    if ([Base64Wrapper atob:k tobytes:authkey withlen:sizeof(authkey)] - authkey != sizeof(authkey)) return;
                                    n->sharekey = new SymmCipher(authkey);
                                }

                                n->outshare = 1;
                            }

                            ShareWrapper* sp;
                            NSNumber* u_num = [NSNumber numberWithUnsignedLongLong:uh];
                        
                            sp = [n->outshares objectForKey:u_num];
                        
                            if (sp == nil)
                            {
                                sp = [[ShareWrapper alloc] initWithuser:[self finduser:uh withnew:1] access:r andtime:ts];
                                [n->outshares setObject:sp forKey:u_num];
                            }
                        }
                        else [app_wrapper debug_log:self withmsg:@"Outgoing share node not found"];

                    }
                    else [app_wrapper debug_log:self withmsg:@"Share signature verification failed"];
                }
                else [app_wrapper debug_log:self withmsg:@"Invalid outgoing share"];
            }
            else
            {
                if (oh != me && uh == me)
                {
                    // new incoming share: node may not exist yet, queue & merge after next "t" CS command
                    byte buf[AsymmCipher::MAXKEYLENGTH];
                    ShareWrapper* s;
                    SymmCipher* sk;
                    NSNumber* h_num = [NSNumber numberWithUnsignedLongLong:h];
                    int sl;
                    
                    sl = [Base64Wrapper atob:k tobytes:buf withlen:sizeof(buf)] - buf;
                    
                    if (asymkey.decrypt(buf,sl,buf,SymmCipher::KEYLENGTH))
                    {
                        sk = new SymmCipher(buf);
                        s = [[ShareWrapper alloc] initWithuser:[self finduser:oh withnew:1] access:r andtime:ts];
                        
                        NodeWrapper* n = [self nodebyhandle:h];
                        if (n != nil)
                        {
                            n->sharekey = sk;
                            n->inshare = s;
                            [s->user->sharing addObject:h_num];
                        }
                        else
                        {
                            [newshares setObject:[[NewShareWrapper alloc] initWithshare:s andsymcipher:sk] forKey:h_num];
                        }
                    }
                    else [app_wrapper debug_log:self withmsg:@"Malformed inbound share key"];
                }
            }
            
        }
    }
}

-(void) sc_contacts :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"u"])
        {
            [self readusers:value];
        }
    }
}

-(void) sc_keys :(id)json_data
{
    NSError *error;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&error];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    handle h;
    NodeWrapper* sn = nil;
    
    for (NSString* dict_key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:dict_key];
        if ([dict_key isEqualToString:@"sr"])
        {
            [self procsr:value];
        } else if ([dict_key isEqualToString:@"h"])
        {
            h = [self convert_base64str_handle:(NSString *)value];
            
            // we only distribute node keys for our own outgoing shares
            if ((sn = [self nodebyhandle:h]) && (!sn->outshare || !sn->sharekey)) sn = NULL;
        } else if ([dict_key isEqualToString:@"n"])
        {
            if ([value isKindOfClass:[NSArray class]])
            {
                NSMutableArray* shares = [NSMutableArray arrayWithObject:sn];
                NSMutableArray* nodesarray = [NSMutableArray array];
                
                NSEnumerator* enumrator = [(NSArray*)value objectEnumerator];
                NSString* inner_str;
                while (inner_str = [enumrator nextObject])
                {
                    h = [self convert_base64str_handle:inner_str];
                    if (!ISUNDEF(h)) [nodesarray addObject:[self nodebyhandle:h]];
                    else break;
                }
                
                [self cr_response:shares withnodes:nodesarray anddata:nil];
            }
        } else if ([dict_key isEqualToString:@"cr"])
        {
            [self proccr:value];
        }
    }
}
    
-(void) mergenewshares
{
    for (id share_key in [newshares allKeys])
    {
        id value = [newshares objectForKey:share_key];
        NSNumber* first = (NSNumber*)share_key;
        NewShareWrapper* share_ptr = (NewShareWrapper *)value;
        id node_obj = [nodes objectForKey:first];
        if (node_obj == nil)
        {
            continue;
        }
        NodeWrapper* n = (NodeWrapper*)node_obj;
        n->inshare = share_ptr->share;
        [n->inshare->user->sharing addObject:first];
        
        if (n->sharekey) delete n->sharekey;
        n->sharekey = share_ptr->sharekey;
        
        [newshares removeObjectForKey:share_key];
    }
}

-(NodeWrapper*) childof:(NodeWrapper*)parent andchild:(NodeWrapper*)child
{
    NodeWrapper* n = child;
    while ((n = [self nodebyhandle:n->parent])) {
        if (n == parent)
        {
            return child;
        }
    }
    
    return nil;
}

-(unsigned) addnode:(NSMutableArray*)v andnode:(NodeWrapper*)n
{
    for (int i = [v count]; i--; ) {
        if ([v objectAtIndex:i] == n) {
            return i;
        }
    }
    [v addObject:n];
    return [v count]-1;
}

-(void) cr_response:(NSMutableArray*)shares withnodes:(NSMutableArray*)local_nodes anddata:(id)selector_obj
{
	NSMutableArray *rshares, *rnodes;
	unsigned si, ni;
	NodeWrapper* sn;
	NodeWrapper* n;
	NSMutableArray* crkeys;
	byte local_key[FILENODEKEYLENGTH];
	char buf[128];
	int setkey = -1;
    
	// for security reasons, we only respond to key requests affecting our own shares
	for (si = [shares count]; si--; ) if ([shares objectAtIndex:si] && (!((NodeWrapper *)[shares objectAtIndex:si])->outshare || !((NodeWrapper *)[shares objectAtIndex:si])->sharekey))
	{
        [app_wrapper debug_log:self withmsg:@"Attempt to obtain node key for invalid/third-party share foiled"];
        [shares replaceObjectAtIndex:si withObject:[NSNull null]];
	}
    
    NSArray* selector = nil;
    int selector_idx = 0;
	if (!selector_obj) si = ni = 0;
    else
    {
        NSError* error;
        if ([selector_obj isKindOfClass:[NSData class]])
        {
            selector = [NSJSONSerialization JSONObjectWithData:selector_obj options:NSJSONReadingMutableLeaves error:&error];
        } else if ([selector_obj isKindOfClass:[NSArray class]])
        {
            selector = selector_obj;
        }
    }
    
	for (;;)
	{
		if (selector)
		{
			// walk selector, detect errors/end by checking if the JSON position advanced
            if (selector_idx >= [selector count])
            {
                break;
            }
			
			si = [(NSNumber *)[selector objectAtIndex:selector_idx] unsignedIntValue];
			selector_idx ++;
            
            
            if (selector_idx >= [selector count])
            {
                break;
            }
            
			ni = [(NSNumber *)[selector objectAtIndex:selector_idx] unsignedIntValue];
            selector_idx ++;
            
			if (si >= [shares count])
			{
                [app_wrapper debug_log:self withmsg:@"Share index out of range"];
				return;
			}
            
			if (ni >= [local_nodes count])
			{
				[app_wrapper debug_log:self withmsg:@"Node index out of range"];
				return;
			}
            
            if (selector_idx >= [selector count])
            {
                break;
            }
            
			if ([[selector objectAtIndex:selector_idx] isKindOfClass:[NSString class]])
            {
                NSString* selector_str = [selector objectAtIndex:selector_idx];
                setkey = [Base64Wrapper atob:[selector_str UTF8String] tobytes:local_key withlen:sizeof(local_key)] - local_key;
                selector_idx ++;
            }
		}
		else
		{
			// no selector supplied
			ni++;
            
			if (ni >= [local_nodes count])
			{
				ni = 0;
				if (++si >= [shares count]) break;
			}
		}
        
        sn = [shares objectAtIndex:si];
        n = [local_nodes objectAtIndex:ni];
		if (![sn isEqual:[NSNull null]] && ![n isEqual:[NSNull null]])
		{
		 	if ([self childof:sn andchild:n])
			{
				if (setkey >= 0)
				{
					if (setkey == n->keylen)
					{
						sn->sharekey->ecb_decrypt(local_key,n->keylen);
                        [n setkey:local_key];
						setkey = -1;
					}
				}
				else
				{
					unsigned nsi, nni;
                    
					nsi = [self addnode:rshares andnode:sn];
                    nni = [self addnode:rnodes andnode:n];
                    
                    //We don't need this as crkeys is an NSMutableArray
					//sprintf(buf,"\",%u,%u,\"",nsi,nni);
                    
					// generate & queue share nodekey
					sn->sharekey->ecb_encrypt(n->nodekey,local_key,n->keylen);
                    [Base64Wrapper btoa:local_key oflength:n->keylen tobuf:buf];
                    [crkeys addObject:[NSNumber numberWithUnsignedInt:nsi]];
                    [crkeys addObject:[NSNumber numberWithUnsignedInt:nni]];
                    [crkeys addObject:[NSString stringWithUTF8String:buf]];
				}
			}
			else [app_wrapper debug_log:self withmsg:@"Attempt to obtain key of node outside share foiled"];
		}
	}
    
	if ([crkeys count])
	{
        [reqs[req_sn] add:[[CommandKeyCRWrapper alloc] initWithClient:self andsharearray:rshares andsharenode:rnodes andArraykey:crkeys]];
	}
}

-(void) warn: (NSString *)msg
{
    [app_wrapper debug_log:self withmsg:msg];
    warned = 1;
}

-(int) warnlevel
{
    return warned ? (warned = 0) | 1 : 0;
}

-(void) proctree:(NodeWrapper *)n withproc:(TreeProcWrapper *)tp
{
    if (n->type != FILENODE)
    {
        handle h = n->nodehandle;
        NodeWrapper* nn;
        
        NSMutableOrderedSet* child_set = [children objectForKey:[NSNumber numberWithUnsignedLongLong:h]];
        
        if (child_set)
        {
            NSEnumerator* enumerator = [child_set objectEnumerator];
            NSNumber* child_num;
            while ((child_num = [enumerator nextObject])) {
                handle child_handle = [child_num unsignedLongLongValue];
                nn = [self nodebyhandle:child_handle];
                if (nn)
                {
                    [self proctree:nn withproc:tp];
                }
            }
        }
    }
    
    [tp proc:self andnode:n];
}

-(void) setkey:(SymmCipher*)c withkey:(const char*)k
{
    byte newkey[SymmCipher::KEYLENGTH];
	
    if ([Base64Wrapper atob:k tobytes:newkey withlen:sizeof(newkey)]-newkey == sizeof(newkey))
	{
		key.ecb_decrypt(newkey);
		c->setkey(newkey);
	}
}

-(int) decryptkey: (const char*)sk withtk:(byte*)tk withtl:(int)tl withsc:(SymmCipher*)sc withtype:(int)type withnode:(uint64_t)node
{
	int sl;
	const char* ptr = sk;
    
	// measure key length
	while (*ptr)
	{
		if (*ptr == '"' || *ptr == '/') break;
		else if (*ptr == ':')
		{
			// @@@ add handling
			printf("Compound share key: %.120s\n",sk);
		}
		ptr++;
	}
	
	sl = ptr-sk;
    
	if (sl > 4*FILENODEKEYLENGTH/3+1)
	{
		// RSA-encrypted key - decrypt and update on the server to save CPU time next time
		sl = sl/4*3+3;
        
		if (sl > 4096) return 0;
		
		byte* buf = new byte[sl];
        
        sl = [Base64Wrapper atob:sk tobytes:buf withlen:sl] - buf;
        
		// decrypt and set session ID for subsequent API communication
		if (!asymkey.decrypt(buf,sl,tk,tl))
		{
			delete[] buf;
			[app_wrapper debug_log:self withmsg:@"Corrupt or invalid RSA node key detected"];
			return 0;
		}
        
		delete[] buf;
        
        NSNumber* node_num = [NSNumber numberWithUnsignedLongLong:node];
        
		if (type) [sharekeyrewrite addObject:node_num];
		else [nodekeyrewrite addObject:node_num];
	}
	else
	{
        if ([Base64Wrapper atob:sk tobytes:tk withlen:tl]-tk != tl)
		{
            [app_wrapper debug_log:self withmsg:@"Corrupt or invalid symmetric node key"];
			return 0;
		}
        
		sc->ecb_decrypt(tk,tl);
	}
	
	return 1;
}

-(void) handleauth:(handle)h withauth:(byte *)authbuf
{
    [Base64Wrapper btoa:(byte*)&h oflength:6 tobuf:(char *)authbuf];
	memcpy(authbuf+8,authbuf,8);
    
	key.ecb_encrypt(authbuf);
}

@end

@implementation PairWrapper

+(void) addPair:(NSMutableDictionary *)container withfirst:(handle)first_obj andSecond:(handle)second_obj
{
    NSMutableOrderedSet* set_obj = [container objectForKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
    if (set_obj == nil)
    {
        [container setObject:[NSMutableOrderedSet orderedSetWithObject:[NSNumber numberWithUnsignedLongLong:second_obj]] forKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
    } else {
        [set_obj addObject:[NSNumber numberWithUnsignedLongLong:second_obj]];
    }
}

+(void) delPair:(NSMutableDictionary *)container withfirst:(handle)first_obj andSecond:(handle)second_obj
{
    NSMutableOrderedSet* set_obj = [container objectForKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
    if (set_obj != nil)
    {
        [set_obj removeObject:[NSNumber numberWithUnsignedLongLong:second_obj]];
        if ([set_obj count] == 0)
        {
            [container removeObjectForKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
        }
    }
}

+(void) addPendingfa:(NSMutableDictionary *)container withfirst:(handle)first_obj andSecond:(uint16_t)second_obj andThird:(handle)third_obj
{
    NSMutableDictionary* dict_obj = [container objectForKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
    if (dict_obj != nil)
    {
        [dict_obj setObject:[NSNumber numberWithUnsignedLongLong:third_obj] forKey:[NSNumber numberWithUnsignedShort:second_obj]];
    } else
    {
        [container setObject:[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLongLong:third_obj] forKey:[NSNumber numberWithUnsignedShort:second_obj]] forKey:[NSNumber numberWithUnsignedLongLong:first_obj]];
    }
}

@end