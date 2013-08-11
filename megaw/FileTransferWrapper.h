//
//  FileTransferWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#import "RequestWrapper.h"
#import "MegaClientWrapper.h"
#include "megacpp/mega.h"
#include "megacpp/megacrypto.h"

static const int UPLOADTOKENLEN = 27;
static const int DLRETRYINTERVAL = 120;
static const int DLMAXFAIL = 64;

@interface FileTransferWrapper : NSObject
{
    @public
    int inuse;
    int ft_idx;
    
	NSFileHandle* file;
    
	off_t progressinflight, progresscompleted;
	off_t pos, size;
	off_t startpos, endpos;
    off_t startblock;
	
	uint32_t starttime;
	
	uint32_t nextattempt;
	int failcount;
	
		
    //	byte key[Node::FILENODEKEYLENGTH];
	int64_t ctriv;
	int64_t metamac;
    
	SymmCipher key;
    
	NSString* tempurl;
	
	NSMutableString* filename;
    
	int upload;
    
    handle uploadhandle;
	
	int connections;
	NSMutableArray* reqs;
    
	NSMutableDictionary* chunkmacs;
}

-(id) initWithIndex:(int)idx;

-(void) init:(off_t)s andfilename:(NSString*)fn andconnection:(int)c;

-(void) doio:(MegaClientWrapper*)client;

-(void) issue_request:(MegaClientWrapper*)client withreq:(HttpRequestWrapper*)req;

-(void) doio_success:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req anddata:(NSData *)data;

-(void) doio_fail:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req anderror:(error)err_num andcode:(int)httpcode;

-(void) doio_update:(MegaClientWrapper*)client withreq:(HttpRequestWrapper *)req bytesdone:(uint64_t)done_bytes bytestotal:(uint64_t)total_bytes bytesexpect:(uint64_t)expect_bytes;

-(void) close;

-(int64_t) macsmac:(NSMutableDictionary*)macs;

@end

@protocol HttpReqXferWrapper

-(void) preprare:(NSFileHandle*)file withurl:(NSString*)tempurl andkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)pos andnpos:(off_t)npos;

-(void) finalize_trans:(NSFileHandle*)file withkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)startpos andnpos:(off_t)endpos;

@end

@interface HttpReqULWrapper : HttpRequestWrapper<HttpReqXferWrapper>
{
    @public
    off_t size;
}

-(id) initWithIndex:(int)idx;

-(void) preprare:(NSFileHandle*)file withurl:(NSString*)tempurl andkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)pos andnpos:(off_t)npos;

-(void) finalize_trans:(NSFileHandle*)file withkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)startpos andnpos:(off_t)endpos;

-(off_t) transferred:(MegaClientWrapper *)client;

@end

@interface HttpReqDLWrapper : HttpRequestWrapper<HttpReqXferWrapper>
{
    @public
    off_t size;
    off_t dlpos;
}

-(id) initWithIndex:(int)idx;

-(void) preprare:(NSFileHandle*)file withurl:(NSString*)tempurl andkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)pos andnpos:(off_t)npos;

-(void) finalize_trans:(NSFileHandle*)file withkey:(SymmCipher *)key andmacs:(NSMutableDictionary*)macs andctr:(uint64_t)ctriv andpos:(off_t)startpos andnpos:(off_t)endpos;

@end
