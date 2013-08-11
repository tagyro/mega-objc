#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <memory.h>
//#include <endian.h>


#ifndef htobe64
#define htobe64(x) (((uint64_t) htonl((uint32_t) ((x) >> 32))) | (((uint64_t) htonl((uint32_t) x)) << 32))
#endif

#include <iostream>
//#include <algorithm>
#include <string>
//#include <sstream>
//#include <map>
//#include <set>
//#include <iterator>
//#include <queue>

using namespace std;
