//
//  MegaAppWrapper.m
//  megaios
//

#import "MegaAppWrapper.h"
#import "NodeWrapper.h"
#import "ShareWrapper.h"
#import "UserWrapper.h"
#import "AccountWrapper.h"
#import "Base64Wrapper.h"

const char* errorstring(error e)
{
	switch (e)
	{
		case API_OK:
			return "No error";
		case API_EINTERNAL:
			return "Internal error";
		case API_EARGS:
			return "Invalid argument";
		case API_EAGAIN:
			return "Request failed, retrying";
		case API_ERATELIMIT:
			return "Rate limit exceeded";
		case API_EFAILED:
			return "Transfer failed";
		case API_ETOOMANY:
			return "Too many concurrent connections or transfers";
		case API_ERANGE:
			return "Out of range";
		case API_EEXPIRED:
			return "Expired";
		case API_ENOENT:
			return "Not found";
		case API_ECIRCULAR:
			return "Circular linkage detected";
		case API_EACCESS:
			return "Access denied";
		case API_EEXIST:
			return "Already exists";
		case API_EINCOMPLETE:
			return "Incomplete";
		case API_EKEY:
			return "Invalid key/Decryption error";
		case API_ESID:
			return "Bad session ID";
		case API_EBLOCKED:
			return "Blocked";
		case API_EOVERQUOTA:
			return "Over quota";
		case API_ETEMPUNAVAIL:
			return "Temporarily not available";
		case API_ETOOMANYCONNECTIONS:
			return "Connection overflow";
		case API_EWRITE:
			return "Write error";
		case API_EREAD:
			return "Read error";
		case API_EAPPKEY:
			return "Invalid application key";
		default:
			return "Unknown error";
	}
}

void nodepath(MegaClientWrapper*client, handle h, NSMutableString* path)
{
	if (h == client->rootnodes[0])
	{
        path = [NSMutableString stringWithString:@"/"];
		return;
	}
    
	NodeWrapper* n = [client nodebyhandle:h];
    
	while (n)
	{
		switch (n->type)
		{
			case FOLDERNODE:
                [path insertString:[NSString stringWithUTF8String:[n displayname]] atIndex:0];
                
				if (n->inshare)
				{
                    [path insertString:@":" atIndex:0];
					if (n->inshare->user) [path insertString:n->inshare->user->email atIndex:0];
					else [path insertString:@"UNKNOWN" atIndex:0];
					return;
				}
				break;
                
			case INCOMINGNODE:
                [path insertString:@"//in" atIndex:0];
				return;
                
			case ROOTNODE:
				return;
                
			case RUBBISHNODE:
                [path insertString:@"//bin" atIndex:0];
				return;
                
			case MAILNODE:
                [path insertString:@"//mail" atIndex:0];
				return;
                
			case TYPE_UNKNOWN:
			case FILENODE:
				[path insertString:[NSString stringWithUTF8String:[n displayname]] atIndex:0];
		}
        
        [path insertString:@"/" atIndex:0];
        
		n = [client nodebyhandle:n->parent];
	}
}

void nodestats(int* c, const char* action)
{
	if (c[FILENODE]) cout << c[FILENODE] << ((c[FILENODE] == 1) ? " file" : " files");
	if (c[FILENODE] && c[FOLDERNODE]) cout << " and ";
	if (c[FOLDERNODE]) cout << c[FOLDERNODE] << ((c[FOLDERNODE] == 1) ? " folder" : " folders");
	if (c[MAILNODE] && (c[FILENODE] || c[FOLDERNODE])) cout << " and ";
	if (c[MAILNODE]) cout << c[MAILNODE] << ((c[MAILNODE] == 1) ? " mail" : " mails");
    
	if (c[FILENODE] || c[FOLDERNODE] || c[MAILNODE]) cout << " " << action << endl;
}

@implementation MegaAppWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    //self->inner_cpp_app = new MegaAppCpp();
    //inner_cpp_app->wrapper = self;
    
    uploadtarget_wrapper = UNDEF;
    uploadfilename_wrapper = [NSMutableString string];
    
    debug = 0;
    cwd = UNDEF;
    
    urandomfd = open("/dev/urandom",O_RDONLY);
    assert(urandomfd >= 0);
    return self;
}

-(void) dealloc
{
    if (urandomfd >= 0)
        close(urandomfd);
}

-(uint32_t) dstime
{
    clock_t ts;

    ts = clock();

    return ts * 10 / CLOCKS_PER_SEC;
}

-(uint64_t) rnd:(uint64_t)max
{
    uint64_t t;
    
    assert(read(urandomfd,(char*)&t,sizeof(t)) == sizeof(t));
        
    return t/((~(uint64_t)0)/max);
}

