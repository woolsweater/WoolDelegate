//
//  main.m
//  WoolDelegate
//
//  Created by Joshua Caswell on 12/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WoolDelegate.h"
#import <objc/runtime.h>


#define NSStringFromBOOL(b) ((b) ? @"YES" : @"NO")

@protocol Allia <NSObject>

- (id)poireaux: (NSArray *)leek;
- (void)oignon: (NSString *)onion;
- (void)pommes: (NSString *)apple terre:(NSString *)earth;
- (NSNumber *)ail:(BOOL)b avec:(int)i huile:(NSArray *)a;

@end

static void test_respondsToInheritedSelector(WoolDelegate * d) {
    
    NSLog(@"%@", NSStringFromBOOL([d respondsToSelector:@selector(class)]));
}

static void test_respondsToDefinedSelector(WoolDelegate * d) {
    
    NSLog(@"%@", NSStringFromBOOL([d respondsToSelector:@selector(handlerForSelector:)]));
}

static void test_respondsToSetSelector(WoolDelegate * d) {
    
    NSLog(@"%@", NSStringFromBOOL([d respondsToSelector:@selector(estragon)]));
}

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    WoolDelegate * d =  [[WoolDelegate alloc] init];
    
//    test_respondsToInheritedSelector(d);
//    test_respondsToDefinedSelector(d);
//    [d addForSelector:@selector(estragon) handler:(GenericBlock)^{ NSLog(@"%d", 10); }];
//    test_respondsToSetSelector(d);
//    //[d performSelector:@selector(estragon)];
//    [d addForSelector:@selector(poireaux:) fromProtocol:@protocol(Allia) handler:(GenericBlock)(^id (NSArray * leek) {
//        NSLog(@"%@", leek);
//        return [leek objectAtIndex:0];
//    })];
//    NSArray * poireaux_arr = [[NSArray arrayWithObjects:@"Abacus", @"Banana", @"Capuchin", nil] retain];
//    NSLog(@"%@", poireaux_arr);
//    id o = [d poireaux:poireaux_arr];
//    NSLog(@"Result of poireaux: %@", o);
//    
    [d addForSelector:@selector(oignon:) fromProtocol:@protocol(Allia) handler:(GenericBlock)^(NSString * onion){
        NSLog(@"%@", [onion lowercaseString]);
    }];
    [d oignon:@"SUPERCALIFRAGILISTICEXPIALIDOCIOUS!"];
    [d addForSelector:@selector(pommes:terre:) handler:(GenericBlock)^(NSString * potato, NSString * earth){
        NSLog(@"%@", [potato stringByAppendingString:earth]);
    }];
    
    [d pommes:@"Hello, " terre:@"Bird"];
    
    NSArray * frick_arr = [NSArray arrayWithObjects:@"behemoth", @"leviathan", @"bantam", nil];
    [d addForSelector:@selector(frick:a:frack:) handler:(GenericBlock)(^NSNumber * (BOOL b, int i, NSArray * arr){
        return (b ? [NSNumber numberWithInt:i] : [NSNumber numberWithUnsignedInteger:[arr count]]);
    })];
    NSNumber * r;
    r = [d frick:YES a:10 frack:frick_arr];
    NSLog(@"res: %@", r);
    r = [d frick:NO a:100 frack:frick_arr];
    NSLog(@"res: %@", r);
    
    [d addForSelector:@selector(ail:avec:huile:) fromProtocol:@protocol(Allia) handler:(GenericBlock)(^NSNumber * (BOOL b, int i, NSArray * arr){
        return (b ? [NSNumber numberWithInt:i] : [NSNumber numberWithUnsignedInteger:[arr count]]);
    })];
    
    r = [d ail:YES avec:10 huile:frick_arr];
    NSLog(@"%@", r);
    r = [d ail:NO avec:100 huile:frick_arr];
    NSLog(@"%@", r);
    
    [pool drain];
    return 0;
}

