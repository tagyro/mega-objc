//
//  RequestWrapper.m
//  testioslib
//

#import "RequestWrapper.h"
#import "CommandWrapper.h"
#import "HttpIOWrapper.h"

@implementation RequestWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    cmds = [NSMutableArray array];
    
    return self;
}

-(void) add:(id)cmd
{
    [cmds addObject:cmd];
}

-(int) cmdspending
{
    return [cmds count];
}

-(int) get:(byref NSData*)req
{
    NSMutableArray* json_array = [NSMutableArray array];
    
    NSEnumerator *enumerator = [cmds objectEnumerator];
    id cmd_obj;
    
    while (cmd_obj = [enumerator nextObject]) {
        if ([cmd_obj isKindOfClass:[CommandWrapper class]])
        {
            CommandWrapper* cmd = (CommandWrapper*)cmd_obj;
            [json_array addObject:[cmd getdict]];
        }
    }
    
    NSError* err;
    req = [NSJSONSerialization dataWithJSONObject:json_array options:0 error:&err];
    
    return 1;
}

-(void) procresult:(MegaClientWrapper*)client
{
    NSError* err;
    id json_obj = [NSJSONSerialization JSONObjectWithData:client->json options:NSJSONReadingMutableLeaves error:&err];
    
    if (![json_obj isKindOfClass:[NSArray class]])
    {
        return;
    }
    NSArray* result_array = (NSArray*)json_obj;
    int num_cmd = [cmds count];
    for (int i = 0; i < num_cmd; i++)
    {
        id cmd_obj = [cmds objectAtIndex:i];
        id result_obj = [result_array objectAtIndex:i];
        if ([cmd_obj conformsToProtocol:@protocol(CommandResult)])
        {
            [cmd_obj procresult:client withdata:result_obj];
        }
    }
    
    [cmds removeAllObjects];
}

@end

@implementation HttpRequestWrapper

-(id) init
{
    if (!(self = [super init]))
        return nil;
    
    status = REQ_READY;
    ft_idx = 0;
    
    posturl = [NSMutableString stringWithString:@""];
    in = [NSData data];
    out = [NSData data];
    
	buf = NULL;
	
	httpiohandle = nil;
    
    return self;
}

// set url and data range
-(void) setreq:(NSString*)u withtype:(contenttype)t
{
    posturl = [NSMutableString stringWithString:u];
	type = t;
}

-(void) post:(MegaClientWrapper*)client isbulk:(int)bulk withdata:(const char*)data andlen:(unsigned)len;
{
    [client->httpio_wrapper post:self isbulk:bulk withdata:data andlen:len];
}

-(void) put:(const void*)data withlen:(int)len
{
    if (buf)
	{
		if (bufpos+len > buflen) len = buflen-bufpos;
		
		memcpy(buf+bufpos,data,len);
		bufpos += len;
	}
    else [in appendBytes:data length:len];
}

-(off_t) transferred:(MegaClientWrapper*)client
{
    if (buf) return bufpos;
    else return [in length];
}

@end