-(void) rnd:(byte*)buf withlength:(int)len
{
    assert(read(urandomfd,buf,len) == len);
}

/*-(FileAccess*) newfile
{
    return new PosixFileAccess();
}*/

-(void) request_error:(MegaClientWrapper*)client witherror:(error)err
{
    cout << "Request failed: code " << err << endl;
}

-(void) login_result:(MegaClientWrapper*)client witherror:(error)err
{
    if (err == API_OK)
	{
		cout << "Login successful, retrieving account..." << endl;
		[client fetchnodes];
	}
	else cout << "Login failed: " << errorstring(err) << endl;    
}

-(void) nodes_updated:(MegaClientWrapper*)client withnodes:(NSMutableArray *)nodes withcount:(int)count
{
    int c[2][6] = {{ 0 }};
	
    if (nodes)
    {
        while (count--)
        {
            NodeWrapper* n = [nodes objectAtIndex:count];
            if (n == nil)
                continue;
        
            if (n->type < 6)
                c[!n->removed][n->type]++;
        }
    }
    else
    {
        NSEnumerator* enumerator = [client->nodes objectEnumerator];
        NodeWrapper* n;
        while (n=[enumerator nextObject])
        {
            if (n->type < 6)
                c[1][n->type]++;
        }
    }

    nodestats(c[1],"added or updated");
	nodestats(c[0],"removed");
    
    if (ISUNDEF(cwd)) cwd = client->rootnodes[0];
}

-(int) prepare_download:(MegaClientWrapper*)client withnode:(NodeWrapper*)node
{
    return 0;
}

-(void) setattr_result:(MegaClientWrapper *)client withhandle:(handle)h witherror:(error)err
{
    cout << "Node attribute update failed (" << errorstring(err) << ")" << endl;
}

-(void) rename_result:(MegaClientWrapper *)client withhandle:(handle)h witherror:(error)err
{
    cout << "Node move failed (" << errorstring(err) << ")" << endl;
}

-(void) unlink_result:(MegaClientWrapper *)client withhandle:(handle)h witherror:(error)err
{
    cout << "Node deletion failed (" << errorstring(err) << ")" << endl;
}

-(void) user_updated:(MegaClientWrapper *)client withusers:(NSMutableArray *)user withcount:(int)count
{
    if (count == 1) cout << "1 user received" << endl;
	else cout << count << " users received" << endl;
}

-(void) fetchnodes_result:(MegaClientWrapper *)client witherror:(error)err
{
    cout << "File/folder retrieval failed (" << errorstring(err) << ")" << endl;
}

-(void) putnodes_result:(MegaClientWrapper *)client witherror:(error)err
{
    cout << "Node addition failed (" << errorstring(err) << ")" << endl;
}

-(void) share_result:(MegaClientWrapper*)client witherror:(error)err
{
    cout << "Node addition failed (" << errorstring(err) << ")" << endl;
}

-(void) share_result:(MegaClientWrapper*)client withidx:(int)idx witherror:(error)err
{
    cout << "Share creation/modification request failed (" << errorstring(err) << ")" << endl;
}

-(void) account_details:(MegaClientWrapper *)client withaccount:(AccountDetailsWrapper *)ad withstorage:(int)storage withtransfer:(int)transfer withpro:(int)pro withpurchases:(int)purchases withtransactions:(int)transactions withsessions:(int)sessions
{
    char timebuf[32], timebuf2[32];
    
	cout << "Account e-mail: " << client->myemail << endl;
    
	if (storage)
	{
		cout << "\tStorage: " << ad->storage_used << " of " << ad->storage_max << " (" << (100*ad->storage_used/ad->storage_max) << "%)" << endl;
	}
    
	if (transfer)
	{
		if (ad->transfer_max)
		{
			cout << "\tTransfer: " << ad->transfer_own_used << "/" << ad->transfer_srv_used << " of " << ad->transfer_max << " (" << (100*(ad->transfer_own_used+ad->transfer_srv_used)/ad->transfer_max) << "%)" << endl;
			cout << "\tServing bandwidth ratio: " << ad->srv_ratio << "%" << endl;
		}
	}
    
	if (pro)
	{
		cout << "\tPro level: " << ad->pro_level << endl;
		cout << "\tSubscription type: " << ad->subscription_type << endl;
		cout << "\tAccount balance:" << endl;
        
		for (AccountBalanceWrapper* it in ad->balances)
		{
			printf("\tBalance: %.3s %.02f\n",it->currency,it->amount);
		}
	}
    
	if (purchases)
	{
		cout << "Purchase history:" << endl;
        
		for (AccountPurchaseWrapper* it in ad->purchases)
		{
			strftime(timebuf,sizeof timebuf,"%c",localtime(&it->timestamp));
			printf("\tID: %.11s Time: %s Amount: %.3s %.02f Payment method: %d\n",it->local_handle,timebuf,it->currency,it->amount,it->method);
		}
	}
    
	if (transactions)
	{
		cout << "Transaction history:" << endl;
        
		for (AccountTransactionWrapper* it in ad->transactions)
		{
			strftime(timebuf,sizeof timebuf,"%c",localtime(&it->timestamp));
			printf("\tID: %.11s Time: %s Delta: %.3s %.02f\n",it->local_handle,timebuf,it->currency,it->delta);
		}
	}
    
	if (sessions)
	{
		cout << "Session history:" << endl;
        
		for (AccountSessionWrapper* it in ad->sessions)
		{
			strftime(timebuf,sizeof timebuf,"%c",localtime(&it->timestamp));
			strftime(timebuf2,sizeof timebuf,"%c",localtime(&it->mru));
			printf("\tSession start: %s Most recent activity: %s IP: %s Country: %.2s User-Agent: %s\n",timebuf,timebuf2,[it->ip UTF8String],it->country,[it->useragent UTF8String]);
		}
	}
}

