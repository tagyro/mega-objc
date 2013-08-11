//
//  CommandWrapper.m
//  testioslib
//

#import "CommandWrapper.h"
#import "MegaClientWrapper.h"
#import "Base64Wrapper.h"
#import "NodeWrapper.h"
#import "UserWrapper.h"
#import "RequestWrapper.h"
#import "FileTransferWrapper.h"
#import "PubKeyActionWrapper.h"
#import "TreeProcWrapper.h"
#import "AccountWrapper.h"

@implementation CommandWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    json = [NSMutableDictionary dictionary];
        
    return self;
}

-(void) cmd:(NSString*)cmd
{
    [json setValue:cmd forKey:@"a"];
}

-(void) arg_str:(NSString*)name withstr:(NSString*)value
{
    [json setValue:[NSString stringWithString:value] forKey:name];
}

-(void) arg_num:(NSString*)name withnum:(NSNumber*)value
{
    [json setValue:value forKey:name];
}

-(void) arg_bin:(NSString*)name withbuf:(const byte*)value andlen:(int)len
{
    char* buf = new char[len*4/3+4];
    
    [Base64Wrapper btoa:value oflength:len tobuf:buf];
    
    NSString* buf_str = [NSString stringWithUTF8String:buf];
    
	[json setValue:buf_str forKey:name];
    
	delete[] buf;
}

-(NSString *) element:(byte *)value andlen:(int)len
{
    char* buf = new char[len*4/3+4];
    
    [Base64Wrapper btoa:value oflength:len tobuf:buf];
    
    NSString* buf_str = [NSString stringWithUTF8String:buf];
       
	delete[] buf;
    
    return buf_str;
}

-(void) arg_array:(NSString*)name witharray:(NSMutableArray*)array
{
    [json setValue:[NSArray arrayWithArray:array] forKey:name];
}

-(void) arg_dict:(NSString*)name withdic:(NSMutableDictionary*)dict
{
    [json setValue:[NSDictionary dictionaryWithDictionary:dict] forKey:name];
}

-(void) notself:(MegaClientWrapper *)client
{
    [json setValue:[NSString stringWithUTF8String:client->sessionid] forKey:@"i"];
}

-(NSMutableDictionary *) getdict
{
    return json;
}

@end

@implementation HttpReqCommandPutFAWrapper

-(id) initWithHandle:(handle)cth withctype:(fatype)ctype withdata:(byte*)cdata andlen:(unsigned)clen
{
    if (!(self = [super init]))
        return nil;
    
    th = cth;
	type = ctype;
	data = cdata;
	len = clen;
    
    http_req = [[HttpRequestWrapper alloc] init];
    http_req->direction = 3;
    
    [self cmd:@"ufa"];
    [self arg_num:@"s" withnum:[NSNumber numberWithUnsignedInt:len]];
    
    return self;
}

-(void) dealloc
{
    if (NULL != data)
    {
        delete[] data;
    }
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        http_req->status = REQ_FAILURE;
        return;
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
	NSString* p = nil;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"p"])
        {
            p = (NSString *)value;
        }
    }
    
    if (!p)
    {
        http_req->status = REQ_FAILURE;
    } else
    {
        [NodeWrapper copystring:http_req->posturl from:[p UTF8String]];
        [http_req post:client isbulk:1 withdata:(char*)data andlen:len];
    }
}

-(void) sethandle:(MegaClientWrapper*)client withhandle:(handle)fah
{
    NodeWrapper* n;
	handle h;
	NSMutableOrderedSet* inner_set;
    
	// do we have a valid upload handle?
	h = th;
    
	inner_set = [client->uhnh objectForKey:[NSNumber numberWithUnsignedLongLong:h]];
    
	if (inner_set) h = [(NSNumber *)[inner_set objectAtIndex:0] unsignedLongLongValue];
    
	// are we updating a live node? issue command directly. otherwise, queue for processing upon upload completion.
	if ((n = [client nodebyhandle:h]) || (n = [client nodebyhandle:th]))
	{
		// decrypt & store encrypted data
		n->key.cbc_decrypt(data,len);
		[client->fileattrs setObject:[NSData dataWithBytes:data length:len] forKey:[NSNumber numberWithUnsignedLongLong:fah]];
        
        [PairWrapper addPair:n->fileattrs withfirst:type andSecond:fah];
        [client->reqs[client->req_sn] add:[[CommandAttachFAWrapper alloc] initWithNode:n]];
	}
	else [PairWrapper addPendingfa:client->pendingfa withfirst:th andSecond:type andThird:fah];
}

@end

@implementation CommandLoginWrapper

