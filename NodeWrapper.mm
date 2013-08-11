//
//  NodeWrapper.m
//  testioslib
//


#import "NodeWrapper.h"
#import "Base64Wrapper.h"
#import "ShareWrapper.h"

@implementation NodeCoreWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    attrstring = @"";
    
    return self;
}

-(void) copyfromother:(NodeCoreWrapper *)copy
{   
    nodehandle = copy->nodehandle;
	parent = copy->parent;
    type = copy->type;
    
    memcpy(nodekey, copy->nodekey, FILENODEKEYLENGTH);
	keylen = copy->keylen;
    
    ctime = copy->ctime;
	mtime = copy->mtime;
    
    attrstring = [NSString stringWithString:copy->attrstring];
}

@end

@implementation NodeWrapper

+(void) copystring:(NSString *)s from:(const char*)p
{
    if (p)
    {
        const char* pp;
        pp = strchr(p, '"');
        if (NULL != pp)
        {
            s = [s initWithBytes:p length:(pp-p) encoding:NSUTF8StringEncoding];
        } else
        {
            s = [NSString stringWithUTF8String:p];
        }
    } else
    {
        s = @"";
    }
}

+(byte*) decryptattr:(SymmCipher*)key from:(NSString*)attrstr
{
    int attrstrlen = [attrstr lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (attrstrlen)
	{
		int l = attrstrlen*3/4+3;
		byte* buf = new byte[l];
        
		l = [Base64Wrapper atob:[attrstr UTF8String] tobytes:buf withlen:l]-buf;
		
		if (!(l & (SymmCipher::BLOCKSIZE-1)))
		{
			key->cbc_decrypt(buf,l);
            
			if (!memcmp(buf,"MEGA{\"",6)) return buf;
		}
        
		delete[] buf;
	}
	
	return NULL;
}

-(id) initWithHandle:(handle)h parent:(handle)p withtype:(nodetype)t withsize:(size_t)s withowner:(handle)u withattrstr:(NSString*)a withkeystr:(NSString*)k withfileattrstr:(NSString*)fa withmodtime:(time_t)tm withcreatetime:(time_t)ts withshare:(ShareWrapper*)share
{
    if (!(self = [super init]))
        return nil;
    
    attrs = [NSMutableDictionary dictionary];
    fileattrs = [NSMutableDictionary dictionary];
    outshares = [NSMutableDictionary dictionary];

    nodehandle = h;
	parent = p;
    
	if ((type = t) == FILENODE) keylen = FILENODEKEYLENGTH;
	else keylen = FOLDERNODEKEYLENGTH;
	
	size = s;
	owner = u;
    
    attrstring = [NSString stringWithString:a];
    keystring = @"";
    if (k)
    {
        keystring = [NSString stringWithString:k];
    }
    
    // FIXME: add support for file attribute reading
    //	copystring(&fileattrstring,fa);
    
	mtime = tm;
	ctime = ts;
    
	inshare = share;
	sharekey = NULL;
	outshare = 0;
    
	removed = NO;
    notified = NO;
    
    return self;
}

-(void) dealloc
{
    for (id share_key in [outshares allKeys])
    {
        id value = [outshares objectForKey:share_key];
        if (value != nil)
        {
            ShareWrapper* share_value = (ShareWrapper *)value;
            NSNumber* share_num = (NSNumber *)share_key;
            [share_value removeshare:[share_num unsignedLongLongValue]];
        }
    }
    
    if (sharekey) delete sharekey;
}

// try to resolve node key string
-(int) applykey:(MegaClientWrapper*)client with:(handle)nh
{
    if ([keystring lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) return 0;
	
	int l = -1, t=0;
    NSRange tr;
	handle h;
	const char* k = NULL;
	SymmCipher* sc = &(client->key);
    
    tr = NSMakeRange(t, [keystring lengthOfBytesUsingEncoding:NSUTF8StringEncoding]-t);
    
	while ((tr = [keystring rangeOfString:@":" options:NSLiteralSearch range:tr]).location != NSNotFound)
	{
		// compound key: locate suitable subkey (always symmetric)
		h = 0;
        
        t = tr.location;
        tr = NSMakeRange(t, [keystring lengthOfBytesUsingEncoding:NSUTF8StringEncoding]-t);
        
        l = [Base64Wrapper atob:[keystring UTF8String]+[keystring rangeOfString:@"/" options:NSBackwardsSearch range:tr].location+1 tobytes:(byte*)&h withlen:sizeof(h)]-(byte*)&h;
        
		t++;
        
		if (l == 8)
		{
			// this is a user handle - reject if it's not me
			if (h != client->me) continue;
		}
		else
		{
            // look for share key if not folder access with folder master key
            if (h != client->me)
            {
                NodeWrapper *n;
            
                // this is a share node handle - check if we have node and the share key
                if (!(n = [client nodebyhandle:h]) || !n->sharekey) continue;
			
                sc = n->sharekey;
            }
		}
		
		k = [keystring UTF8String]+t;
		break;
	}
    
	// no : found => personal key, use directly
	// otherwise, no suitable key available yet - bail
	if (!k)
	{
		if (l < 0) k = [keystring UTF8String];
		else return 0;
	}
    
    if ([client decryptkey:k withtk:nodekey withtl:keylen withsc:sc withtype:0 withnode:nh])
	{
		keystring = @"";
        [self setkey:NULL];
	}
    
	return 1;
}

// decrypt attribute string and set fileattrs
-(void) setattr
{
    byte* buf;
	
    buf = [NodeWrapper decryptattr:&key from:attrstring];
	if (NULL != buf)
	{
        NSError* err;
        int buf_len = strlen((const char*)buf);
        buf_len -= 5;
		id json_obj = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:(buf+5) length:(buf_len)] options:NSJSONReadingMutableLeaves error:&err];
		
        BOOL is_dict = [json_obj isKindOfClass:[NSDictionary class]];
        if (!is_dict)
        {
            delete buf;
            return;
        }
        
        attrs = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)json_obj];
        
		delete buf;
        
		attrstring = @"";
	}
}

// display name (UTF-8)
-(const char*) displayname
{
    if ([attrstring lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0) return "NO_KEY";
	
    NSString* keystr = @"n";
    id value = [attrs objectForKey:keystr];
	
	if (value == nil) return "CRYPTO_ERROR";
    
    NSString* value_str = (NSString *)value;
	if ([value_str lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) return "BLANK";
	return [value_str UTF8String];
}

-(void) setkey:(byte *)newkey
{
	if (newkey) memcpy(nodekey,newkey,keylen);
    
	key.setkey(nodekey,type);
    [self setattr];
}

-(void) faspec:(NSMutableString*)fa
{
    char buf[128];

    NSNumber* key_num;
    for (key_num in [fileattrs allKeys]) {
        NSMutableOrderedSet* value_set = [fileattrs objectForKey:key_num];
        if (value_set)
        {
            NSNumber* value_num;
            for (value_num in value_set) {
                handle h = [value_num unsignedLongLongValue];
                sprintf(buf,"/%u*",[key_num unsignedIntValue]);
                [Base64Wrapper btoa:(byte*)&h oflength:sizeof(h) tobuf:strchr(buf+3,0)];
                [fa appendString:[NSString stringWithUTF8String:(buf+![fa lengthOfBytesUsingEncoding:NSUTF8StringEncoding])]];
            }
        }
    }

}
@end

@implementation NewNodeWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    attrstring = @"";
    
    attrdata = [NSMutableData data];
    
    return self;
}

@end
