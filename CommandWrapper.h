//
//  CommandWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"
#import "MegaAppWrapper.h"
#import "ShareWrapper.h"
#import "NodeWrapper.h"

@class HttpRequestWrapper;
@class AccountDetailsWrapper;

@interface CommandWrapper : NSObject
{
    NSMutableDictionary* json;
    error result;
}

-(id) init;

-(void) cmd:(NSString*)cmd;

-(void) arg_str:(NSString*)name withstr:(NSString*)value;

-(void) arg_num:(NSString*)name withnum:(NSNumber*)value;

-(void) arg_bin:(NSString*)name withbuf:(const byte*)value andlen:(int)len;

-(NSString *) element:(byte *)value andlen:(int)len;

-(void) arg_array:(NSString*)name witharray:(NSMutableArray*)array;

-(void) arg_dict:(NSString*)name withdic:(NSMutableDictionary*)dict;

-(void) notself:(MegaClientWrapper*)client;

-(NSMutableDictionary *) getdict;

@end

@protocol CommandResult

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface HttpReqCommandPutFAWrapper : CommandWrapper<CommandResult>
{
    @public
    handle th;
	fatype type;
	byte* data;
	unsigned len;
    
    HttpRequestWrapper* http_req;
}

-(id) initWithHandle:(handle)cth withctype:(fatype)ctype withdata:(byte*)cdata andlen:(unsigned)clen;

-(void) dealloc;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

-(void) sethandle:(MegaClientWrapper*)client withhandle:(handle)fah;

@end

@interface CommandLoginWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client andemail:(NSString*)e andemailhash:(byte*)emailhash;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandSetMasterKeyWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client andok:(const byte*)oldkey andnk:(const byte*)newkey andhash:(const byte*)hash;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandFetchNodesWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandKeyCRWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client andsharearray:(NSArray *)rshares andsharenode:(NSArray *)rnodes andArraykey:(NSArray *)key_arrary;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandPubKeyRequestWrapper : CommandWrapper<CommandResult>
{
    UserWrapper* u;
}

-(id) initWithClient:(MegaClientWrapper*)client anduser:(UserWrapper *)user;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandShareKeyUpdateWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client andsharehandle:(handle)sh anduid:(NSString*)uid andkeybuffer:(const byte*)key andkeylen:(int)len;

-(id) initWithClient:(MegaClientWrapper*)client andhandlevalue:(NSArray*)v;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandNodeKeyUpdateWrapper : CommandWrapper<CommandResult>

-(id) initWithClient:(MegaClientWrapper*)client andhandlevalue:(NSArray*)v;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandMoveNodeWrapper : CommandWrapper<CommandResult>
{
    handle h;
}

-(id) initWithClient:(MegaClientWrapper*)client withnode:(NodeWrapper*)n tonode:(NodeWrapper*)t;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandDelNodeWrapper : CommandWrapper<CommandResult>
{
    handle h;
}

-(id) initWithClient:(MegaClientWrapper*)client withnode:(handle)th;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetFileWrapper : CommandWrapper<CommandResult>

{
    int td;
    int connections;
}

-(id) initWithtd:(int)t andhandle:(handle)h andp:(int)p andconn:(int)c;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandPutFileWrapper : CommandWrapper<CommandResult>
{
    int td;
    NSFileHandle* file;
    int connections;
}

-(id) initWithtd:(int)t andfile:(NSFileHandle *)f andms:(int)ms andconn:(int)c;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandAttachFAWrapper : CommandWrapper<CommandResult>

-(id) initWithNode:(NodeWrapper*)n;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandPutNodesWrapper : CommandWrapper<CommandResult>
{
    NSMutableArray* ulhandles;
}

-(id) initWithClient:(MegaClientWrapper*)client withhandle:(handle)th withtargettype:(targettype)t withnewnode:(NSMutableArray *)n;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandSetAttrWrapper : CommandWrapper<CommandResult>
{
    handle h;
}

-(id) initWithClient:(MegaClientWrapper*)client andnode:(NodeWrapper *)n;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandSetShareWrapper : CommandWrapper<CommandResult>
{
    handle sh;
    NSString* uid;
    accesslevel access;
}

-(id) initWithClient:(MegaClientWrapper*)client withNode:(NodeWrapper*)n anduser:(UserWrapper*)u andaccesslevel:(accesslevel)a andnewshare:(int)newshare;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandSetPHWrapper : CommandWrapper<CommandResult>
{
    handle h;
}

-(id) initWithClient:(MegaClientWrapper*)client withNode:(NodeWrapper*)n anddel:(int)del;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetPHWrapper : CommandWrapper<CommandResult>
{
    handle ph;
	byte key[FILENODEKEYLENGTH];
}

-(id) initWithClient:(MegaClientWrapper*)client withhandle:(handle)cph andkey:(const byte*)ckey;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetUserQuotaWrapper : CommandWrapper<CommandResult>
{
    AccountDetailsWrapper* details;
    int got_storage, got_transfer, got_pro;
}

-(id) initWithClient:(MegaClientWrapper*)client withaccount:(AccountDetailsWrapper*)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetUserTransactionsWrapper : CommandWrapper<CommandResult>
{
    AccountDetailsWrapper* details;
}

-(id) initWithClient:(MegaClientWrapper*)client withaccount:(AccountDetailsWrapper*)ad;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetUserPurchasesWrapper : CommandWrapper<CommandResult>
{
    AccountDetailsWrapper* details;
}

-(id) initWithClient:(MegaClientWrapper*)client withaccount:(AccountDetailsWrapper*)ad;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end

@interface CommandGetUserSessionsWrapper : CommandWrapper<CommandResult>
{
    AccountDetailsWrapper* details;
}

-(id) initWithClient:(MegaClientWrapper*)client withaccount:(AccountDetailsWrapper*)ad;

-(void) procresult:(MegaClientWrapper*)client withdata:(id)json_data;

@end