-(id) initWithClient:(MegaClientWrapper*)client andemail:(NSString*)e andemailhash:(byte *)emailhash
{
    if (!(self = [super init]))
        return nil;
       
    [self cmd:@"us"];
    [self arg_str:@"user" withstr:e];
    [self arg_bin:@"uh" withbuf:emailhash andlen:8];
    
    return self;

}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        int err_code = [(NSNumber *)json_obj intValue];
        return [client->app_wrapper login_result:client witherror:(error)err_code];
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
	byte hash[SymmCipher::KEYLENGTH];
	byte sidbuf[AsymmCipher::MAXKEYLENGTH];
	byte privkbuf[AsymmCipher::MAXKEYLENGTH*2];
	int len_k = 0, len_privk = 0, len_csid = 0;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"k"])
        {
            len_k = [Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:hash withlen:sizeof(hash)] - hash;
        } else if ([key isEqualToString:@"csid"])
        {
            len_csid = [Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:sidbuf withlen:sizeof(sidbuf)] - sidbuf;
        } else if ([key isEqualToString:@"privk"])
        {
            len_privk = [Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:privkbuf withlen:sizeof(privkbuf)] - privkbuf;
        }
    }
    
    if (len_k != sizeof(hash) || len_csid < 32 || len_privk < 256) return [client->app_wrapper login_result:client witherror:API_EINTERNAL];
    
    // decrypt master key
    client->key.ecb_decrypt(hash);
    client->key.setkey(hash);
    
    // decrypt and decode private key
    client->key.ecb_decrypt(privkbuf,len_privk);
    if (!client->asymkey.setkey(AsymmCipher::PRIVKEY,privkbuf,len_privk)) return [client->app_wrapper login_result:client witherror:API_EKEY];
    
    // decrypt and set session ID for subsequent API communication
    if (!client->asymkey.decrypt(sidbuf,len_csid,sidbuf,43)) return [client->app_wrapper login_result:client witherror:API_EINTERNAL];
    
    [Base64Wrapper btoa:sidbuf oflength:43 tobuf:(char *)privkbuf];
    
    [client setsid:(char*)privkbuf];
    
    return [client->app_wrapper login_result:client witherror:API_OK];
}

@end

@implementation CommandSetMasterKeyWrapper

-(id) initWithClient:(MegaClientWrapper*)client andok:(const byte*)oldkey andnk:(const byte*)newkey andhash:(const byte*)hash
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"up"];
    [self arg_bin:@"currk" withbuf:oldkey andlen:SymmCipher::KEYLENGTH];
    [self arg_bin:@"k" withbuf:newkey andlen:SymmCipher::KEYLENGTH];
    [self arg_bin:@"uh" withbuf:hash andlen:8];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    if ([json_data isKindOfClass:[NSNumber class]])
    {
        [client->app_wrapper changepw_result:client witherror:(error)[(NSNumber*)json_data intValue]];
    } else [client->app_wrapper changepw_result:client witherror:API_EINTERNAL];
}

@end

@implementation CommandFetchNodesWrapper

-(id) initWithClient:(MegaClientWrapper*)client
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"f"];
    [self arg_num:@"c" withnum:@1];
    [self arg_num:@"r" withnum:@1];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    [client purgenodes:nil];
    [client purgeusers:nil];
    
    client->scsn = @"";
    
    NSError *err;
    id json_obj;
    
    if ([json_data isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper fetchnodes_result:client witherror:(error)[(NSNumber*)json_data intValue]];
    }
    
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"f"])
        {
            // nodes
            if (![client readnodes:value withnotify:0 andhandles:nil]) return [client->app_wrapper fetchnodes_result:client witherror:API_EINTERNAL];
        } else if ([key isEqualToString:@"ok"])
        {
            // my own outgoing sharekeys
            if (![client readshares:value withmode:SHAREOWNERKEY andnotify:1]) return [client->app_wrapper fetchnodes_result:client witherror:API_EINTERNAL];
        } else if ([key isEqualToString:@"s"])
        {
            // outgoing shares
            if (![client readshares:value withmode:OUTSHARE andnotify:1]) return [client->app_wrapper fetchnodes_result:client witherror:API_EINTERNAL];
        } else if ([key isEqualToString:@"u"])
        {
            // users/contacts
            if (![client readusers:value]) return [client->app_wrapper fetchnodes_result:client witherror:API_EINTERNAL];
        } else if ([key isEqualToString:@"cr"])
        {
            // crypto key request
            [client proccr:value];
        } else if ([key isEqualToString:@"sr"])
        {
            // sharekey distribution request
            [client procsr:value];
        } else if ([key isEqualToString:@"sn"])
        {
            client->scsn = (NSString *)value;
        }
    }
    
    if ([client->scsn lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) return [client->app_wrapper fetchnodes_result:client witherror:API_EINTERNAL];
    
    [client applykeys];
    
    [client->app_wrapper nodes_updated:client withnodes:nil withcount:[client->nodes count]];
}

@end

@implementation CommandKeyCRWrapper

-(id) initWithClient:(MegaClientWrapper*)client andsharearray:(NSArray *)rshares andsharenode:(NSArray *)rnodes andArraykey:(NSArray *)key_arrary
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"k"];
    
    NSMutableArray *rsharehandlearray = [NSMutableArray array];
    NSMutableArray *rnodehandlearray = [NSMutableArray array];
    
    NSEnumerator *enumerator = [rshares objectEnumerator];
    NodeWrapper *n;
    while ((n = [enumerator nextObject])) {
        char buf[12];
        handle h = n->nodehandle;
        [Base64Wrapper btoa:(const byte*)&h oflength:6 tobuf:buf];
        [rsharehandlearray addObject:[NSString stringWithUTF8String:buf]];
    }
    
    enumerator = [rnodes objectEnumerator];
    while ((n = [enumerator nextObject])) {
        char buf[12];
        handle h = n->nodehandle;
        [Base64Wrapper btoa:(const byte*)&h oflength:6 tobuf:buf];
        [rnodehandlearray addObject:[NSString stringWithUTF8String:buf]];
    }

    NSMutableArray* big_array = [NSMutableArray array];
    [big_array addObject:rsharehandlearray];
    [big_array addObject:rnodehandlearray];
    [big_array addObject:key_arrary];
    
    [self arg_array:@"cr" witharray:big_array];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    
}

