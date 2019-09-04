//
//  TZStock.h
//  WCDBSourceCodeAnaylize
//
//  Created by Zou Tan on 2019/8/23.
//  Copyright © 2019 Zou Tan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WCDB/WCDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface TZStock : NSObject<WCTTableCoding>

//@property (nonatomic, retain) NSString *name;
//
//@property (nonatomic, assign) int code;
//
//@property (nonatomic, retain) NSDate *date;


@property (assign) int code;
@property(retain) NSString *name;
@property(retain) NSDate *date;
////@property(assign) int code;
//
+ (const WCTProperty &) code;
+ (const WCTProperty &) name;
+ (const WCTProperty &) date;
//WCDB_PROPERTY(code);
//WCDB_PROPERTY(name);
//WCDB_PROPERTY(date);

@end

NS_ASSUME_NONNULL_END
