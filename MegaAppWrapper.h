//
//  MegaAppWrapper.h
//  megaios
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"

//#include <curl/curl.h>

#include "megacpp/mega.h"
#include "megacpp/megacrypto.h"
//#include "megacpp/megaclient.h"
//#include "megacpp/megaapp.h"

//class MegaAppCpp;

@class NodeWrapper;
@class UserWrapper;
@class AccountDetailsWrapper;

@interface MegaAppWrapper : NSObject

{
    int urandomfd;
    
    handle uploadtarget_wrapper;
    NSMutableString* uploadfilename_wrapper;
    
    int debug;
    handle cwd;
    //MegaAppCpp* inner_cpp_app;
}

-(id) init;

-(void) dealloc;

//-(MegaAppCpp*) get_inner_cpp_app;

-(uint32_t) dstime;

-(uint64_t) rnd:(uint64_t)max;
-(void) rnd:(byte*)buf withlength:(int)len;

//-(FileAccess*) newfile;

-(void) request_error:(MegaClientWrapper*)client witherror:(error)err;

-(void) login_result:(MegaClientWrapper*)client witherror:(error)err;

-(void) user_updated:(MegaClientWrapper*)client withusers:(NSMutableArray*)user withcount:(int)count;
-(void) nodes_updated:(MegaClientWrapper*)client withnodes:(NSMutableArray*)nodes withcount:(int)count;

-(int) prepare_download:(MegaClientWrapper*)client withnode:(NodeWrapper*)node;

-(void) setattr_result:(MegaClientWrapper*)client withhandle:(handle)h witherror:(error)err;
-(void) rename_result:(MegaClientWrapper*)client withhandle:(handle)h witherror:(error)err;
-(void) unlink_result:(MegaClientWrapper*)client withhandle:(handle)h witherror:(error)err;

-(void) fetchnodes_result:(MegaClientWrapper*)client witherror:(error)err;

-(void) putnodes_result:(MegaClientWrapper*)client witherror:(error)err;

-(void) share_result:(MegaClientWrapper*)client witherror:(error)err;
-(void) share_result:(MegaClientWrapper*)client withidx:(int)idx witherror:(error)err;

-(void) account_details:(MegaClientWrapper*)client withaccount:(AccountDetailsWrapper*)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro withpurchases:(int)purchases withtransactions:(int)transactions withsessions:(int)sessions;

-(void) exportnode_result:(MegaClientWrapper*)client witherror:(error)err;
-(void) exportnode_result:(MegaClientWrapper*)client withhandle:(handle)h withph:(handle)ph;

-(void) openfilelink_result:(MegaClientWrapper*)client witherror:(error)err;
-(void) openfilelink_result:(MegaClientWrapper*)client withnode:(NodeWrapper*)n;

-(void) topen_result:(MegaClientWrapper*)client withtd:(int)td witherror:(error)err;
-(void) topen_result:(MegaClientWrapper*)client withtd:(int)td withfilename:(NSMutableString *)filename withattr:(const char*)fa withpfa:(int)pfa;

-(void) transfer_update:(MegaClientWrapper*)client withtd:(int)td withbytes:(off_t)bytes withsize:(off_t)size withstarttime:(uint32_t)starttime;
-(void) transfer_error:(MegaClientWrapper*)client withtd:(int)td withhttpcode:(int)httpcode withcount:(int)count;
-(void) transfer_failed:(MegaClientWrapper*)client withtd:(int)td witherror:(error)err;
-(void) transfer_failed:(MegaClientWrapper*)client withtd:(int)td withfilename:(NSString*)filename witherror:(error)err;
-(void) transfer_limit:(MegaClientWrapper*)client withtd:(int)td;
-(void) transfer_complete:(MegaClientWrapper*)client withtd:(int)td withchunk:(NSMutableDictionary*)chunkmac withfilename:(NSString*)fn;
-(void) transfer_complete:(MegaClientWrapper*)client withtd:(int)td withulhandle:(handle)ulhandle withultoken:(const byte*)ultoken withfilekey:(const byte*)filekey withcryptokey:(SymmCipher*)key;
-(void) changepw_result:(MegaClientWrapper*)client witherror:(error)err;

-(void) reload:(MegaClientWrapper*)client withreason:(NSString*)reason;

-(void) notify_retry:(MegaClientWrapper*)client intime:(int)ds;
-(void) debug_log:(MegaClientWrapper*)client withmsg:(NSString *)message;

@end