@end

@implementation CommandPubKeyRequestWrapper

-(id) initWithClient:(MegaClientWrapper*)client anduser:(UserWrapper *)user
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"uk"];
    [self arg_str:@"u" withstr:user->uid];

    u = user;
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
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
    
    byte pubkbuf[AsymmCipher::MAXKEYLENGTH];
	int len_pubk = 0;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"pubk"])
        {
            len_pubk = [Base64Wrapper atob:[(NSString *)value UTF8String] tobytes:pubkbuf withlen:sizeof(pubkbuf)] - pubkbuf;
        }
    }

    if (len_pubk && u->pubk.setkey(AsymmCipher::PUBKEY,pubkbuf,len_pubk))
    {
        NSEnumerator* enumerator = [u->pkrs objectEnumerator];
        id obj_item;
        
        while (obj_item = [enumerator nextObject])
        {
            if ([obj_item isKindOfClass:[PubKeyActionWrapper class]])
            {
                [(PubKeyActionWrapper *)obj_item proc:client anduser:u];
            }
        }
        [u->pkrs removeAllObjects];
    }
}

@end

@implementation CommandShareKeyUpdateWrapper

-(id) initWithClient:(MegaClientWrapper*)client andsharehandle:(handle)sh anduid:(NSString*)uid andkeybuffer:(const byte*)key andkeylen:(int)len
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"k"];
    NSMutableArray* big_array = [NSMutableArray array];
    
    char buf[12];
    [Base64Wrapper btoa:(const byte*)&sh oflength:6 tobuf:buf];
    [big_array addObject:[NSString stringWithUTF8String:buf]];
    char* uid_buf = new char[[uid lengthOfBytesUsingEncoding:NSUTF8StringEncoding]*4/3+4];
    [Base64Wrapper btoa:(const byte*)[uid UTF8String] oflength:[uid lengthOfBytesUsingEncoding:NSUTF8StringEncoding] tobuf:uid_buf];
    [big_array addObject:[NSString stringWithUTF8String:uid_buf]];
    delete[] uid_buf;
    char* key_buf = new char[len*4/3+4];
    [Base64Wrapper btoa:key oflength:len tobuf:key_buf];
    [big_array addObject:[NSString stringWithUTF8String:key_buf]];
    delete[] key_buf;
    
    [self arg_array:@"sr" witharray:big_array];
    
    return self;

}

-(id) initWithClient:(MegaClientWrapper*)client andhandlevalue:(NSArray*)v
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"k"];
    NSMutableArray* big_array = [NSMutableArray array];
    
    NSEnumerator* enumerator = [v reverseObjectEnumerator];
    id obj_item;
    
    NodeWrapper* n;
    char buf[64];
    while (obj_item = [enumerator nextObject])
    {
        handle h = [(NSNumber *)obj_item unsignedLongLongValue];
        if ((n = [client nodebyhandle:h]) && n->sharekey)
        {
            [Base64Wrapper btoa:(const byte*)&h oflength:6 tobuf:buf];
            NSString* buf_str = [NSString stringWithUTF8String:buf];
            [big_array addObject:buf_str];
            [Base64Wrapper btoa:(const byte*)&client->me oflength:8 tobuf:buf];
            buf_str = [NSString stringWithUTF8String:buf];
            [big_array addObject:buf_str];
            [Base64Wrapper btoa:n->sharekey->key oflength:SymmCipher::KEYLENGTH tobuf:buf];
            buf_str = [NSString stringWithUTF8String:buf];
            [big_array addObject:buf_str];
        }
    }
    
    [self arg_array:@"sr" witharray:big_array];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    
}

@end

@implementation CommandNodeKeyUpdateWrapper

-(id) initWithClient:(MegaClientWrapper*)client andhandlevalue:(NSArray*)v
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"k"];
    NSMutableArray* big_array = [NSMutableArray array];
    
    NSEnumerator* enumerator = [v reverseObjectEnumerator];
    id obj_item;
    
    NodeWrapper* n;
    byte key[FILENODEKEYLENGTH];
    while (obj_item = [enumerator nextObject])
    {
        handle h = [(NSNumber *)obj_item unsignedLongLongValue];
        if ((n = [client nodebyhandle:h]))
        {
            char buf[64];
            [Base64Wrapper btoa:(const byte*)&h oflength:6 tobuf:buf];
            NSString* buf_str = [NSString stringWithUTF8String:buf];
            [big_array addObject:buf_str];
            client->key.ecb_encrypt(n->nodekey, key, n->keylen);
            [Base64Wrapper btoa:key oflength:n->keylen tobuf:buf];
            buf_str = [NSString stringWithUTF8String:buf];
            [big_array addObject:buf_str];
        }
    }
    
    [self arg_array:@"nk" witharray:big_array];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    
}

@end

@implementation CommandMoveNodeWrapper

-(id) initWithClient:(MegaClientWrapper*)client withnode:(NodeWrapper*)n tonode:(NodeWrapper*)t
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"m"];
    [self notself:client];
    
    h = n->nodehandle;
    
    [self arg_bin:@"n" withbuf:(byte*)&n->nodehandle andlen:6];
    [self arg_bin:@"t" withbuf:(byte*)&t->nodehandle andlen:6];
    
    TreeProcShareKeysWrapper* tpsk;
    [client proctree:n withproc:tpsk];
    [tpsk get:self];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    if ([json_data isKindOfClass:[NSNumber class]])
    {
        error e = (error)[(NSNumber*)json_data intValue];
        if (e != API_OK) [client->app_wrapper rename_result:client withhandle:h witherror:e];
    }
}

