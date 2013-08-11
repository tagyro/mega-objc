//
//  MegaClientWrapper.h
//  megaios
//

#import <Foundation/Foundation.h>
#include "megacpp/mega.h"
#include "megacpp/megacrypto.h"
//#include "megacpp/megaclient.h"

// General error codes
typedef enum {
    API_OK = 0,
    API_EINTERNAL = -1,     // internal error
    API_EARGS = -2,         // bad arguments
    API_EAGAIN = -3,        // request failed, retry with exponential backoff
    API_ERATELIMIT = -4,    // too many requests, slow down
    API_EFAILED = -5,       // request failed permanently
    API_ETOOMANY = -6,      // too many requests for this resource
    API_ERANGE = -7,        // resource access out of rage
    API_EEXPIRED = -8,      // resource expired
    API_ENOENT = -9,        // resource does not exist
    API_ECIRCULAR = -10,    // circular linkage
    API_EACCESS = -11,      // access denied
    API_EEXIST = -12,       // resource already exists
    API_EINCOMPLETE = -13,  // request incomplete
    API_EKEY = -14,         // cryptographic error
    API_ESID = -15,         // bad session ID
    API_EBLOCKED = -16,     // resource administratively blocked
    API_EOVERQUOTA = -17,   // quote exceeded
    API_ETEMPUNAVAIL = -18, // resource temporarily not available
    API_ETOOMANYCONNECTIONS = -19, // too many connections on this resource
    API_EWRITE = -20,       // file could not be written to
    API_EREAD = -21,        // file could not be read from
    API_EAPPKEY = -22		// invalid or missing application key
} error;

typedef enum { SHARE, SHAREOWNERKEY, OUTSHARE } sharereadmode;

// Node/user handles are 8-11 base64 characters, case sensitive, and thus fit in a 64-bit int
typedef uint64_t handle;

// Undefined node handle
const handle UNDEF = ~(handle)0;

#define ISUNDEF(h) (!((h)+1))

typedef enum { USER_HANDLE, NODE_HANDLE } targettype;

// Access levels:
// RDONLY - cannot add, rename or delete
// RDWR - cannot rename or delete
// FULL - all operations that do not require ownership permitted
// OWNER - node is in caller's ROOT, INCOMING or RUBBISH trees
typedef enum { ACCESS_UNKNOWN = -1, RDONLY = 0, RDWR, FULL, OWNER } accesslevel;

// file attribute type
typedef uint16_t fatype;

@class NodeWrapper;
@class UserWrapper;
@class RequestWrapper;
@class HttpRequestWrapper;
@class HttpIOWrapper;
@class FileTransferWrapper;
@class MegaAppWrapper;
@class TreeProcWrapper;
@class PubKeyActionWrapper;
@class AccountDetailsWrapper;

@interface MegaClientWrapper : NSObject
{
    @public
    // own e-mail address
    NSString* myemail;
    
    NSObject* pending_lock;
    HttpRequestWrapper* pending;
    uint32_t nextattempt;
    int backoff;
    
    NSObject* pendingsc_lock;
    HttpRequestWrapper* pendingsc;
    uint32_t nextattemptsc;
    int backoffsc;
    
    uint32_t nextattemptputfa;
	int backoffputfa;
    
    NSOperationQueue* http_queue;
    
    NSString* apiurl;
    
    NSString* scnotifyurl;
    
    //public: (in c++)
    //MegaClient* inner_client;
    
    NSMutableArray* nodekeyrewrite;
    NSMutableArray* sharekeyrewrite;
    NSMutableArray* nodenotify;
    NSMutableArray* usernotify;
    
    NSMutableDictionary* nodes;
    NSMutableDictionary* newshares;
    NSMutableDictionary* userpubk;
    NSMutableDictionary* users;
    
    // up two concurrent filetransfers
	FileTransferWrapper* ft[2];
    
    // pending file attributes
    NSMutableDictionary* pendingfa;
    
    // active file attributes
	NSMutableDictionary* fileattrs;
    
    NSString* scsn;
    
    int req_sn;	
    RequestWrapper* reqs[2];
    
    NSMutableDictionary* children;
    NSMutableDictionary* uhnh;
    
    //MegaClient-Server response JSON
    NSData* json;
    
    // Server_MegaClient request JSON
    NSData* jsonsc;
    
    handle me;

    handle rootnodes[4];
    
    SymmCipher key;
    
    AsymmCipher asymkey;
    
    char reqid[11];
    NSMutableString* auth;
    char sessionid[10];
    NSString* appkey;
    
    int warned;
    
    NSMutableDictionary* uhindex;
    NSMutableDictionary* umindex;
    
    int userid;
    
    // pending file attribute writes
	NSMutableArray* newfa;
    
	// current attribute being sent
	int curfa;
    
    // next upload handle
    handle nextuh;
    
    MegaAppWrapper* app_wrapper;
    HttpIOWrapper* httpio_wrapper;
};

-(id) initWithApp:(MegaAppWrapper *)app andHttpIO:(HttpIOWrapper *)httpio andAppkey:(char *)k;

// generate attribute string based on the pending attributes for this upload
-(void) pendingattrstring:(handle)h tofa:(NSMutableString*)fa;

// allocate transfer descriptor in ft[]
-(int) alloctd;

