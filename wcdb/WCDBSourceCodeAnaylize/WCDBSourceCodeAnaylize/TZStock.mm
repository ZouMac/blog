//
//  TZStock.m
//  WCDBSourceCodeAnaylize
//
//  Created by Zou Tan on 2019/8/23.
//  Copyright © 2019 Zou Tan. All rights reserved.
//

#import "TZStock.h"

//#define __WCDB_PROPERTY_TYPE(className, propertyName)   decltype([className new].propertyName)
//#define kTEST(className, propertyName) decltype([className new].propertyName)

@implementation TZStock

WCDB_IMPLEMENTATION(TZStock);

//WCDB_SYNTHESIZE(TZStock, code);
//WCDB_SYNTHESIZE(TZStock, name);
//WCDB_SYNTHESIZE(TZStock, date);


+ (const WCTProperty &)code {
    _s_TZStock_binding;
    _s_TZStock_binding.addColumnBinding<decltype([TZStock new].code)>("code", "code");
    static const WCTProperty s_property("code", TZStock.class, _s_TZStock_binding.addColumnBinding<decltype([TZStock new].code)>("code", "code"));
    return s_property;
}

//#define WCDB_IMPLEMENTATION(className)
//static WCTBinding __WCDB_BINDING(className)(className.class);
//static WCTPropertyList __WCDB_PROPERTIES(className);
//+(const WCTBinding *) objectRelationalMappingForWCDB
//{
//if (self.class != className.class) {
//WCDB::Error::Abort("Inheritance is not supported for ORM");
//}
//return &__WCDB_BINDING(className);
//}

//+(const WCTPropertyList &) AllProperties
//{
//return __WCDB_PROPERTIES(className);
//}
//+(const WCTAnyProperty &) AnyProperty
//{
//static const WCTAnyProperty s_anyProperty(className.class);
//return s_anyProperty;
//}
//+(WCTPropertyNamed) PropertyNamed { return WCTProperty::PropertyNamed; }


@end