@end

@implementation CommandDelNodeWrapper

-(id) initWithClient:(MegaClientWrapper*)client withnode:(handle)th
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"d"];
    [self notself:client];
    
    h = th;
    
    [self arg_bin:@"n" withbuf:(byte*)&th andlen:6];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    if ([json_data isKindOfClass:[NSNumber class]])
    {
        error e = (error)[(NSNumber*)json_data intValue];
        if (e != API_OK) [client->app_wrapper unlink_result:client withhandle:h witherror:e];
    }
}

@end

@implementation CommandGetFileWrapper

-(id) initWithtd:(int)t andhandle:(handle)h andp:(int)p andconn:(int)c
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"g"];
    [self arg_bin:p?@"n":@"p" withbuf:(byte*)&h andlen:6];
    [self arg_num:@"g" withnum:@1];
    
    td = t;
    connections = c;
    
    return self;

}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper topen_result:client withtd:td witherror:(error)[(NSNumber*)json_obj intValue]];
    }
    
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    NSString* g = nil;
    NSString* at = nil;
    NSString* fa = nil;
    error e = API_EINTERNAL;
    
    off_t s = -1;
	int d = 0;
	int pfa = 0;
	byte* buf;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"g"])
        {
            g = (NSString *)value;
        } else if ([key isEqualToString:@"s"])
        {
            s = [(NSNumber *)value longLongValue];
        } else if ([key isEqualToString:@"d"])
        {
            d = 1;
        } else if ([key isEqualToString:@"at"])
        {
            at = (NSString *)value;
        } else if ([key isEqualToString:@"fa"])
        {
            fa = (NSString *)value;
        } else if ([key isEqualToString:@"pfa"])
        {
            pfa = [(NSNumber *)value intValue];
        } else if ([key isEqualToString:@"e"])
        {
            e = (error)[(NSNumber*)value intValue];
        }
    }
    
    if (d) return [client->app_wrapper topen_result:client withtd:td witherror:API_EBLOCKED];
    else
    {
        if (g && s >= 0)
        {
            // decrypt at and set filename/@@@ mtime/ctime
            NSString* tmpfilename;
            
            if ((buf = [NodeWrapper decryptattr:&(client->ft[td]->key) from:at]))
            {
                json_obj = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytesNoCopy:buf+5 length:strlen((const char*)buf)-5 freeWhenDone:NO] options:NSJSONReadingMutableLeaves error:&err];
                
                is_dict = [json_obj isKindOfClass:[NSDictionary class]];
                if (!is_dict)
                {
                    return;
                }
                NSDictionary* json_dict = (NSDictionary *)json_obj;

                
                for (NSString* key in [json_dict allKeys])
                {
                    id value = [json_dict objectForKey:key];
                    if ([key isEqualToString:@"n"])
                    {
                        tmpfilename = (NSString *)value;
                    }
                }
                
                delete buf;
                
                [client->ft[td] init:s andfilename:tmpfilename andconnection:connections];
                [NodeWrapper copystring:client->ft[td]->tempurl from:[g UTF8String]];
                client->ft[td]->pos = [ChunkedHashWrapper chunkfloor:(client->ft[td]->startpos)];
                
                return [client->app_wrapper topen_result:client withtd:td withfilename:client->ft[td]->filename withattr:[fa UTF8String] withpfa:pfa];
            }
            
            [client->app_wrapper topen_result:client withtd:td witherror:API_OK];
        }
        else [client->app_wrapper topen_result:client withtd:td witherror:e];
    }
}

@end

@implementation CommandPutFileWrapper

-(id) initWithtd:(int)t andfile:(NSFileHandle *)f andms:(int)ms andconn:(int)c
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"u"];
    [self arg_num:@"s" withnum:[NSNumber numberWithUnsignedLongLong:[f seekToEndOfFile]]];
    [self arg_num:@"ms" withnum:[NSNumber numberWithInt:ms]];
    
    td = t;
    file = f;
    connections = c;
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper topen_result:client withtd:td witherror:(error)[(NSNumber*)json_obj intValue]];
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
    NSString* p = nil;
    
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"p"])
        {
            p = (NSString *)value;
        }
    }
    
    if (!p) [client->app_wrapper topen_result:client withtd:td witherror:API_EINTERNAL];
    else
    {
        [NodeWrapper copystring:client->ft[td]->tempurl from:[p UTF8String]];
        client->ft[td]->file = file;
        client->ft[td]->upload = 1;
    }
    return;
}

@end

@implementation CommandAttachFAWrapper

-(id) initWithNode:(NodeWrapper*)n
{
    if (!(self = [super init]))
        return nil;
    
    [self cmd:@"pfa"];
    [self arg_bin:@"n" withbuf:(byte*)&n->nodehandle andlen:8];
    
    NSMutableString* fa;
    
    [n faspec:fa];
    
    [self arg_str:@"fa" withstr:fa];

    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    
}

@end

@implementation CommandPutNodesWrapper

