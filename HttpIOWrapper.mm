//
//  HttpIOWrapper.m
//  testioslib
//

#import "HttpIOWrapper.h"
#import "MegaClientWrapper.h"
#import "MegaAppWrapper.h"
#import "RequestWrapper.h"
#import "AFHTTPRequestOperation.h"
#import "FileTransferWrapper.h"

@implementation HttpIOWrapper

-(void) post:(HttpRequestWrapper*)req isbulk:(int)bulk withdata:(const char*)data andlen:(unsigned)len;
{
    NSURL* url = [NSURL URLWithString:req->posturl];
    NSMutableURLRequest* url_req = [NSMutableURLRequest requestWithURL:url];
    if (len > 0)
    {
        [url_req setHTTPBody:[NSData dataWithBytesNoCopy:(void*)data length:len freeWhenDone:NO]];
        [url_req setHTTPMethod:@"PUT"];
    } else if ([req->out length] > 0)
    {
        [url_req setHTTPBody:req->out];
        [url_req setHTTPMethod:@"PUT"];
    }
    
    AFHTTPRequestOperation* myaction = [[AFHTTPRequestOperation alloc] initWithRequest:url_req];
    req->status = REQ_INFLIGHT;    
    [myaction setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (!operation.responseData) {
            req->status = REQ_FAILURE;
            [client->app_wrapper request_error:client witherror:API_EINTERNAL];
            return;
        }
        req->status = REQ_SUCCESS;
        [client exec_process_success:req withdata:operation.responseData];
    } failure:^(AFHTTPRequestOperation *operation, NSError *err) {
        error err_num = (error)[err code];
        req->status = REQ_FAILURE;
        [client->app_wrapper request_error:client witherror:err_num];
        [client exec_process_failure:req witherr:err_num];
    }];
    
    [client->http_queue addOperation:myaction];
}

-(void) post:(HttpRequestWrapper *)req withft:(FileTransferWrapper *)ft
{

    NSURL* url = [NSURL URLWithString:req->posturl];
    NSMutableURLRequest* url_req = [NSMutableURLRequest requestWithURL:url];
    if ([req->out length] > 0)
    {
        [url_req setHTTPBody:req->out];
        [url_req setHTTPMethod:@"PUT"];
    }
    AFHTTPRequestOperation* myaction = [[AFHTTPRequestOperation alloc] initWithRequest:url_req];
    req->status = REQ_INFLIGHT;
    [myaction setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData* result_data = [NSData data];
        if (operation.responseData) {
            result_data = operation.responseData;
        }
        req->status = REQ_SUCCESS;
        [ft doio_success:client withreq:req anddata:result_data];
    } failure:^(AFHTTPRequestOperation *operation, NSError *err) {
        error err_num = (error)[err code];
        req->status = REQ_FAILURE;
        [ft doio_fail:client withreq:req anderror:err_num andcode:[operation.response statusCode]];
    }];
    
    if (ft->upload)
    {
        [myaction setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            [ft doio_update:client withreq:req bytesdone:bytesWritten bytestotal:totalBytesWritten bytesexpect:totalBytesExpectedToWrite];
        }];
    }
    else
    {
        [myaction setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            [ft doio_update:client withreq:req bytesdone:bytesRead bytestotal:totalBytesRead bytesexpect:totalBytesExpectedToRead];
        }];
    }
    [client->http_queue addOperation:myaction];
}

-(off_t) postpos:(id)handle
{
    return 0;
}

-(void) remove:(HttpRequestWrapper*)req
{
    
}

-(int) doio
{
    return 0;
}

-(void) waitio:(uint32_t)ds
{
    
}

@end
