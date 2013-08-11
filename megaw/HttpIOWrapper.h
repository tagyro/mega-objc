//
//  HttpIOWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>

@class HttpRequestWrapper;
@class MegaClientWrapper;
@class FileTransferWrapper;

@interface HttpIOWrapper : NSObject
{
    @public
    MegaClientWrapper* client;
}

-(void) post:(HttpRequestWrapper*)req isbulk:(int)bulk withdata:(const char*)data andlen:(unsigned)len;

-(void) post:(HttpRequestWrapper *)req withft:(FileTransferWrapper *)ft;

-(off_t) postpos:(id)handle;

-(void) remove:(HttpRequestWrapper*)req;

-(int) doio;

-(void) waitio:(uint32_t)ds;

@end
