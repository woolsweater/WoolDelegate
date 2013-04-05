//
//  NSInvocation+FFITranslation.m
//
//  Copyright (c) 2011 Joshua Caswell

#import "NSInvocation+FFITranslation.h"
#include <ffi/ffi.h>
#include <objc/objc-runtime.h>

@interface NSInvocation (FFITranslationPrivate)

/* Get memory via NSMutableData and associate it with this invocation. */
- (void *)Wool_allocate: (size_t)size;

/* Construct a list of ffi_type * describing the method signature of this invocation. */
- (ffi_type **)Wool_buildFFIArgTypeList;

/*
 * Put the values of the invocation's arguments into the format required
 * by libffi: a list of pointers to pieces of memory holding the values.
 */
- (void **)Wool_buildArgValList;

@end

ffi_type * libffi_type_for_objc_encoding(const char * str);

@implementation NSInvocation (FFITranslationPrivate)

/* 
 * Use associated objects facility to manage memory needed for ffi argument
 * type and value lists. The memory is acquired via NSMutableData, which are
 * put into an NSMutableArray associated with this NSInvocation instance.
 * All memory allocations for the libffi translation process are thus tied
 * to the invocation's normal lifespan.
 */
static char allocations_key;
- (void *)Wool_allocate: (size_t)size {
    NSMutableArray * allocations = objc_getAssociatedObject(self, 
                                                            &allocations_key);
    if( !allocations ){
        allocations = [NSMutableArray array];
        objc_setAssociatedObject(self, &allocations_key, 
                                 allocations, OBJC_ASSOCIATION_RETAIN);
    }
    
    NSMutableData * dat = [NSMutableData dataWithLength:size];
    [allocations addObject:dat];
    
    return [dat mutableBytes];
}
    
/* 
 * Construct a list of ffi_type * describing the method signature of this
 * invocation. Steps through each argument in turn and interprets the ObjC
 * type encoding.
 */
- (ffi_type **)Wool_buildFFIArgTypeList {

    NSMethodSignature * sig = [self methodSignature];
    NSUInteger num_used_args = [sig numberOfArguments] - 1;    // Ignore SEL
    ffi_type ** arg_types = [self Wool_allocate: sizeof(ffi_type *) * num_used_args];
    for( NSUInteger i = 0; i < num_used_args; i++ ){
        // Skip over the SEL; the Block doesn't have a slot for it, so we
        // don't want to pass it in later.
        //!!!: Blocks don't have a slot, but a generic IMP _will_. This
        // requires some re-working for use apart from Blocks.
        NSUInteger actual_arg_idx = i;
        if( i >= 1 ){
            actual_arg_idx += 1;
        }
        arg_types[i] = libffi_type_for_objc_encoding([sig getArgumentTypeAtIndex:actual_arg_idx]);
    }
    
    return arg_types;
}
    
/* 
 * Put the values of the arguments to this invocation into the format required
 * by libffi: a list of pointers to pieces of memory containing the values.
 */
- (void **)Wool_buildArgValList
{
    
    NSMethodSignature * sig = [self methodSignature];
    NSUInteger num_used_args = [sig numberOfArguments] - 1;    // Ignore SEL
    /* Allocate list of pointers big enough for the number of args. */
    void ** arg_list = (void **)[self Wool_allocate:sizeof(void *) * num_used_args];
    NSUInteger i;
    for(i = 0; i < num_used_args; i++ ){
        // Skip over the SEL; the Block doesn't have a slot for it.
        NSUInteger actual_arg_idx = i;
        if( i >= 1 ){
            actual_arg_idx++;
        }
        /* Find size of this arg. */
        NSUInteger arg_size;
        NSGetSizeAndAlignment([sig getArgumentTypeAtIndex:actual_arg_idx], 
                              &arg_size, 
                              NULL);
        /* Get a piece of memory that size and put its address in the list. */
        arg_list[i] = [self Wool_allocate:arg_size];
        /* Put the value into the allocated spot. */
        [self getArgument:arg_list[i] atIndex:actual_arg_idx];
    }
    return arg_list;
}

@end

//MARK: Public category

@implementation NSInvocation (FFITranslation)

// Typedef for casting IMP in ffi_call to shut up compiler
typedef void (*genericfunc)(void);

- (void)Wool_invokeUsingIMP: (IMP)theIMP {
    
    NSMethodSignature * sig = [self methodSignature];
    NSUInteger num_used_args = [sig numberOfArguments] - 1;    // Ignore SEL
    ffi_type ** arg_types = [self Wool_buildFFIArgTypeList];
    ffi_type * ret_type = libffi_type_for_objc_encoding([sig methodReturnType]);
    ffi_cif inv_cif;
    ffi_status prep_status = ffi_prep_cif(&inv_cif, FFI_DEFAULT_ABI,
                                          (unsigned int)num_used_args, 
                                          ret_type, arg_types);
    NSAssert(prep_status == FFI_OK, @"ffi_prep_cif failed in %@ for invocation of %@",
                                    NSStringFromSelector(_cmd),
                                    NSStringFromSelector([self selector]));
    
    
    void ** arg_vals = [self Wool_buildArgValList];
    NSUInteger ret_size = [sig methodReturnLength];
    void * ret_val = NULL;
    if( ret_size > 0 ){
        ret_val = calloc(1, ret_size);
        NSAssert(ret_val != NULL, @"%@ failed to allocate space for return value for invocation of %@",
                                  NSStringFromSelector(_cmd),
                                  NSStringFromSelector([self selector]));
    }
    
    ffi_call(&inv_cif, (genericfunc)theIMP, ret_val, arg_vals);
    if( ret_val ){
        [self setReturnValue:ret_val];
        free(ret_val);
    }

}

