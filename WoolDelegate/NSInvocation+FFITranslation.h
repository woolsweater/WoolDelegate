//
//  NSInvocation+FFITranslation.h
//  WoolDelegate
//
//  Created by Joshua Caswell on 12/23/11.
//  Copyright 2011 Wool Sweater Soft. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <ffi/ffi.h>

@interface NSInvocation (FFITranslation)

/* Get memory via NSMutableData and associate it with this invocation. */
- (void *) Wool_allocate: (size_t)size;
/* Construct a list of ffi_type * describing the method signature of this invocation. */
- (ffi_type **) Wool_buildFFIArgTypeList;
/* Put the values of the invocation's arguments into the format required 
 * by libffi: a list of pointers to pieces of memory holding the values. 
 */
- (void **) Wool_buildArgValList;
/* With the help of the above methods, use the passed IMP to obtain a result 
 * for this invocation. 
 */
- (void) Wool_invokeUsingIMP: (IMP)theIMP;

@end

/* Translate an ObjC type encoding string into the appropriate ffi_type *. */
ffi_type * libffi_type_for_objc_encoding(const char * str);

/* ffi_types for common Cocoa structs */
#if CGFLOAT_IS_DOUBLE
    #define CGFloatFFI &ffi_type_double
#else
    #define CGFloatFFI &ffi_type_float
#endif

extern ffi_type CGPointFFI;
extern ffi_type CGSizeFFI;
extern ffi_type CGRectFFI;