//
//  main.m
//  WoolDelegate
//
//  Copyright (c) 2011 Joshua Caswell.

#import <Foundation/Foundation.h>
#import "WoolDelegate.h"
#import <objc/runtime.h>
#import "WoolBlockHelper.h"


#define NSStringFromBOOL(b) ((b) ? @"YES" : @"NO")

extern id objc_msgSend(id, SEL, ...);

@protocol Allia <NSObject>

- (id)poireaux: (NSArray *)leek;
- (void)oignon: (NSString *)onion;
- (void)pommes: (NSString *)apple terre:(NSString *)earth;
- (NSNumber *)ail:(BOOL)b avec:(int)i huile:(NSArray *)a;

@end

@interface NSObject (WoolShutUpARC)
- (NSNumber *)frick: (BOOL)b a: (int)i frack: (NSArray *)a;
@end

static void test_respondsToInheritedSelector(WoolDelegate * d) {
    
    NSLog(@"Responds to inherited selector? %@", NSStringFromBOOL([d respondsToSelector:@selector(class)]));
}

static void test_respondsToDefinedSelector(WoolDelegate * d) {
    
    NSLog(@"Responds to selector in class definition? %@", NSStringFromBOOL([d respondsToSelector:@selector(handlerForSelector:)]));
}

static void test_respondsToSetSelector(WoolDelegate * d) {
    
    NSLog(@"Responds to selector set at runtime? %@", NSStringFromBOOL([d respondsToSelector:@selector(estragon)]));
}

int main (int argc, const char * argv[])
{
    @autoreleasepool {
    
    // ARC causes a compiler error at any message send that WoolDelegate's
    // interface doesn't declare. The variable has to be typed id or cast
    // whenever a message send is made.
    // This may not be an issue, though, since the primary purpose of
    // WoolDelegate means it will be receiving messages from framework objects,
    // i.e., from code that is already compiled (and which is indeed sending its
    // messages to id).
        
    id d =  [[WoolDelegate alloc] init];
    
    test_respondsToInheritedSelector(d);
    test_respondsToDefinedSelector(d);
    [d addForSelector:@selector(estragon) handler:(GenericBlock)^{ NSLog(@"estragon: %d", 10); }];
    test_respondsToSetSelector(d);
    [d performSelector:@selector(estragon)];
    [d addForSelector:@selector(poireaux:) fromProtocol:@protocol(Allia) handler:(GenericBlock)(^id (NSArray * leek) {
        NSLog(@"poireaux:'s received array: %@", leek);
        return [leek objectAtIndex:0];
    })];
    NSArray * poireaux_arr = [NSArray arrayWithObjects:@"Abacus", @"Banana", @"Capuchin", nil];
    id o = [d poireaux:poireaux_arr];
    NSLog(@"Result of poireaux: %@", o);
    
    [d addForSelector:@selector(oignon:) fromProtocol:@protocol(Allia) handler:(GenericBlock)^(NSString * onion){
        NSLog(@"oignon:'s lowercased argument: %@", [onion lowercaseString]);
    }];
    [d oignon:@"SUPERCALIFRAGILISTICEXPIALIDOCIOUS!"];
    [d addForSelector:@selector(pommes:terre:) handler:(GenericBlock)^(NSString * potato, NSString * earth){
        NSLog(@"pommes:terre:'s cat'd arguments: %@", [potato stringByAppendingString:earth]);
    }];
    
    [d pommes:@"Hello, " terre:@"Bird"];
    
    // Test selector not from protocol; encoding string will have to be constructed
    NSArray * frick_arr = [NSArray arrayWithObjects:@"behemoth", @"leviathan", @"bantam", nil];
    [d addForSelector:@selector(frick:a:frack:) handler:(GenericBlock)(^NSNumber * (BOOL b, int i, NSArray * arr){
        return (b ? [NSNumber numberWithInt:i] : [NSNumber numberWithUnsignedInteger:[arr count]]);
    })];
    NSNumber * r;
    int a_arg = 10;
    r = [d frick:YES a:a_arg frack:frick_arr];
    NSLog(@"Expected: %d; Actual: %@", a_arg, r);
    a_arg = 100;
    r = [d frick:NO a:a_arg frack:frick_arr];
    NSLog(@"Expected: %ld; Actual: %@", [frick_arr count], r);
    
    [d addForSelector:@selector(ail:avec:huile:) fromProtocol:@protocol(Allia) handler:(GenericBlock)(^NSNumber * (BOOL b, int i, NSArray * arr){
        return (b ? [NSNumber numberWithInt:i] : [NSNumber numberWithUnsignedInteger:[arr count]]);
    })];
    
    a_arg = 10;
    r = [d ail:YES avec:a_arg huile:frick_arr];
    NSLog(@"Expected: %d; Actual: %@", a_arg, r);
    r = [d ail:NO avec:a_arg huile:frick_arr];
    NSLog(@"Expected: %ld; Actual: %@", [frick_arr count], r);
        
    }
    return 0;
}

