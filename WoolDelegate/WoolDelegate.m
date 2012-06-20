//
//  WoolDelegate.m
//  WoolDelegate
//
//  Created by Joshua Caswell on 12/6/11.
//  Copyright 2011 Wool Sweater Soft. All rights reserved.
//

#import "WoolDelegate.h"

#include <ffi/ffi.h>
#import <objc/runtime.h>

#import "WoolBlockHelper.h"
#import "NSInvocation+FFITranslation.h"
#import "WoolEncoding.h"

/* Keys for the handler info dictionary: */
/* The handler Block itself */
NSString * const WoolDelegateHandlerKey = @"HandlerKey";
/* The NSMethodSignature object for the handler */
NSString * const WoolDelegateSignatureKey = @"SignatureKey";
/* The ffi_type list corresponding to the handler's signature */
NSString * const WoolDelegateFFITypeListKey = @"FFITypeListKey";

@interface WoolDelegate ()
{
    NSMutableDictionary * handlers_;
    NSMutableArray * allocations_;
}

- (void *) allocate: (size_t)size;
//- (ffi_type **) buildArgTypeListForSignature: (NSMethodSignature *)sig;
- (void **) buildArgListForInvocation: (NSInvocation *)invoc;
//- (ffi_type *) libffi_type_for_objc_encoding: (const char *) str;

- (void)setSignature: (NSMethodSignature *)sig forSelector: (SEL)sel;
- (NSMethodSignature *)signatureForSelector: (SEL)sel;

@end

@implementation WoolDelegate

@synthesize handlers = handlers_;


