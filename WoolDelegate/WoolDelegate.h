//
//  WoolDelegate.h
//
//  Copyright (c) 2012 Joshua Caswell

#import <Foundation/Foundation.h>

typedef void (^GenericBlock)(void);

@interface WoolDelegate : NSObject

/* 
 * A dictionary of dictionaries, with information about handlers, 
 * keyed by selector converted to NSString.
 */
@property (readonly, nonatomic) NSDictionary * handlers;

/* 
 * A list of protocols which clients have indicated this delegate adopts.
 * This can be added to explicitly with setAdoptsProtocol:, or implicitly
 * by using addForSelector:fromProtocol:handler: The list of protocols
 * will be used to find method signatures for handlers if possible.
 */
@property (readonly, nonatomic) NSArray * adoptedProtocols;

/* 
 * Add a protocol to the list of those which this delegate instance
 * adopts. The list is used to find method signatures for handlers.
 */
- (void)setAdoptsProtocol: (Protocol *)p;
/* Note that this has no effect at compile-time and won't remove warnings. */

/* 
 * Returns the set handler for the selector; if no handler is set, returns nil.
 */
- (GenericBlock)handlerForSelector: (SEL)selector;

/* 
 * Returns the dictionary of info for the selector; only the handler itself
 * is guaranteed to be set before the instance has been sent the selector.
 * Valid keys are listed below.
 */
//TODO: Remove this restriction, i.e., set other info immediately?
- (NSDictionary *)handlerInfoForSelector: (SEL)selector;

/* 
 * Sets the passed Block as this instance's response to the selector.
 * This copies the block and creates the handler info dictionary, but does
 * not necessarily create the method signature.
 */
- (void)addForSelector: (SEL)aSelector  handler: (GenericBlock)handler;
- (void)addForSelector: (SEL)aSelector fromProtocol: (Protocol *)protocol handler: (GenericBlock)handler;

/* 
 * Ties this instance to the supplied object using objc_setAssociatedObject
 * OBJC_ASSOCIATION_RETAIN. The lifetime of the delegate is therefore the same
 * as its delegator, and no reference needs to be kept in the creating scope.
 */
- (void)associateSelfWithDelegator: (id)delegator;

@end

/* Keys for retrieving info from the individual handler info dictionaries. */
/* The handler Block itself */
extern NSString * const WoolDelegateHandlerKey;
/* NSMethodSignature object for the handler */
extern NSString * const WoolDelegateSignatureKey;