-(id) initWithClient:(MegaClientWrapper*)client withhandle:(handle)th withtargettype:(targettype)t withnewnode:(NSMutableArray *)n
{
    if (!(self = [super init]))
        return nil;
    
    byte key[FILENODEKEYLENGTH];
	int i;
	
	[self cmd:@"p"];
    [self notself:client];
    
    [self arg_bin:@"t" withbuf:(byte*)&th andlen:(t==USER_HANDLE)?8:6];
    
    ulhandles = [NSMutableArray array];
    
    NSEnumerator* enumerator = [n objectEnumerator];
    id obj_item;
    
    NSMutableArray* big_array = [NSMutableArray array];
    while (obj_item = [enumerator nextObject])
    {
        NSMutableDictionary* inner_dic = [NSMutableDictionary dictionary];
        NewNodeWrapper* new_node = (NewNodeWrapper *)obj_item;
        
        [ulhandles addObject:[NSNumber numberWithUnsignedLongLong:new_node->uploadhandle]];
        
        switch (new_node->source) {
            case NEW_NODE:
                [inner_dic setObject:[self element:(byte*)&(new_node->nodehandle) andlen:6] forKey:@"h"];
                break;
                
            case NEW_PUBLIC:
                [inner_dic setObject:[self element:(byte*)&(new_node->nodehandle) andlen:6] forKey:@"ph"];
                break;
                
            case NEW_UPLOAD:
                [inner_dic setObject:[self element:new_node->uploadtoken andlen:sizeof(new_node->uploadtoken)] forKey:@"h"];
                break;
                
            default:
                break;
        }
        
        [inner_dic setObject:[NSNumber numberWithInt:new_node->type] forKey:@"t"];
        [inner_dic setObject:[self element:(byte*)[new_node->attrstring UTF8String] andlen:[new_node->attrstring lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] forKey:@"a"];
        
        if (new_node->type == FILENODE)
		{
			new_node->keylen = FILENODEKEYLENGTH;
            
            // include pending file attributes for this upload
            NSMutableString* t;
            [client pendingattrstring:new_node->uploadhandle tofa:t];
            
            if ([t lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0) [self arg_str:@"fa" withstr:t];

		}
		else new_node->keylen = FOLDERNODEKEYLENGTH;
        
		client->key.ecb_encrypt(new_node->nodekey,key,new_node->keylen);
        [inner_dic setObject:[self element:key andlen:new_node->keylen] forKey:@"k"];
        
        [big_array addObject:[NSMutableDictionary dictionaryWithDictionary:inner_dic]];
    }
    
    [self arg_array:@"n" witharray:big_array];
    big_array = [NSMutableArray array];
    
    if (t == NODE_HANDLE)
	{
		NodeWrapper* tn;
		
		if ((tn = [client nodebyhandle:th]))
        {
            ShareNodeKeysWrapper *snk;
        
			for (i = 0; i < [n count]; i++)
            {
                NewNodeWrapper* new_node = (NewNodeWrapper *)[n objectAtIndex:i];
				switch (new_node->source)
				{
					case NEW_NODE:
                        [snk add:client withn:(NodeCoreWrapper*)new_node withsn:tn andspecific:0 anditem:NULL andlength:0];
						break;
                        
					case NEW_UPLOAD:
                        [snk add:client withn:(NodeCoreWrapper*)new_node withsn:tn andspecific:0 anditem:new_node->uploadtoken andlength:(int)sizeof(new_node->uploadtoken)];
						break;
						
					case NEW_PUBLIC:
						break;
				}
			}
            
            [snk get:self];
        }
	}
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper putnodes_result:client witherror:(error)[(NSNumber*)json_obj intValue]];
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return [client->app_wrapper putnodes_result:client witherror:API_EINTERNAL];
    }
    
    NSDictionary* json_dict = (NSDictionary *)json_obj;
        
    for (NSString* key in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key];
        if ([key isEqualToString:@"f"])
        {
            if (![client readnodes:value withnotify:1 andhandles:ulhandles]) return [client->app_wrapper putnodes_result:client witherror:API_EINTERNAL];
        }
    }

}

@end

@implementation CommandSetAttrWrapper

-(id) initWithClient:(MegaClientWrapper*)client andnode:(NodeWrapper *)n
{
    if (!(self = [super init]))
        return nil;
    
    h = n->nodehandle;
    
    [self cmd:@"a"];
    [self notself:client];
    
    NSError* err;
    NSMutableData* at = [NSMutableData data];
    NSData* json_data = [NSJSONSerialization dataWithJSONObject:n->attrs options:0 error:&err];
    [client makeattr:&(n->key) withoutput:at andinput:json_data];
    [self arg_bin:@"n" withbuf:(byte*)&(n->nodehandle) andlen:6];
    [self arg_bin:@"at" withbuf:(byte*)[at bytes] andlen:[at length]];
    
    byte key[FILENODEKEYLENGTH];
	client->key.ecb_encrypt(n->nodekey,key,n->keylen);
    [self arg_bin:@"k" withbuf:key andlen:n->keylen];
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    if ([json_data isKindOfClass:[NSNumber class]])
    {
        error e = (error)[(NSNumber*)json_data intValue];
        if (e != API_OK) [client->app_wrapper setattr_result:client withhandle:h witherror:e];
    }

}

@end

@implementation CommandSetShareWrapper

