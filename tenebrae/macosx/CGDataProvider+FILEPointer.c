//
//  CGDataProvider+FILEPointer.c
//  TenebraeQuake
//
//  Created by C.W. Betts on 7/31/16.
//
//

#include "CGDataProvider+FILEPointer.h"


static size_t FILEGetBytesCallback(void * __nullable info, void *  buffer, size_t count)
{
	if (info == NULL) {
		return 0;
	}
	FILE *fInfo = info;
	return fread(buffer, count, 1, fInfo);
}

static off_t FILESkipForwardCallback(void * __nullable info, off_t count)
{
	if (info == NULL) {
		return 0;
	}
	FILE *fInfo = info;
	return fseeko(fInfo, count, SEEK_CUR);
}

static void FILERewindCallback(void *info)
{
	if (info == NULL) {
		return;
	}
	FILE *fInfo = info;
	rewind(fInfo);
}

const CGDataProviderSequentialCallbacks FILECallback = {
	0,
	FILEGetBytesCallback,
	FILESkipForwardCallback,
	FILERewindCallback,
	NULL
};

CGColorSpaceRef getGenericRGBColorSpace()
{
	static CGColorSpaceRef ourStore;
	if (!ourStore) {
		ourStore = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
	}
	return ourStore;
}

CGColorSpaceRef getGenericGrayColorSpace()
{
	static CGColorSpaceRef ourStore;
	if (!ourStore) {
		ourStore = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
	}
	return ourStore;
}
