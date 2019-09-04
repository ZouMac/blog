//
//  main.m
//  WCDBSourceCodeAnaylize
//
//  Created by Zou Tan on 2019/8/23.
//  Copyright © 2019 Zou Tan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TZStock.h"
#import <WCDB/WCDB.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        WCTDatabase *dataBase = [[WCTDatabase alloc] initWithPath:@"/Users/zoutan/Desktop/stock.db"];
        BOOL result = [dataBase createTableAndIndexesOfName:@"stock" withClass:TZStock.class];
        if (result) {
            NSLog(@"建表成功");
            NSArray *stocks = @[@{@"name": @"FLH", @"code": @666}, @{@"name": @"ND", @"code": @777}, @{@"name": @"QT", @"code": @000}];
            [stocks enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                TZStock *stock = [[TZStock alloc] init];
                stock.name = obj[@"name"];
                stock.code = ((NSNumber *)obj[@"code"]).intValue;
                stock.date = [NSDate dateWithTimeIntervalSinceNow:111];
                [dataBase insertObject:stock into:@"stock"];
            }];


            [dataBase deleteObjectsFromTable:@"stock" where:TZStock.code == 777];

            TZStock *editStock = [[TZStock alloc] init];
            editStock.code = 888;
            [dataBase updateRowsInTable:@"stock" onProperty:TZStock.code withObject:editStock limit:nil];

            NSArray <TZStock *> *searchStocks = [dataBase getObjectsOfClass:TZStock.class fromTable:@"stock" orderBy:TZStock.code.order()];
            NSLog(@"finish");
        
        }
    }
    return 0;
}



