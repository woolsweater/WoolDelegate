//
//  WoolDelegate.m
//
//  Copyright (c) 2011 Joshua Caswell

#import "WoolDelegate.h"

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

- (void)setSignature:(NSMethodSignature *)sig forSelector:(SEL)sel;
- (NSMethodSignature *)signatureForSelector:(SEL)sel;

@end

@implementation WoolDelegate
{
    NSMutableDictionary * _handlers;
}

@synthesize handlers = _handlers;

- (id)init {
    
    self = [super init];
    if( !self ) return nil;
    
    
    _handlers = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc {
    
    [_handlers release];
    [super dealloc];
}

/* Return YES for any selector which would normally result in YES and for any
 * for which there is a handler set.
 */
- (BOOL)respondsToSelector:(SEL)aSelector {
    
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

- (void)setAdoptsProtocol:(Protocol *)p 
{
    class_addProtocol([self class], p);
}

- (GenericBlock)handlerForSelector:(SEL)selector {
    NSDictionary * handlerDict = [self handlerInfoForSelector:selector];
    return [handlerDict objectForKey:WoolDelegateHandlerKey];
}

- (NSDictionary *)handlerInfoForSelector:(SEL)selector {
    return [[self handlers] objectForKey:NSStringFromSelector(selector)];
}

static BOOL method_description_isNULL(struct objc_method_description desc)
{
    return (desc.types == NULL) && (desc.name == NULL);
}

static const char * procure_encoding_string_for_selector_from_protocol(SEL sel,  Protocol * protocol)
{
    // Try all combinations of "is required" and "is an instance method".
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

- (void)addForSelector:(SEL)aSelector fromProtocol:(Protocol *)protocol handler:(GenericBlock)handler
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
            

- (void)addForSelector:(SEL)aSelector handler:(GenericBlock)handler {
    // ffi_type list and signature will be added later
    NSMutableDictionary * d;
    d = [NSMutableDictionary dictionaryWithObject:[[handler copy] autorelease]
                                           forKey:WoolDelegateHandlerKey];
    //TODO: Assert that block sig and selector sig match
    // Note: In fact, they won't match exactly; will have to look into using 
    // NSGetSizeAndAlignment to compare.
    [_handlers setObject:d
                  forKey:NSStringFromSelector(aSelector)];
}

static char delegator_key;
- (void)associateSelfWithDelegator:(id)delegator {
    // Tie delegate's lifetime to that of the object for which it delegates
    objc_setAssociatedObject(delegator, &delegator_key, 
                             self, OBJC_ASSOCIATION_RETAIN);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    
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

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    
    SEL sel = [anInvocation selector];
    GenericBlock handler = [self handlerForSelector:sel];
    
    if( !handler ) {
        return [super forwardInvocation:anInvocation];
    }
    
    // imp_implementationWithBlock() would be a great choice
    // here but it is problematic; it handles the SEL problem differently,
    // passing the Block in the self slot and the reciever of the message in
    // _cmd. Using it will require rewriting Wool_invokeUsingIMP: and others.
    IMP handlerIMP = BlockIMP(handler);
    
    [anInvocation Wool_invokeUsingIMP:handlerIMP];
    
}

- (NSMethodSignature *)signatureForSelector:(SEL)sel
{
    return [[self handlerInfoForSelector:sel] objectForKey:WoolDelegateSignatureKey];
}

- (void)setSignature:(NSMethodSignature *)sig forSelector:(SEL)sel
{
    NSMutableDictionary * d = [_handlers objectForKey:NSStringFromSelector(sel)];
    [d setObject:sig forKey:WoolDelegateSignatureKey];
}

@end
