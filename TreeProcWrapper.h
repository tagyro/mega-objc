//
//  TreeProcWrapper.h
//  megaiosapp
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"

@class NodeWrapper;
@class NodeCoreWrapper;
@class NewNodeWrapper;
@class CommandWrapper;

@interface ShareNodeKeysWrapper : NSObject
{
    NSMutableArray* shares;
    NSMutableArray* items;
    NSMutableArray* keys;
}

-(id) init;

-(int) addshare:(NodeWrapper*)sn;

-(void) add:(MegaClientWrapper*)client withn:(NodeWrapper*)n withsn:(NodeWrapper*)sn andspecific:(int)specific;

-(void) add:(MegaClientWrapper*)client withn:(NodeCoreWrapper*)n withsn:(NodeWrapper*)sn andspecific:(int)specific anditem:(const byte*)item andlength:(int)itemlen;

-(void) get:(CommandWrapper*)c;

@end

@interface TreeProcWrapper : NSObject

-(id) init;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

@end

@interface TreeProcDelWrapper : TreeProcWrapper

-(id) init;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

@end

@interface TreeProcListOutShresWrapper : TreeProcWrapper

-(id) init;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

@end

@interface TreeProcCopyWrapper : TreeProcWrapper
{
    @public
    NSMutableArray* nn;
    int nc;
}

-(id) init;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

-(void) allocnodes;

@end

@interface TreeProcDUWrapper : TreeProcWrapper
{
    @public
    off_t numbytes;
    int numfiles;
    int numfolders;
}

-(id) init;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

@end

@interface TreeProcShareKeysWrapper : TreeProcWrapper
{
    ShareNodeKeysWrapper* snk;
    NodeWrapper* sn;
}

-(id) initWithNode:(NodeWrapper*)n;

-(void) proc:(MegaClientWrapper*)client andnode:(NodeWrapper*)n;

-(void) get:(CommandWrapper*)c;

@end