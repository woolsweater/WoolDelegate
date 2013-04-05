//
//  NSInvocation+FFITranslation.h
//
//  Copyright (c) 2011 Joshua Caswell

#import <Foundation/Foundation.h>

@interface NSInvocation (WoolFFITranslation)

/* 
 * Use the passed IMP to obtain a result for this invocation. Due to internal
 * details of the way arguments are passed along to libffi, this currently only
 * works for IMPs obtained from Blocks.
 */
- (void)Wool_invokeUsingIMP: (IMP)theBlockIMP;

@end