-(id) initWithClient:(MegaClientWrapper*)client withNode:(NodeWrapper*)n anduser:(UserWrapper*)u andaccesslevel:(accesslevel)a andnewshare:(int)newshare
{
    if (!(self = [super init]))
        return nil;
    
    byte auth[SymmCipher::BLOCKSIZE];
	byte key[SymmCipher::KEYLENGTH];
	byte asymmkey[AsymmCipher::MAXKEYLENGTH];
	int t;
    
	sh = n->nodehandle;
	if (u) uid = [NSString stringWithString:u->uid];	// u == NULL => link export
	access = a;
    
    [self cmd:@"s"];
    
    [self arg_bin:@"n" withbuf:(byte*)&sh andlen:6];
    
	if (a != ACCESS_UNKNOWN)
	{
		// securely store/transmit share key
		// by creating a symmetrically (for the sharer) and an asymmetrically (for the sharee) encrypted version
		memcpy(key,n->sharekey->key,sizeof key);
		memcpy(asymmkey,key,sizeof key);
        
		client->key.ecb_encrypt(key);
        [self arg_bin:@"ok" withbuf:key andlen:sizeof(key)];
        
		if (u) t = u->pubk.encrypt(asymmkey,SymmCipher::KEYLENGTH,asymmkey,sizeof asymmkey);
        
		// outgoing handle authentication
        [client handleauth:sh withauth:auth];
        [self arg_bin:@"ha" withbuf:auth andlen:sizeof(auth)];
	}
        
    NSMutableDictionary* inner_dict = [NSMutableDictionary dictionary];
    [inner_dict setObject:[uid lengthOfBytesUsingEncoding:NSUTF8StringEncoding]?uid:@"EXP" forKey:@"u"];
    
	if (a != ACCESS_UNKNOWN)
	{
        [inner_dict setObject:[NSNumber numberWithInt:a] forKey:@"r"];
		if (u) [inner_dict setObject:[self element:asymmkey andlen:t] forKey:@"k"];
	}
    
    [self arg_array:@"s" witharray:[NSMutableArray arrayWithObject:inner_dict]];
    
	// only for a fresh share: add cr element with all node keys encrypted to the share key
	if (newshare)
	{
		// the new share's nodekeys for this user: generate node list
		TreeProcShareKeysWrapper* tpsk = [[TreeProcShareKeysWrapper alloc] initWithNode:n];
        [client proctree:n withproc:tpsk];
		[tpsk get:self];
	}
    
    return self;
}

-(int) procuserresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
       
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return 0;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;

    handle uh = UNDEF;
    NSString* m = nil;
    
    for (NSString* key_str in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key_str];
        if ([key_str isEqualToString:@"u"])
        {
            uh = [client convert_base64str_handle:(NSString*)value];
        } else if ([key_str isEqualToString:@"m"])
        {
            m = (NSString*)value;
        }
    }
    
    if (!ISUNDEF(uh) && m)
    {
        [client mapuser:uh withemail:m];
    }
    
    return 1;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper share_result:client witherror:(error)[(NSNumber*)json_obj intValue]];
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    byte key[SymmCipher::KEYLENGTH];
    id json_item;
    
    for (NSString* key_str in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key_str];
        if ([key_str isEqualToString:@"ok"])
        {
            NSString* value_str = @"";
            if ([value isKindOfClass:[NSString class]])
            {
                value_str = value;
            }
            if (([Base64Wrapper atob:[value_str UTF8String] tobytes:key withlen:sizeof(key)]-key) == sizeof(key))
            {
                NodeWrapper* n;
                UserWrapper* u;
                
                if ((n = [client nodebyhandle:(sh)]) && n->sharekey && (u = [client finduser:uid withadd:0]))
                {
                    client->key.ecb_decrypt(key);
                    n->sharekey->setkey(key);
                    
                    // repeat attempt with corrected share key
                    [client->reqs[client->req_sn] add:[[CommandSetShareWrapper alloc] initWithClient:client withNode:n anduser:u andaccesslevel:access andnewshare:0]];
                    return;
                }
            }
            
            if (![client readshares:value withmode:SHAREOWNERKEY andnotify:0]) return [client->app_wrapper share_result:client witherror:API_EINTERNAL];
        }
        else if ([key_str isEqualToString:@"u"])
        {
            if ([value isKindOfClass:[NSArray class]]) {
                for (json_item in (NSArray*)value) {
                    if (![self procuserresult:client withdata:json_item])
                    {
                        break;
                    }
                }
            }
        }
        else if ([key_str isEqualToString:@"r"])
        {
            if ([value isKindOfClass:[NSArray class]]) {
                error e;
                int i = 0;
                
                for (json_item in (NSArray*)value) {
                    if ([json_item isKindOfClass:[NSNumber class]] && (e = (error)[(NSNumber*)json_item intValue]))
                    {
                        [client->app_wrapper share_result:client withidx:i++ witherror:e];
                    } else
                    {
                        break;
                    }
                }
            }
        }
        else if ([key_str isEqualToString:@"suk"])
        {
            if ([value isKindOfClass:[NSArray class]]) {
                for (json_item in (NSArray*)value) {
                    if ([json_item isKindOfClass:[NSArray class]])
                    {
                        handle local_sh, uh;
                        if ([(NSArray*)json_item count] > 2)
                        {
                            local_sh = [(NSNumber*)[(NSArray*)json_item objectAtIndex:0] unsignedLongLongValue];
                            uh = [(NSNumber*)[(NSArray*)json_item objectAtIndex:1] unsignedLongLongValue];
                            if (!ISUNDEF(local_sh) && !ISUNDEF(uh))
                            {
                                // FIXME: add support for share user key delivery
                            }
                        }
                    }
                }
            }
        }
        else if ([key_str isEqualToString:@"suk"])
        {
            [client proccr:value];
        }
    }
    
    if ([client->scsn lengthOfBytesUsingEncoding:NSUTF8StringEncoding]==0) return [client->app_wrapper share_result:client witherror:API_EINTERNAL];
    
    [client applykeys];
    [client notifypurge];
}

