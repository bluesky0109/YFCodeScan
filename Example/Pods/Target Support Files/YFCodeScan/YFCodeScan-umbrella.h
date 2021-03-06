#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "YFScanController.h"
#import "YFScanner.h"
#import "YFScanningAnimationProtocol.h"
#import "YFScanningLineAnimation.h"
#import "YFScanPreviewView.h"
#import "YFScanPreviewViewConfiguration.h"

FOUNDATION_EXPORT double YFCodeScanVersionNumber;
FOUNDATION_EXPORT const unsigned char YFCodeScanVersionString[];

