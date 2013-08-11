//
//  FileTransferWrapper.m
//  testioslib
//

#import "FileTransferWrapper.h"
#import "Base64Wrapper.h"
#import "MegaClientWrapper.h"
#import "MegaAppWrapper.h"
#import "HttpIOWrapper.h"
#import "NodeWrapper.h"

@implementation FileTransferWrapper

-(id) initWithIndex:(int)idx
{
    if (!(self = [super init]))
        return nil;
    
    file = nil;
	reqs = [NSMutableArray array];
    
	inuse = 0;
    ft_idx = idx;
	connections = 3;
    
    return self;
}

-(void) init:(off_t)s andfilename:(NSString*)fn andconnection:(int)c
{
    size = s;
    
    if (fn && ([fn lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0)) filename = [NSMutableString stringWithString:fn];
    else filename = [NSMutableString stringWithString:@""];
    
    upload = 0;
    uploadhandle = 0;
    
    pos = 0;
    
    failcount = 0;
    
    connections = c;
    
    nextattempt = 0;
    
    progressinflight = 0;
    progresscompleted = 0;
}

-(void) doio:(MegaClientWrapper*)client
{
    if (file != nil)
    {        
        progressinflight = 0;
        
        if ([reqs count] == 0)
        {
            for (int i = 0; i < connections; i++)
            {
                if (upload) [reqs addObject:[[HttpReqULWrapper alloc] initWithIndex:i]];
                else [reqs addObject:[[HttpReqDLWrapper alloc] initWithIndex:i]];
            }
        }
        
        NSEnumerator *enumerator = [reqs objectEnumerator];
        HttpRequestWrapper* req;
        while (req = [enumerator nextObject]) {
            if (req->status == REQ_READY)
            {
                [self issue_request:client withreq:req];
            }
        }
    }
}

-(void) issue_request:(MegaClientWrapper*)client withreq:(HttpRequestWrapper*)req
{
    uint32_t ds = [client->app_wrapper dstime];
    if (ds > nextattempt && (size ? pos < size : !req->ft_idx))
    {
        off_t npos = [ChunkedHashWrapper chunkceil:pos];
        
        if (npos > size) npos = size;
        if (upload)
        {
            HttpReqULWrapper* ul_req = (HttpReqULWrapper *)req;
            [ul_req preprare:file withurl:tempurl andkey:&key andmacs:chunkmacs andctr:ctriv andpos:pos andnpos:npos];
        }
        else
        {
            HttpReqDLWrapper* dl_req = (HttpReqDLWrapper *)req;
            [dl_req preprare:file withurl:tempurl andkey:&key andmacs:chunkmacs andctr:ctriv andpos:pos andnpos:npos];
        }
        req->direction = 2;
        [client->httpio_wrapper post:req withft:self];
        pos = npos;
        failcount = 0;
    }

}

-(void) doio_success:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req anddata:(NSData *)data
{
    [req put:[data bytes] withlen:[data length]];
    HttpReqDLWrapper* dl_req;
    HttpReqULWrapper* ul_req;
    if (upload)
    {
        ul_req = (HttpReqULWrapper *)req;
        progresscompleted += ul_req->size;
        [ul_req finalize_trans:file withkey:&key andmacs:chunkmacs andctr:ctriv andpos:startpos andnpos:endpos];
    } else
    {
        dl_req = (HttpReqDLWrapper *)req;
        progresscompleted += dl_req->size;
        [dl_req finalize_trans:file withkey:&key andmacs:chunkmacs andctr:ctriv andpos:startpos andnpos:endpos];
    }
    
    
    if (upload)
    {
        if ([ul_req->in length] > 0)
        {
            NSMutableData* in_data = [NSMutableData dataWithData:ul_req->in];
            [in_data appendData:[NSMutableData dataWithLength:1]];

            if ([ul_req->in length] == UPLOADTOKENLEN*4/3)
            {
                byte ultoken[UPLOADTOKENLEN+1];
                byte filekey[FILENODEKEYLENGTH];
                                
                if ([Base64Wrapper atob:(const char*)[in_data bytes] tobytes:ultoken withlen:UPLOADTOKENLEN+1]-ultoken == UPLOADTOKENLEN)
                {
                    memcpy(filekey,key.key,sizeof key.key);
                    ((int64_t*)filekey)[2] = ctriv;                    
                    ((int64_t*)filekey)[3] = [self macsmac:chunkmacs];
                    SymmCipher::xorblock(filekey+SymmCipher::KEYLENGTH,filekey);
                    
                    [client->app_wrapper transfer_update:client withtd:ft_idx withbytes:size withsize:size withstarttime:starttime];
                    return [client->app_wrapper transfer_complete:client withtd:ft_idx withulhandle:uploadhandle withultoken:ultoken withfilekey:filekey withcryptokey:&key];
                }
            }
            
            return [client->app_wrapper transfer_failed:client withtd:ft_idx witherror:(error)atoi((const char*)[in_data bytes])];
        }
    }
    else
    {
        if (endpos != -1)
        {
            // partial read: complete?
            if (progresscompleted >= endpos-startblock)
                return [client->app_wrapper transfer_complete:client withtd:ft_idx withchunk:chunkmacs withfilename:filename];
        }
        else if (progresscompleted == size)
        {
            if ([self macsmac:chunkmacs] == metamac)
            {
                [client->app_wrapper transfer_update:client withtd:ft_idx withbytes:size withsize:size withstarttime:starttime];
                return [client->app_wrapper transfer_complete:client withtd:ft_idx withchunk:chunkmacs withfilename:filename];
            }
            else return [client->app_wrapper transfer_failed:client withtd:ft_idx withfilename:filename witherror:API_EKEY];
        }
    }
    cout << "Completed: " << progresscompleted << " Filesize: " << size << endl;
    req->status = REQ_READY;
    [self issue_request:client withreq:req];
}

-(void) doio_fail:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req anderror:(error)err_num andcode:(int)httpcode
{
    cout << "Transfer FAILED with status = " << httpcode << endl;
    
    uint32_t ds = [client->app_wrapper dstime];
    if (httpcode == 509)
    {
        [client->app_wrapper transfer_limit:client withtd:ft_idx];
        
        nextattempt = ds+DLRETRYINTERVAL;
    }
    else
    {
        failcount++;
        
        [client->app_wrapper transfer_error:client withtd:ft_idx withhttpcode:httpcode withcount:failcount];
               
        if (failcount == DLMAXFAIL/2)
        {
            // @@@ refetch tempurl
        }
        
        if (failcount > DLMAXFAIL)
            return [client->app_wrapper transfer_failed:client withtd:ft_idx withfilename:filename witherror:API_EFAILED];
        
        nextattempt = ds+DLRETRYINTERVAL;
    }
    
    [client->httpio_wrapper post:req withft:self];
}

-(void) doio_update:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req bytesdone:(uint64_t)done_bytes bytestotal:(uint64_t)total_bytes bytesexpect:(uint64_t)expect_bytes
{
    progressinflight += done_bytes;
    if (!starttime) starttime = [client->app_wrapper dstime];
    
    [client->app_wrapper transfer_update:client withtd:ft_idx withbytes:progresscompleted+progressinflight withsize:size withstarttime:starttime];
}

-(void) close
{
    [chunkmacs removeAllObjects];
    
    file = nil;
    
    [reqs removeAllObjects];
    
    inuse = 0;
    
    starttime = 0;
}

-(int64_t) macsmac:(NSMutableDictionary*)macs
{
    byte mac[SymmCipher::BLOCKSIZE] = { 0 };
    
    for (id mac_key in [macs allKeys])
    {
        id mac_value = [macs objectForKey:mac_key];
        SymmCipher::xorblock((const byte*)[(NSData *)mac_value bytes], mac);
        key.ecb_encrypt(mac);
    }
    
    uint32_t* m = (uint32_t*)mac;
	
	m[0] ^= m[1];
	m[1] = m[2]^m[3];
    
    return *(int64_t*)mac;
}

@end

@implementation HttpReqULWrapper

-(id) initWithIndex:(int)idx
{
    if (!(self = [super init]))
        return nil;
    ft_idx = idx;
    
    return self;
}

-(void) preprare:(NSFileHandle*)file withurl:(NSString*)tempurl andkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)pos andnpos:(off_t)npos
{
    byte mac[SymmCipher::BLOCKSIZE] = { 0 };
    [self setreq:[NSString stringWithFormat:@"%@/%tu", tempurl, pos] withtype:REQ_BINARY];
    
    size = npos - pos;
    
    [file seekToFileOffset:pos];
    out = [NSMutableData dataWithData:[file readDataOfLength:size]];
    [out appendData:[NSMutableData dataWithLength:(-size)&(SymmCipher::BLOCKSIZE-1)]];
    
    // writing, mutableBytes will be ok.
    key->ctr_crypt((byte*)[out mutableBytes], size, pos, ctriv, mac, 1);
    
    NSNumber* pos_num = [NSNumber numberWithUnsignedLongLong:pos];
    NSMutableData* mac_obj = [macs objectForKey:pos_num];
    
    if (mac_obj == nil)
    {
        mac_obj = [NSMutableData dataWithBytes:mac length:sizeof(mac)];
        [macs setObject:mac_obj forKey:pos_num];
    } else
    {
        memcpy([mac_obj mutableBytes], mac, sizeof(mac));
    }
    
    [out setLength:size];
}

