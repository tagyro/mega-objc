//
//  Base64Wrapper.m
//  testioslib
//

#import "Base64Wrapper.h"

@implementation Base64Wrapper

+(byte) to64:(byte)c
{
    c &= 63;
	if (c < 26) return c+'A';
	if (c < 52) return c-26+'a';
	if (c < 62) return c-52+'0';
	if (c == 62) return '-';
	return '_';
}

+(byte) from64:(byte)c
{
    if (c >= 'A' && c <= 'Z') return c-'A';
	if (c >= 'a' && c <= 'z') return c-'a'+26;
	if (c >= '0' && c <= '9') return c-'0'+52;
	if (c == '-') return 62;
	if (c == '_') return 63;
	return 255;
}

+(char*) btoa:(const byte*)b oflength:(int)blen tobuf:(char*)a
{
    for (;;)
	{
		if (blen <= 0) break;
		*a++ = [Base64Wrapper to64:(*b >> 2)];
		*a++ = [Base64Wrapper to64:((*b << 4) | (((blen > 1) ? b[1] : 0) >> 4))];
		if (blen < 2) break;
		*a++ = [Base64Wrapper to64:(b[1] << 2 | (((blen > 2) ? b[2] : 0) >> 6))];
		if (blen < 3) break;
		*a++ = [Base64Wrapper to64:(b[2])];
        
		blen -= 3;
		b += 3;
	}
	
	*a = 0;
	
	return a;
}

+(byte*) atob:(const char*)a tobytes:(byte*)b withlen:(int)blen
{
    byte c[4];
	int i;
	int done = 0;
    
	c[3] = 0;
    
	do {
		for (i = 0; i < 4; i++) if ((c[i] = [Base64Wrapper from64:(*a++)]) == 255) break;
        
		if (!blen-- || !i) return b;
		*b++ = (c[0] << 2) | ((c[1] & 0x30) >> 4);
		if (!blen-- || i < 3) return b;
		*b++ = (c[1] << 4) | ((c[2] & 0x3c) >> 2);
		if (!blen-- || i < 4) return b;
		*b++ = (c[2] << 6) | c[3];
	} while (!done);
	
	return b;
}

@end

@implementation ChunkedHashWrapper

+(off_t) chunkfloor:(off_t)p
{
    off_t cp, np;
	
	cp = 0;
	
	for (unsigned int i = 1; i <= 8; i++)
	{
		np = cp+i*SEGSIZE;
		if (p >= cp && p < np) return cp;
		cp = np;
	}
	
	return ((p-cp)&-(8*SEGSIZE))+cp;
}

+(off_t) chunkceil:(off_t)p
{
    off_t cp, np;
	
	cp = 0;
	
	for (unsigned int i = 1; i <= 8; i++)
	{
		np = cp+i*SEGSIZE;
		if (p >= cp && p < np) return np;
		cp = np;
	}
	
	return ((p-cp)&-(8*SEGSIZE))+cp+8*SEGSIZE;
}

@end