-(void) topen_result:(MegaClientWrapper*)client withtd:(int)td witherror:(error)err
{
    cout << "TD " << td << ": Failed to open file (" << errorstring(err) << ")" << endl;

    [uploadfilename_wrapper setString:@""];

    [client tclose:td];
}

-(void) topen_result:(MegaClientWrapper*)client withtd:(int)td withfilename:(NSMutableString *)filename withattr:(const char*)fa withpfa:(int)pfa
{
    cout << "TD " << td << ": File opened successfully, filename: " << [filename UTF8String] << endl;
    
	if (fa) cout << "File has attributes: " << fa << " / " << pfa << endl;
    
	// sanitize filename
    [filename replaceOccurrencesOfString:@"\\/:?\"<>|" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [filename length])];
	
	NSMutableString* tmpfilename = filename;
	
	[tmpfilename appendString:@".tmp"];
    [client dlopen:td withfilename:tmpfilename];
}

-(void) transfer_update:(MegaClientWrapper*)client withtd:(int)td withbytes:(off_t)bytes withsize:(off_t)size withstarttime:(uint32_t)starttime
{
    cout << "TD " << td << ": Update: " << bytes/1024 << " KB of " << size/1024 << " KB, " << bytes*10/(1024*([self dstime]-starttime)+1) << " KB/s" << endl;
}

-(void) transfer_error:(MegaClientWrapper*)client withtd:(int)td withhttpcode:(int)httpcode withcount:(int)count
{
    cout << "TD " << td << ": Failed, HTTP error code " << httpcode << " (count " << count << ")" << endl;
	
	[uploadfilename_wrapper setString:@""];
	[client tclose:td];

}

-(void) transfer_failed:(MegaClientWrapper*)client withtd:(int)td witherror:(error)err
{
    cout << "TD " << td << ": Upload failed, error code " << errorstring(err) << endl;
    
	[uploadfilename_wrapper setString:@""];
	[client tclose:td];
}

-(void) transfer_failed:(MegaClientWrapper*)client withtd:(int)td withfilename:(NSString *)filename witherror:(error)err
{
    cout << "TD " << td << ": Download failed, error code " << errorstring(err) << endl;
	
    NSMutableString* tmpfilename = [NSMutableString stringWithString:filename];
    [tmpfilename appendString:@".tmp"];
	unlink([tmpfilename UTF8String]);
    
	[client tclose:td];
}

-(void) transfer_limit:(MegaClientWrapper*)client withtd:(int)td
{
    cout << "TD " << td << ": Transfer limit reached, retrying..." << endl;
}

-(void) transfer_complete:(MegaClientWrapper*)client withtd:(int)td withchunk:(NSMutableDictionary*)chunkmac withfilename:(NSString*)fn
{
    cout << "TD " << td << ": Download complete" << endl;
    
	NSMutableString* tmpfilename = [NSMutableString stringWithString:fn];
	NSMutableString* filename = [NSMutableString stringWithString:fn];
    
	[tmpfilename appendString:@".tmp"];
    
	if (!rename([tmpfilename UTF8String],[filename UTF8String])) cout << "TD " << td << ": Download complete: " << [filename UTF8String] << endl;
	else cout << "TD " << td << ": rename(" << [tmpfilename UTF8String] << "," << [filename UTF8String] << ") failed (" << errno << ")" << endl;
	
	[client tclose:td];
}