@end

@implementation CommandSetPHWrapper

-(id) initWithClient:(MegaClientWrapper*)client withNode:(NodeWrapper*)n anddel:(int)del
{
    if (!(self = [super init]))
        return nil;
    
    h = n->nodehandle;
    
	[self cmd:@"l"];
    [self arg_bin:@"n" withbuf:(byte*)&n->nodehandle andlen:8];
	if (del) [self arg_num:@"d" withnum:@1];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;

    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        return [client->app_wrapper exportnode_result:client witherror:(error)[(NSNumber*)json_data intValue]];
    }
    
    handle ph = UNDEF;
    
    if ([json_obj isKindOfClass:[NSString class]])
    {
        ph = [client convert_base64str_handle:(NSString *)json_obj];
    }
    
    if (ISUNDEF(ph)) return [client->app_wrapper exportnode_result:client witherror:API_EINTERNAL];

    [client->app_wrapper exportnode_result:client withhandle:h withph:ph];
}

@end

@implementation CommandGetPHWrapper

-(id) initWithClient:(MegaClientWrapper*)client withhandle:(handle)cph andkey:(const byte*)ckey
{
    if (!(self = [super init]))
        return nil;
    
    ph = cph;
    memcpy(key, ckey, sizeof(key));
    
    [self cmd:@"g"];
    [self arg_bin:@"p" withbuf:(byte*)&ph andlen:8];
    
    return self;
}

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
    
    if ([json_obj isKindOfClass:[NSNumber class]])
    {
        int err_code = [(NSNumber *)json_obj intValue];
        return [client->app_wrapper openfilelink_result:client witherror:(error)err_code];
    }
    
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
    
	off_t s = -1;
	time_t tm = 0;
	time_t ts = 0;
	NSString* a = nil;
	NSString* fa = nil;
    
    for (NSString* key_str in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key_str];
        if ([key_str isEqualToString:@"s"])
        {
            s = [(NSNumber*)value longLongValue];
        } else if ([key_str isEqualToString:@"at"])
        {
            a = (NSString*)value;
        } else if ([key_str isEqualToString:@"fa"])
        {
            fa = (NSString*)value;
        } else if ([key_str isEqualToString:@"tm"])
        {
            tm = [(NSNumber*)value intValue];
        } else if ([key_str isEqualToString:@"ts"])
        {
            ts = [(NSNumber*)value intValue];
        }
    }
    
    // we want at least the attributes
    if (a && s >= 0)
    {
        NodeWrapper* n = [[NodeWrapper alloc] initWithHandle:ph parent:0 withtype:FILENODE withsize:s withowner:0 withattrstr:a withkeystr:nil withfileattrstr:fa withmodtime:tm withcreatetime:ts withshare:nil];
        
        [n setkey:key];
        [n setattr];
        
        return [client->app_wrapper openfilelink_result:client withnode:n];
    }
    else [client->app_wrapper openfilelink_result:client witherror:API_EINTERNAL];

}

@end

@implementation CommandGetUserQuotaWrapper

-(id) initWithClient:(MegaClientWrapper *)client withaccount:(AccountDetailsWrapper *)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro
{
    if (!(self = [super init]))
        return nil;
    
    details = ad;
	got_storage = 0;
	got_transfer = 0;
	got_pro = 0;
    
	[self cmd:@"uq"];
	if (storage) [self arg_num:@"strg" withnum:@1];
	if (transfer) [self arg_num:@"xfer" withnum:@1];
	if (pro) [self arg_num:@"pro" withnum:@1];
    
    return self;
}

