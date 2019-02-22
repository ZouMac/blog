//
//  main.m
//  FishHookDemo
//
//  Created by 林训键 on 2018/8/25.
//  Copyright © 2018 林训键. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import "fishhook.h"

static int (*original_open)(const char *, int, ...);

int new_open(const char *path, int oflag, ...) {
    va_list ap = {0};
    mode_t mode = 0;
    
    if ((oflag & O_CREAT) != 0) {
        va_start(ap, oflag);
        mode = va_arg(ap, int);
        va_end(ap);
        printf("Calling real open('%s', %d, %d)\n", path, oflag, mode);
        return original_open(path, oflag, mode);
    } else {
        printf("Calling real open('%s', %d)\n", path, oflag);
        return original_open(path, oflag, mode);
    }
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        struct rebinding open_rebinding = { "open", new_open, (void *)&original_open };
        rebind_symbols( (struct rebinding[1]){ open_rebinding } , 1);
        __unused int fd = open(argv[0], O_RDONLY);
    }
    return 0;
}

