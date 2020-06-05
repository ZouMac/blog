//
//  main.m
//  TZFishHook
//
//  Created by Zou Tan on 2020/6/3.
//  Copyright © 2020 Zou Tan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "fishhook.h"

#import <objc/runtime.h>

static void (*orig_nslog)(NSString *format, ...);

void my_NSLog(NSString *format, ...) {
    orig_nslog(@"%@: nslog has been hook \n", format);
}


static int (*orig_sleep)(unsigned int);

int my_sleep(unsigned int a) {
    orig_nslog(@"orig_sleep has been hook");
    return orig_sleep(a);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        
        NSLog(@"before hook");
//        sleep(1);
        
        struct rebinding logBind;
        logBind.name = "NSLog";
        logBind.replacement = my_NSLog;
        logBind.replaced = (void *)&orig_nslog;
        
        struct rebinding sleepBind;
        sleepBind.name = "sleep";
        sleepBind.replacement = my_sleep;
        sleepBind.replaced = (void *)&orig_sleep;
        
        struct rebinding rebs[] = {logBind, sleepBind};
        
        rebind_symbols(rebs, 2);
        
//        sleep(1);
        NSLog(@"after hook");
        
    }
    return NSApplicationMain(argc, argv);
}