-(void) purgenodes:(NSArray*)affected;
-(void) purgeusers:(NSArray*)affected;
-(int) readusers:(id)j;

-(void) exec;

-(void) exec_process_success:(HttpRequestWrapper*)http_req withdata:(NSData *)data;

-(void) exec_process_failure:(HttpRequestWrapper*)http_req witherr:(error)err;

// wait for I/O or other events
-(void) wait;

// user login: e-mail, pwkey
-(void) loginWithEmail: (NSString *)email andpw_key:(byte *)pwkey;

// check if logged in
-(int) loggedin;

// set folder link: node, key
-(error) folderaccess:(NSString*)f withk:(NSString*)k;

// open exported file link
-(error) openfilelink:(NSString*)link;

// change login password
-(error) changepw:(const byte*)oldpwkey tonewpw:(const byte*)newpwkey;

// load all trees: nodes, shares, contacts
-(void) fetchnodes;

// retrieve user details
-(void) getaccountdetails:(AccountDetailsWrapper*)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro withtransactions:(int)transactions withpurchases:(int)purchases withsessions:(int)sessions;

// update node attributes
-(void) setattr:(NodeWrapper*)n withnewattr:(NSMutableDictionary*)newattr;

// prefix and encrypt attribute json
-(void) makeattr:(SymmCipher*)attr_key withoutput:(NSMutableData*) attrstring andinput:(NSData*)attr_json;

// check node access level
-(int) checkaccess:(NodeWrapper*)n andaccess:(accesslevel)a;

// check if a move operation would succeed
-(error) checkmove:(NodeWrapper*)fn tonode:(NodeWrapper*)tn;

// delete node
-(error) unlink:(NodeWrapper*)n;

// move node to new parent folder
-(error) rename:(NodeWrapper*)n tonode:(NodeWrapper*)t;

// start upload
-(int) topen:(NSString *)localpath withms:(int)ms andconn:(int)c;

// start (partial) download
-(int) topen:(handle)h withkey:(const byte*)k andstart:(off_t)start andlen:(off_t)len andconn:(int)c;

// close/cancel transfer
-(void) tclose:(int)td;

// obtain upload handle
-(handle) uploadhandle:(int)td;

// open target file for download
-(void) dlopen:(int)td withfilename:(NSString*)tmpfilename;

// attach file attribute to a file
-(void) putfa:(SymmCipher*)filekey withhandle:(handle)th andtype:(fatype)t anddata:(const byte*)data andlen:(unsigned)len;

// add nodes (send files/folders to user, complete upload, copy files, make folders)
-(error) putnodes:(handle)h withtargettype:(targettype)t withnewnode:(NSMutableArray *)n;

// add/remove/update outgoing share
-(void) setshare:(NodeWrapper*)n touser:(NSString*)user withaccess:(accesslevel)a;

// export node link or remove existing exported link for this node
-(error) exportnode:(NodeWrapper*)n withdel:(int)del;

-(void) notifyuser:(UserWrapper*)u;

-(void) notifynode: (NodeWrapper*)n;

-(void) notifypurge;

-(NodeWrapper*) nodebyhandle:(handle)h;

// process object arrays by the API server
-(int) readnodes: (id)jsonresponse withnotify:(int)notify andhandles:(NSArray *)ulhandles;
-(int) readshares: (id)j withmode:(sharereadmode)mode andnotify:(int)notify;
-(void) readshare: (id)j withmode:(sharereadmode)mode andnotify:(int)notify;

-(void) warn: (NSString *)msg;

-(void) proccr:(id)json_data;
-(void) procsr:(id)json_data;

// apply keys
-(int) applykeys;

-(void) setparent:(NodeWrapper*)n withandle:(handle)h;

-(UserWrapper *) finduser:(NSString*)uid withadd:(int)add;
-(UserWrapper *) finduser:(handle)uh withnew:(int)add;
-(void) mapuser:(handle)uh withemail:(NSString *)email;

// queue public key request for user
-(void) queuepubkeyreq:(UserWrapper*)u andpubkey_action:(PubKeyActionWrapper*)pka;

// Hash string
-(void) stringhash:(const char*)s withhash:(byte*)hash andcipher:(SymmCipher*)cipher;

// Hash password
-(void) pw_key:(const char*)pw withkey:(byte*)pwkey;

// set configure authentication context
-(void) setsid:(const char*)sid;
-(void) setrootnode:(handle)h;

-(int) warnlevel;

// process node subtree
-(void) proctree:(NodeWrapper*)n withproc:(TreeProcWrapper*)tp;

-(void) setkey:(SymmCipher*)c withkey:(const char*)k;
-(int) decryptkey: (const char*)sk withtk:(byte*)tk withtl:(int)tl withsc:(SymmCipher*)sc withtype:(int)type withnode:(uint64_t)node;

-(void) handleauth:(handle)h withauth:(byte*)authbuf;

-(handle) convert_base64str_handle: (NSString *)stringvalue;

@end

@interface PairWrapper : NSObject

+(void) addPair:(NSMutableDictionary*)container withfirst:(handle)first_obj andSecond:(handle)second_obj;

+(void) delPair:(NSMutableDictionary*)container withfirst:(handle)first_obj andSecond:(handle)second_obj;

+(void) addPendingfa:(NSMutableDictionary*)container withfirst:(handle)first_obj andSecond:(uint16_t)second_obj andThird:(handle)third_obj;

@end