-(void) transfer_complete:(MegaClientWrapper *)client withtd:(int)td withulhandle:(handle)ulhandle withultoken:(const byte *)ultoken withfilekey:(const byte *)filekey withcryptokey:(SymmCipher *)key
{
    NodeWrapper* n;
    error e;
	
	cout << "TD " << td << ": Upload complete" << endl;
    
    n = [client nodebyhandle:uploadtarget_wrapper];
	if (n == nil)
	{
		cout << "Upload target folder inaccessible, using /" << endl;
		uploadtarget_wrapper = client->rootnodes[0];
	}
    
	NewNodeWrapper* newnode;
    
	newnode->source = NEW_UPLOAD;
    newnode->uploadhandle = ulhandle;
	memcpy(newnode->uploadtoken,ultoken,sizeof newnode->uploadtoken);
	memcpy(newnode->nodekey,filekey,sizeof newnode->nodekey);
	newnode->mtime = newnode->ctime = time(NULL);
	newnode->parent = 0;
	newnode->type = FILENODE;
    
	NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    [attrs setValue:[uploadfilename_wrapper stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"n"];
	
    NSError* err;
    NSData* attr_data = [NSJSONSerialization dataWithJSONObject:attrs options:0 error:&err];
    
    [client makeattr:key withoutput:newnode->attrdata andinput:attr_data];
    NSMutableArray* newnodes = [NSMutableArray arrayWithObject:newnode];
    e = [client putnodes:uploadtarget_wrapper withtargettype:NODE_HANDLE withnewnode:newnodes];
    
    if (e != API_OK) cout << "Could not store uploaded file (" << errorstring(e) << ")" << endl;
    
	[uploadfilename_wrapper setString:@""];
	[client tclose:td];
}

-(void) changepw_result:(MegaClientWrapper *)client witherror:(error)err
{
    if (err == API_OK) cout << "Password updated." << endl;
	else cout << "Password update failed: " << errorstring(err) << endl;
}

-(void) exportnode_result:(MegaClientWrapper*)client witherror:(error)err
{
    cout << "Export failed: " << errorstring(err) << endl;
}

-(void) exportnode_result:(MegaClientWrapper*)client withhandle:(handle)h withph:(handle)ph
{
    NodeWrapper* n;
    
	if ((n = [client nodebyhandle:h]))
	{
		NSMutableString* path;
		char node[9];
		char key[FILENODEKEYLENGTH*4/3+3];
        
		nodepath(client, h, path);
        
		cout << "Exported " << path << ": ";
        
        [Base64Wrapper btoa:(byte*)&ph oflength:8 tobuf:node];
        
		// the key
		if (n->type == FILENODE) [Base64Wrapper btoa:n->nodekey oflength:FILENODEKEYLENGTH tobuf:key];
		else if (n->sharekey) [Base64Wrapper btoa:n->sharekey->key oflength:FOLDERNODEKEYLENGTH tobuf:key];
		else
		{
			cout << "No key available for exported folder" << endl;
			return;
		}
        
		cout << "https://mega.co.nz/#" << (n->type ? "F" : "") << "!" << node << "!" << key << endl;
	}
	else cout << "Exported node no longer available" << endl;
}

-(void) openfilelink_result:(MegaClientWrapper*)client witherror:(error)err
{
    cout << "Failed to open link: " << errorstring(err) << endl;
}

-(void) openfilelink_result:(MegaClientWrapper*)client withnode:(NodeWrapper*)n
{
    cout << "Importing " << [n displayname] << "..." << endl;
    
	if (ISUNDEF(cwd) || ![client loggedin]) cout << "Need to be logged in to import file links." << endl;
	else
	{
		NewNodeWrapper* newnode = [[NewNodeWrapper alloc] init];
		string attrstring;
        
		// copy core properties
        [newnode copyfromother:(NodeCoreWrapper*)n];
        
		// generate encrypted attribute string      
        NSError* err;
        NSData* attr_data = [NSJSONSerialization dataWithJSONObject:n->attrs options:0 error:&err];
        
        [client makeattr:&n->key withoutput:newnode->attrdata andinput:attr_data];
        
		newnode->source = NEW_PUBLIC;
        
		// add node
        NSMutableArray* newnodes = [NSMutableArray arrayWithObject:newnode];
        [client putnodes:cwd withtargettype:NODE_HANDLE withnewnode:newnodes];
	}
}

-(void) reload:(MegaClientWrapper *)client withreason:(NSString *)reason
{
    cout << "Reload suggested (" << [reason UTF8String] << ")" << endl;
}

-(void) notify_retry:(MegaClientWrapper *)client intime:(int)ds
{
    cout << "API request failed, retrying in " << ds*100 << " ms..." << endl;
}

-(void) debug_log:(MegaClientWrapper *)client withmsg:(NSString *)message
{
    if (debug) cout << "DEBUG: " << [message UTF8String] << endl;
}

@end

