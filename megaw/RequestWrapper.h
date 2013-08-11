//
//  RequestWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#include "megacpp/mega.h"
#include "megacpp/megacrypto.h"

@class MegaClientWrapper;

@interface RequestWrapper : NSObject
{
    NSMutableArray* cmds;
}

-(id) init;

-(void) add:(id)cmd;

-(int) cmdspending;

-(int) get:(NSData*)req;

-(void) procresult:(MegaClientWrapper*)client;

@end

// HttpReq states
typedef enum { REQ_READY, REQ_INFLIGHT, REQ_SUCCESS, REQ_FAILURE } reqstatus;

typedef enum { REQ_BINARY, REQ_JSON } contenttype;

@interface HttpRequestWrapper : NSObject
{
    @public
    reqstatus status;
    int ft_idx;
    
	int httpstatus;
    
    int direction; //Added. Client to server: 0. Server to client: 1. File transfer: 2. PutFA 3.
    
	contenttype type;
    
	NSMutableString* posturl;
    
    NSMutableData* out; //Use NSData to represent data to post.
    
    NSMutableData* in; //Use NSData to represent data response.
    
    byte* buf; //These buffer remains the same, used for binary mode transfer.
	int buflen, bufpos;
    
    id httpiohandle;
    
    RequestWrapper* target;
}

-(id) init;

// set url and data range
-(void) setreq:(NSString*)u withtype:(contenttype)t;

-(void) post:(MegaClientWrapper*)client isbulk:(int)bulk withdata:(const char*)data andlen:(unsigned)len;

-(void) put:(const void*)data withlen:(int)len;

-(off_t) transferred:(MegaClientWrapper*)client;

@end