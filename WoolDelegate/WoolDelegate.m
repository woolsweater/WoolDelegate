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
#import "WoolObjCEncoding.h"

/* Keys for the handler info dictionary: */
/* The handler Block itself */
NSString * const WoolDelegateHandlerKey = @"HandlerKey";
/* The NSMethodSignature object for the handler */
NSString * const WoolDelegateSignatureKey = @"SignatureKey";

@interface WoolDelegate ()

- (void *)allocate: (size_t)size;

- (void)setSignature: (NSMethodSignature *)sig forSelector: (SEL)sel;
- (NSMethodSignature *)signatureForSelector: (SEL)sel;

@end

@implementation WoolDelegate
{
    NSMutableDictionary * handlers_;
    NSMutableArray * allocations_;
}

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

/* Return YES for any selector which would normally result in YES and for any
 * for which there is a handler set.
 */
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

- (void)setAdoptsProtocol: (Protocol *)p 
{
    class_addProtocol([self class], p);
}


- (GenericBlock)handlerForSelector: (SEL)selector {
    NSDictionary * handlerDict = [self handlerInfoForSelector:selector];
    return [handlerDict objectForKey:WoolDelegateHandlerKey];
}

- (NSDictionary *)handlerInfoForSelector: (SEL)selector {
    return [[self handlers] objectForKey:NSStringFromSelector(selector)];
}

static BOOL method_description_isNULL(struct objc_method_description desc)
{
    return (desc.types == NULL) && (desc.name == NULL);
}

static const char * procure_encoding_string_for_selector_from_protocol(SEL sel,  Protocol * protocol)
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
        
        const char * types;
        types = procure_encoding_string_for_selector_from_protocol(aSelector,
                                                                   protocol);
        
        if( types ){
            NSMethodSignature * sig = [NSMethodSignature signatureWithObjCTypes:types];
            [self setSignature:sig forSelector:aSelector];
        }
    }    
}
            

- (void)addForSelector: (SEL)aSelector handler: (GenericBlock)handler {
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
    BOOL mustFreeTypesString = NO;
    const char * types = NULL;
    for( Protocol * p in [self adoptedProtocols] ){
        types = procure_encoding_string_for_selector_from_protocol(aSelector,
                                                                   p);
    }
    // Otherwise, construct a signature based on the block's sig
    if( !types ){
        types = BlockSig(handler);
        types = encoding_createWithInsertedSEL(types);
        mustFreeTypesString = YES;
    }
    
    // Construct NSMethodSignature from the type string, and save it
    // for future use. free string if it was created.
    sig = [NSMethodSignature signatureWithObjCTypes:types];
    [self setSignature:sig forSelector:aSelector];
    if( mustFreeTypesString ){ free((void *)types); }
    return sig;
}

typedef void (*genericfunc)(void);
- (void)forwardInvocation: (NSInvocation *)anInvocation {
    
    SEL sel = [anInvocation selector];
    GenericBlock handler = [self handlerForSelector:sel];
    
    if( !handler ) {
        return [super forwardInvocation:anInvocation];
    }
    
    //TODO: Check for imp_implementationWithBlock() and use it
    // where available (Lion and iOS >= 4.0)
    // This is problematic; imp_implementationWithBlock() handles the SEL
    // problem differently. It may actually not be worth the trouble.
    IMP handlerIMP = BlockIMP(handler);
//    if( imp_implementationWithBlock != NULL ){
//        handlerIMP = imp_implementationWithBlock(handler);
//    }
    
    [anInvocation Wool_invokeUsingIMP:handlerIMP];
    
}  

//TODO: Not needed; remove.
// Thanks to Mike Ash for this idea.
- (void *)allocate: (size_t)size {
    
    NSMutableData * dat = [NSMutableData dataWithLength:size];
    [allocations_ addObject:dat];
    return [dat mutableBytes];
}

- (NSMethodSignature *)signatureForSelector: (SEL)sel
{
    return [[self handlerInfoForSelector:sel] objectForKey:WoolDelegateSignatureKey];
}

- (void)setSignature: (NSMethodSignature *)sig forSelector: (SEL)sel
{
    NSMutableDictionary * d = [handlers_ objectForKey:NSStringFromSelector(sel)];
    [d setObject:sig forKey:WoolDelegateSignatureKey];
}

@end