@end


/* ffi_type structures for common Cocoa structs */

/* N.B.: ffi_type constructions must be created and added as possible return
 * values from libffi_type_for_objc_encoding below for any custom structs that 
 * will be encountered by the invocation. If libffi_type_for_objc_encoding
 * fails to find a match, it will abort.
 */
#if CGFLOAT_IS_DOUBLE
#define CGFloatFFI &ffi_type_double
#else
#define CGFloatFFI &ffi_type_float
#endif

static ffi_type CGPointFFI = (ffi_type){ .size = 0, 
                                  .alignment = 0, 
                                  .type = FFI_TYPE_STRUCT,
                                  .elements = (ffi_type * [3]){CGFloatFFI, 
                                                               CGFloatFFI,
                                                               NULL}};


static ffi_type CGSizeFFI = (ffi_type){ .size = 0, 
                                 .alignment = 0, 
                                 .type = FFI_TYPE_STRUCT,
                                 .elements = (ffi_type * [3]){CGFloatFFI, 
                                                              CGFloatFFI,
                                                              NULL}};

static ffi_type CGRectFFI = (ffi_type){ .size = 0, 
                                 .alignment = 0, 
                                 .type = FFI_TYPE_STRUCT,
                                 .elements = (ffi_type * [3]){&CGPointFFI,
                                                              &CGSizeFFI, NULL}};
    
/* Translate an ObjC encoding string into a pointer to the appropriate
 * libffi type; this covers the CoreGraphics structs defined above, 
 * and, on OS X, the AppKit equivalents.
 */
ffi_type * libffi_type_for_objc_encoding(const char * str)
{
    /* Slightly modfied version of Mike Ash's code from
     * https://github.com/mikeash/MABlockClosure/blob/master/MABlockClosure.m
     * Copyright (c) 2010, Michael Ash
     * All rights reserved.
     * Distributed under a BSD license. See MA_LICENSE.txt for details.
     */
#define SINT(type) do { \
    if(str[0] == @encode(type)[0]) \
    { \
        if(sizeof(type) == 1) \
            return &ffi_type_sint8; \
        else if(sizeof(type) == 2) \
            return &ffi_type_sint16; \
        else if(sizeof(type) == 4) \
            return &ffi_type_sint32; \
        else if(sizeof(type) == 8) \
            return &ffi_type_sint64; \
        else \
        { \
            NSLog(@"fatal: %s, unknown size for type %s", __func__, #type); \
            abort(); \
        } \
    } \
} while(0)
        
#define UINT(type) do { \
    if(str[0] == @encode(type)[0]) \
    { \
        if(sizeof(type) == 1) \
            return &ffi_type_uint8; \
        else if(sizeof(type) == 2) \
            return &ffi_type_uint16; \
        else if(sizeof(type) == 4) \
            return &ffi_type_uint32; \
        else if(sizeof(type) == 8) \
            return &ffi_type_uint64; \
        else \
        { \
            NSLog(@"fatal: %s, unknown size for type %s", __func__, #type); \
            abort(); \
        } \
    } \
} while(0)
        
#define INT(type) do { \
    SINT(type); \
    UINT(unsigned type); \
} while(0)
        
#define COND(type, name) do { \
    if(str[0] == @encode(type)[0]) \
        return &ffi_type_ ## name; \
} while(0)
        
#define PTR(type) COND(type, pointer)
        
#define STRUCT(structType, retType) do { \
    if(strncmp(str, @encode(structType), strlen(@encode(structType))) == 0) \
    { \
        return retType; \
    } \
} while(0)
        
    SINT(_Bool);
    SINT(signed char);
    UINT(unsigned char);
    INT(short);
    INT(int);
    INT(long);
    INT(long long);
    
    PTR(id);
    PTR(Class);
//    PTR(Protocol);
    PTR(SEL);
    PTR(void *);
    PTR(char *);
    PTR(void (*)(void));
    
    COND(float, float);
    COND(double, double);
    
    COND(void, void);
    
    // Mike Ash's code dynamically allocates ffi_types representing the
    // structures rather than statically defining them.
    STRUCT(CGPoint, &CGPointFFI);
    STRUCT(CGSize, &CGSizeFFI);
    STRUCT(CGRect, &CGRectFFI);
    
#if !TARGET_OS_IPHONE
    STRUCT(NSPoint, &CGPointFFI);
    STRUCT(NSSize, &CGSizeFFI);
    STRUCT(NSRect, &CGRectFFI);
#endif
    
    // Add custom structs here using 
    // STRUCT(StructName, &ffi_typeForStruct);
    
    NSLog(@"fatal: %s, unknown encode string %s", __func__, str);
    abort();
}

/* End code from Mike Ash */