- (id) init {
    
    self = [super init];
    if( !self ) return nil;
    
    handlers_ = [[NSMutableDictionary alloc] init];
    allocations_ = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc {
    
    [handlers_ release];
    [allocations_ release];
    [super dealloc];
}

- (BOOL)respondsToSelector: (SEL)aSelector {
    
    BOOL responds = [super respondsToSelector:aSelector];
    if( !responds ){
        
        GenericBlock handler = [self handlerForSelector:aSelector];
        responds = (handler != nil);
    }
    
    return responds;
}

- (NSArray *)adoptedProtocols 
{
    
    unsigned int count;
    Protocol ** protocols = class_copyProtocolList([self class], &count);
    NSArray * arr = [NSArray arrayWithObjects:protocols count:count];
    free(protocols);
    return arr;
}

- (void)setConformsToProtocol: (Protocol *)p 
{
    class_addProtocol([self class], p);
}


- (GenericBlock) handlerForSelector: (SEL)selector {
    NSDictionary * handlerDict = [self handlerInfoForSelector:selector];
    return [handlerDict objectForKey:WoolDelegateHandlerKey];
}

- (NSDictionary *) handlerInfoForSelector: (SEL)selector {
    return [[self handlers] objectForKey:NSStringFromSelector(selector)];
}

static BOOL method_description_isNULL(struct objc_method_description desc)
{
    return (desc.types == NULL) && (desc.name == NULL);
}

static char * procure_encoding_string_for_selector_from_protocol(SEL sel, Protocol * protocol)
{
    static BOOL isReqVals[4] = {NO, NO, YES, YES};
    static BOOL isInstanceVals[4] = {NO, YES, NO, YES};
    struct objc_method_description desc = {NULL, NULL};
    for( int i = 0; i < 4; i++ ){
        desc = protocol_getMethodDescription(protocol,
                                             sel,
                                             isReqVals[i], 
                                             isInstanceVals[i]);
        if( !method_description_isNULL(desc) ){
            break;
        }
    }
    
    return desc.types;
}

- (void)addForSelector: (SEL)aSelector fromProtocol: (Protocol *)protocol handler: (GenericBlock)handler
{
    [self addForSelector:aSelector handler:handler];
    if( protocol ){
        class_addProtocol([self class], protocol);
        
        char * types;
        types = procure_encoding_string_for_selector_from_protocol(aSelector,
                                                                   protocol);
        
        if( types ){
            NSMethodSignature * sig = [NSMethodSignature signatureWithObjCTypes:types];
            [self setSignature:sig forSelector:aSelector];
        }
    }    
}
            

- (void) addForSelector: (SEL)aSelector handler: (GenericBlock)handler {
    // ffi_type list and signature will be added later
    NSMutableDictionary * d;
    d = [NSMutableDictionary dictionaryWithObject:[[handler copy] autorelease]
                                           forKey:WoolDelegateHandlerKey];
    //TODO: Assert that block sig and selector sig match
    // Note: In fact, they won't match exactly; will have to look into using 
    // NSGetSizeAndAlignment to compare.
    [handlers_ setObject:d
                  forKey:NSStringFromSelector(aSelector)];
}

static char delegator_key;
- (void) associateSelfWithDelegator: (id)delegator {
    // Tie delegate's lifetime to that of the object for which it delegates
    objc_setAssociatedObject(delegator, &delegator_key, 
                             self, OBJC_ASSOCIATION_RETAIN);
}
    

// Thanks to Mike Ash for the last section of this implementation 
// https://github.com/mikeash/MABlockForwarding
- (NSMethodSignature *)methodSignatureForSelector: (SEL)aSelector {
    
    GenericBlock handler = [self handlerForSelector:aSelector];
    
    // If no handler is set, just pass along the search for a signature
    if( !handler ){
        return [super methodSignatureForSelector:aSelector];
    }
    
    // Try to get an already-constructed signature
    NSMethodSignature * sig = [self signatureForSelector:aSelector];
    if( sig ){
        return sig;
    }
    
    // Try to get a type string from adopted protocols
    const char * types = NULL;
    for( Protocol * p in [self adoptedProtocols] ){
        types = procure_encoding_string_for_selector_from_protocol(aSelector,
                                                                   p);
    }
    if( types ){
        sig = [NSMethodSignature signatureWithObjCTypes:types];
        [self setSignature:sig forSelector:aSelector];
        return sig;
    }
        
    
    //TODO: Can I ask a protocol for the method signature? This would require
    // clients to pass in a protocol to associate with a handler/SEL pair,
    // but would reduce reliance on the Block ABI.
    // This, however, may be _less_ reliable. The Block private specification
    // at least states that the signature string is based on the ObjC encoding;
    // no statment of any kind is made about objc_method_description.types
//    Protocol * p = [self conformedProtocol];
//    if( p ){
//        struct objc_method_description desc;
//        desc = protocol_getMethodDescription(p, aSelector, NO, YES);
//        return [NSMethodSignature signatureWithObjCTypes: desc.types];
//    }
    // Add a setHandler:forSelector:fromProtocol: method. This will associate the
    // handler with the protocol and use the type string that can be found there.
    // If no protocol is passed, or the simpler setHandler:forSelector:, look
    // through any already-added protocols to see if the selector is present.
    // If so, use that type string. Fall back on string mangling.
    
    // Otherwise, construct a signature based on the block's sig
    types = BlockSig(handler);
    types = encoding_createWithInsertedSEL(types);
    // The types signature for the Block isn't valid for use as a ObjC method
    // signature. For example, the Block 
    // ^id (NSArray * leek){ return [leek objectAtIndex:0]; }
    //  has a type string "@16@?0@8", which looks like:
    // Return type object, the Block, first parameter object. Note no SEL!
    // This is causing problems later when pulling the args out of the invocation.
    // The SEL needs to be _inserted_ into the type string after the block
    // instance. NSGetSizeAndAlignment will help here, and Mike Ash has a 
    // wrapper for that which might make it even easier.
    // Is it possible to require the Blocks to have a signature (like
    // objc_msgSend() does? I.e., typedef id (^HandlerBlock)(SEL sel, ...);
    // I think bbum has something about this in his post on imp_implementationWithBlock()
    sig = [NSMethodSignature signatureWithObjCTypes: types];
    [self setSignature:sig forSelector:aSelector];
    free(types);
    return sig;
}

typedef void (*genericfunc)(void);
- (void)forwardInvocation: (NSInvocation *)anInvocation {
    
    SEL sel = [anInvocation selector];
    GenericBlock handler = [self handlerForSelector:sel];
    
    if( !handler ) {
        return [super forwardInvocation:anInvocation];
    }
    
    //TODO: Conditional compilation to use imp_implementationWithBlock()
    // where available (Lion and iOS >= 4.0)
    IMP handlerIMP = BlockIMP(handler);
    
    [anInvocation Wool_invokeUsingIMP:handlerIMP];
    
//    // Get sig from invocation
//    NSMethodSignature * sig = [anInvocation methodSignature];
//    // Get info about args from sig:
//    // * number
//    // * types (translate to ffi_types)
//    // * (also return type -> ffi_type)
//    NSUInteger num_args = [sig numberOfArguments];
//    //TODO: Cache this shit for each handler.
//    ffi_type ** arg_types = [self buildArgTypeListForSignature:sig];
//    ffi_type * ret_type = [self libffi_type_for_objc_encoding:[sig methodReturnType]];
//    ffi_cif inv_cif;
//    if( FFI_OK == ffi_prep_cif(&inv_cif, FFI_DEFAULT_ABI, 
//                               (unsigned int)num_args, ret_type, arg_types) )
//    {
//        void ** arg_vals = [self buildArgListForInvocation:anInvocation];
//        void * ret_val = calloc(1, [sig methodReturnLength]);
//        ffi_call(&inv_cif, (genericfunc)handlerIMP, ret_val, arg_vals);
//        [anInvocation setReturnValue:ret_val];
//        free(ret_val);
//    }
    
}  

// Thanks to Mike Ash for this idea as well.
- (void *)allocate: (size_t)size {
    
    NSMutableData * dat = [NSMutableData dataWithLength:size];
    [allocations_ addObject:dat];
    return [dat mutableBytes];
}

//- (ffi_type **)buildArgTypeListForSignature: (NSMethodSignature *)sig {
//    
//    NSUInteger l = [sig numberOfArguments];
//    ffi_type ** arg_types = (ffi_type **)[self allocate: sizeof(ffi_type *) * l];
//    NSUInteger i;
//    for( i = 0; i < l; i++ ){
//        arg_types[i] = [self libffi_type_for_objc_encoding:[sig getArgumentTypeAtIndex:i]];
//    }
//    
//    return arg_types;
//}

//- (void **)buildArgListForInvocation: (NSInvocation *)invoc
//{
//    NSMethodSignature * sig = [invoc methodSignature];
//    NSUInteger num_args = [sig numberOfArguments];
//    void ** arg_list = [self allocate: sizeof(void *) * num_args];
//    NSUInteger i;
//    for(i = 0; i < num_args; i++ ){
//        NSUInteger arg_size;
//        NSGetSizeAndAlignment([sig getArgumentTypeAtIndex:i], &arg_size, NULL);
//        arg_list[i] = [self allocate:arg_size];
//        [invoc getArgument:arg_list[i] atIndex:i];
//    }
//    
//    return arg_list;
//}

- (void)setSignature: (NSMethodSignature *)sig forSelector: (SEL)sel
{
    NSMutableDictionary * d = [handlers_ objectForKey:NSStringFromSelector(sel)];
    [d setObject:sig forKey:WoolDelegateSignatureKey];
}

@end


