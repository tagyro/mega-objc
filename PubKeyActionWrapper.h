//
//  PubKeyActionWrapper.h
//  megaiosapp
//

#import <Foundation/Foundation.h>
#import "MegaClientWrapper.h"
#import "UserWrapper.h"
#import "ShareWrapper.h"
#import "NodeWrapper.h"

@interface PubKeyActionWrapper : NSObject

-(id)init;

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u;

@end

@interface PubKeyActionCreateShareWrapper : PubKeyActionWrapper
{
    handle h;   // node to create share on
    accesslevel a; // desired access level
}

-(id)initWithHandle:(handle)sh andaccesslevel:(accesslevel)sa;

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u;

@end

@interface PubKeyActionSendShareKeyWrapper : PubKeyActionWrapper
{
    handle sh; // share node the key was requested on
}

-(id)initWithHandle:(handle)h;

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u;

@end

@interface PubKeyActionAddNodesWrapper : PubKeyActionWrapper
{
    NewNodeWrapper* nn; // nodes to add
    int nc; // number of nodes to add
}

-(id)initWithNewNode:(NewNodeWrapper*)n andidx:(int)idx;

-(void)proc:(MegaClientWrapper *)client anduser:(UserWrapper *)u;

@end