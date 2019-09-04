//
//  TZStock.m
//  WCDBSourceCodeAnaylize
//
//  Created by Zou Tan on 2019/8/23.
//  Copyright © 2019 Zou Tan. All rights reserved.
//

#import "TZStock.h"


@implementation TZStock


//WCDB_IMPLEMENTATION(TZStock);


static WCTBinding _s_TZStock_binding(TZStock.class);
static WCTPropertyList _s_TZStock_properties;

+ (const WCTBinding *) objectRelationalMappingForWCDB {
    if (self.class != TZStock.class) {
        WCDB::Error::Abort("Inheritance is not supported for ORM");
    }
    return &_s_TZStock_binding;
}

+ (const WCTPropertyList &) AllProperties {
    return _s_TZStock_properties;
}

+ (const WCTAnyProperty &) AnyProperty {
    static const WCTAnyProperty s_anyProperty(TZStock.class);
    return s_anyProperty;
}

+(WCTPropertyNamed) PropertyNamed {
    return WCTProperty::PropertyNamed;
}

//WCTProperty(const char *name,
//            Class cls,
//            const std::shared_ptr<WCTColumnBinding> &columnBinding);

+ (const WCTProperty &)code {
    static const WCTProperty s_property("code", TZStock.class, _s_TZStock_binding.addColumnBinding<decltype([TZStock new].code)>("code", "code"));
    return s_property;
}

static const auto UNUSED_UNIQUE_ID = [](WCTPropertyList &propertyList) { // lambda表达式匿名函数
    propertyList.push_back(TZStock.code);
    return nullptr;
}(_s_TZStock_properties); // 将TZStock.code塞到propertyList（_s_TZStock_properties）中


//WCDB_SYNTHESIZE(TZStock, code);
WCDB_SYNTHESIZE(TZStock, name);
WCDB_SYNTHESIZE(TZStock, date);

@end