-(void) finalize_trans:(NSFileHandle*)file withkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)startpos andnpos:(off_t)endpos
{
    
}

-(off_t) transferred:(MegaClientWrapper *)client
{
    if (httpiohandle) return [client->httpio_wrapper postpos:httpiohandle];
    
    return 0;
}

@end

@implementation HttpReqDLWrapper

-(id) initWithIndex:(int)idx
{
    if (!(self = [super init]))
        return nil;
    
    ft_idx = idx;
    
    return self;
}

-(void) preprare:(NSFileHandle*)file withurl:(NSString*)tempurl andkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)pos andnpos:(off_t)npos
{
    [self setreq:[NSString stringWithFormat:@"%@/%tu-%tu", tempurl, pos, npos-1] withtype:REQ_BINARY];
    
    dlpos = pos;
    size = npos-pos;
    
    buf = new byte[(size+SymmCipher::BLOCKSIZE-1)&-SymmCipher::BLOCKSIZE];
	buflen = size;
	bufpos = 0;

}

-(void) finalize_trans:(NSFileHandle*)file withkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)startpos andnpos:(off_t)endpos
{
    byte mac[SymmCipher::BLOCKSIZE] = { 0 };
    
	key->ctr_crypt(buf,bufpos,dlpos,ctriv,mac,0);
    
    NSMutableData* mac_obj = [macs objectForKey:[NSNumber numberWithUnsignedLongLong:dlpos]];
    if (mac_obj == nil)
    {
        mac_obj = [NSMutableData dataWithBytes:mac length:sizeof(mac)];
        [macs setObject:mac_obj forKey:[NSNumber numberWithUnsignedLongLong:dlpos]];
    } else
    {
        memcpy([mac_obj mutableBytes], mac, sizeof(mac));
    }
    
	off_t skip;
	off_t prune;
    
	if (endpos == -1) skip = prune = 0;
	else
	{
		if (startpos > dlpos) skip = startpos-dlpos;
		else skip = 0;
		
		if (dlpos+bufpos > endpos) prune = dlpos+bufpos-endpos;
		else prune = 0;
	}
    
    [file seekToFileOffset:dlpos+skip];
    [file writeData:[NSData dataWithBytesNoCopy:buf+skip length:bufpos-skip-prune freeWhenDone:NO]];
}

@end
