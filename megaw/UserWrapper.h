//
//  UserWrapper.h
//  testioslib
//

#import <Foundation/Foundation.h>
#include "megacpp/megacrypto.h"

// Contact visibility:
// HIDDEN - not shown
// VISIBLE - shown
typedef enum { VISIBILITY_UNKNOWN = -1, HIDDEN = 0, VISIBLE, ME } visibility;

// User/contact
@interface UserWrapper : NSObject
{
    
@public
    // display name of user
    //NSString* name;
    
	// e-mail address
	NSMutableString* email;
    
    // string identifier for API requests (either e-mail address or ASCII user handle)
	NSString* uid;
    
	// visibility status
	visibility show;
    
	// shares by this user
	NSMutableSet* sharing;
    
    // user's public key
    AsymmCipher pubk;
    int pubkrequested;
    
    // actions to take after arrival of the public key
    NSMutableArray* pkrs;
    
	// contact establishment timestamp
	time_t ctime;
    
}

-(void) set:(visibility)v andtime:(time_t)ct;

-(id) initWithemail:(NSString *)cemail;

@end