-(void) procresult:(MegaClientWrapper *)client withdata:(id)json_data
{
    NSError *err;
    id json_obj;
    if ([json_data isKindOfClass:[NSData class]])
        json_obj = [NSJSONSerialization JSONObjectWithData:json_data options:NSJSONReadingMutableLeaves error:&err];
    else
        json_obj = json_data;
        
    BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
    if (!is_dict)
    {
        return;
    }
    NSDictionary* json_dict = (NSDictionary *)json_obj;
        
    for (NSString* key_str in [json_dict allKeys])
    {
        id value = [json_dict objectForKey:key_str];
        if ([key_str isEqualToString:@"cstrg"]) // storage used
        {
            details->storage_used = [(NSNumber *)value unsignedLongLongValue];
        } else if ([key_str isEqualToString:@"mstrg"]) // total storage quota
        {
            details->storage_max = [(NSNumber *)value unsignedLongLongValue];
            got_storage = 1;
        } else if ([key_str isEqualToString:@"caxfer"]) // own transfer quota used
        {
            details->transfer_own_used = [(NSNumber *)value unsignedLongLongValue];
        } else if ([key_str isEqualToString:@"csxfer"]) // third-party transfer quota used
        {
            details->transfer_srv_used = [(NSNumber *)value unsignedLongLongValue];
        } else if ([key_str isEqualToString:@"mxfer"]) // total transfer quota
        {
            details->transfer_max = [(NSNumber *)value unsignedLongLongValue];
            got_transfer = 1;
        } else if ([key_str isEqualToString:@"srvratio"]) // percentage of transfer allocated for serving
        {
            details->srv_ratio = [(NSNumber *)value doubleValue];
        } else if ([key_str isEqualToString:@"utype"]) // Pro level (0 == none)
        {
            details->pro_level = [(NSNumber *)value intValue];
            got_pro = 1;
        } else if ([key_str isEqualToString:@"stype"]) // subscription type
        {
            details->subscription_type = *[(NSString*)value UTF8String];
        } else if ([key_str isEqualToString:@"suntil"]) // Pro level until
        {
            details->pro_until = [(NSNumber*)value intValue];
        } else if ([key_str isEqualToString:@"balance"]) // account balances
        {
            if ([value isKindOfClass:[NSArray class]])
            {
                for (NSArray* inner_array in value) {
                    NSString* cur;
                    NSString* amount;
                    amount = [inner_array objectAtIndex:0];
                    cur = [inner_array objectAtIndex:1];
                    
                    AccountBalanceWrapper* balance = [[AccountBalanceWrapper alloc] init];
                    balance->amount = [amount doubleValue];
                    memcpy(balance->currency, [cur UTF8String], 3);
                    [details->balances addObject:balance];
                }
            }
        }
    }
    [client->app_wrapper account_details:client withaccount:details withstorage:got_storage withtransfer:got_transfer withpro:got_pro withpurchases:0 withtransactions:0 withsessions:0];
}

@end

@implementation CommandGetUserTransactionsWrapper

-(id) initWithClient:(MegaClientWrapper *)client withaccount:(AccountDetailsWrapper *)ad
{
    if (!(self = [super init]))
        return nil;
    
    details = ad;
    
    [self cmd:@"utt"];
    
    return self;
}

-(void) procresult:(MegaClientWrapper *)client withdata:(id)json_data
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
    
    [details->transactions removeAllObjects];
    
    for (NSArray* inner_array in json_array) {
        NSString* local_handle = inner_array[0];
		time_t ts = [(NSNumber *)inner_array[1] intValue];
		NSString* delta = inner_array[2];
		NSString* cur = inner_array[3];
        
		if (local_handle && ts > 0 && delta && cur)
		{
            AccountTransactionWrapper* transaction = [[AccountTransactionWrapper alloc] init];
            memcpy(transaction->local_handle, [local_handle UTF8String], [local_handle lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            transaction->timestamp = ts;
            transaction->delta = [delta doubleValue];
            memcpy(transaction->currency, [cur UTF8String], 3);
            [details->transactions addObject:transaction];
        }
    }
    
    [client->app_wrapper account_details:client withaccount:details withstorage:0 withtransfer:0 withpro:0 withpurchases:0 withtransactions:1 withsessions:0];
}

@end

@implementation CommandGetUserPurchasesWrapper

-(id) initWithClient:(MegaClientWrapper *)client withaccount:(AccountDetailsWrapper *)ad
{
    if (!(self = [super init]))
        return nil;
    
    details = ad;
    
    [self cmd:@"utp"];
    
    return self;
}

-(void) procresult:(MegaClientWrapper *)client withdata:(id)json_data
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
    
    [details->purchases removeAllObjects];
    
    for (NSArray* inner_array in json_array) {
        NSString* local_handle = inner_array[0];
		time_t ts = [(NSNumber *)inner_array[1] intValue];
		NSString* amount = inner_array[2];
		NSString* cur = inner_array[3];
        int method = [(NSNumber *)inner_array[4] intValue];
        
		if (local_handle && ts > 0 && amount && cur && method >= 0)
		{
            AccountPurchaseWrapper* purchase = [[AccountPurchaseWrapper alloc] init];
            memcpy(purchase->local_handle, [local_handle UTF8String], [local_handle lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            purchase->timestamp = ts;
            purchase->amount = [amount doubleValue];
            memcpy(purchase->currency, [cur UTF8String], 3);
            purchase->method = method;
            [details->purchases addObject:purchase];
        }
    }
    
    [client->app_wrapper account_details:client withaccount:details withstorage:0 withtransfer:0 withpro:0 withpurchases:1 withtransactions:0 withsessions:0];
}

@end

@implementation CommandGetUserSessionsWrapper

-(id) initWithClient:(MegaClientWrapper *)client withaccount:(AccountDetailsWrapper *)ad
{
    if (!(self = [super init]))
        return nil;
    
    details = ad;
    
    [self cmd:@"usl"];
    
    return self;
}

-(void) procresult:(MegaClientWrapper *)client withdata:(id)json_data
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
    
    [details->sessions removeAllObjects];
    
    for (NSArray* inner_array in json_array) {
        AccountSessionWrapper* session = [[AccountSessionWrapper alloc] init];
        session->timestamp = [(NSNumber *)inner_array[0] intValue];
        session->mru = [(NSNumber *)inner_array[1] intValue];
        session->useragent = inner_array[2];
        session->ip = inner_array[3];
        NSString* country = inner_array[4];
        memcpy(session->country, country?[country UTF8String]:"\0\0", 2);
        session->current = [(NSNumber *)inner_array[5] intValue];
        
        [details->sessions addObject:session];
    }
    
    [client->app_wrapper account_details:client withaccount:details withstorage:0 withtransfer:0 withpro:0 withpurchases:0 withtransactions:0 withsessions:1];
}

@end