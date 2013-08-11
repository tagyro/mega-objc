//
//  NodeWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"
#import "FileTransferWrapper.h"

static const int FILENODEKEYLENGTH = 32;
static const int FOLDERNODEKEYLENGTH = 16;

// Node types:
// FILE - regular file nodes
// FOLDER - regular folder nodes
// ROOT - the cloud drive root node
// INCOMING - inbox
// RUBBISH - rubbish bin
typedef enum { TYPE_UNKNOWN = -1, FILENODE = 0, FOLDERNODE, ROOTNODE, INCOMINGNODE, RUBBISHNODE, MAILNODE } nodetype;

@class ShareWrapper;

@interface NodeCoreWrapper : NSObject
{
    @public
    // node's own handle
	handle nodehandle;
    
	// parent node handle
	handle parent;

    // node type
	nodetype type;

    // number of valid key bytes depends on type
	byte nodekey[FILENODEKEYLENGTH];
	int keylen;

    // creation and modification times
	time_t ctime;
	time_t mtime;

    // node attributes
    NSString* attrstring;
}

-(id) init;

-(void) copyfromother:(NodeCoreWrapper *)copy;

@end

@interface NodeWrapper : NodeCoreWrapper
{
    @public
	
	// node crypto keys
	NSString* keystring;

	// node-specific key
	SymmCipher key;
    
	// node attributes
	NSMutableDictionary* attrs;
    
	// owner
	handle owner;
        
	// FILENODE nodes only: size, nonce, meta MAC, attributes
	off_t size;
    
	int64_t ctriv;
	int64_t metamac;
	
	NSMutableDictionary* fileattrs;
    
	// inbound share
	ShareWrapper* inshare;
    
	// outbound shares by user
	NSMutableDictionary* outshares;
    
	// incoming/outgoing share key
	SymmCipher* sharekey;
	
	// authenticated outgoing share
	int outshare;
	
	// pointer private to the app
	id appdata;
	
	BOOL removed;
    BOOL notified;
}

+(void) copystring:(NSString *)s from:(const char*)p;

+(byte*) decryptattr:(SymmCipher*)key from:(NSString*)attrstring;

-(id) initWithHandle:(handle)h parent:(handle)p withtype:(nodetype)t withsize:(size_t)s withowner:(handle)u withattrstr:(NSString*)a withkeystr:(NSString*)k withfileattrstr:(NSString*)fa withmodtime:(time_t)tm withcreatetime:(time_t)ts withshare:(ShareWrapper*)share;

-(void) dealloc;

// try to resolve node key string
-(int) applykey:(MegaClientWrapper*)client with:(handle)nh;

// decrypt attribute string and set fileattrs
-(void) setattr;

// display name (UTF-8)
-(const char*) displayname;

-(void) setkey:(byte*)newkey;

-(void) faspec:(NSMutableString*)fa;

@end

// New node source types
typedef enum { NEW_NODE, NEW_PUBLIC, NEW_UPLOAD } newnodesource;

@interface NewNodeWrapper : NodeCoreWrapper
{
    @public
    newnodesource source;
    
	handle uploadhandle;
	byte uploadtoken[UPLOADTOKENLEN];
    
    NSMutableData* attrdata;
	
}

-(id) init;

@end
