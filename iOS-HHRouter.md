---
title: iOS开发 — HHRouter路由数据传递开发分享
author: 檀邹
date: 2018-03-22 11:42:50
categories:
- 经验总结

tags: 
- HHRouter
- 控制器间传值

---

# 前言
在日常开发中，随着业务越来越复杂，代码中的耦合度将会大大增强，各模块间的相互调用将导致相互间的强依赖，我们可以通过使用`HHRouter`路由设计思路来减少代码的耦合度。

<!-- more -->


# 一、传统控制器间的属性传递

在日常开发中经常碰到一些属性正向传递的问题，比如说`controllerA`页面 push 到`controllerB`页面，我们一般可以通过给控制器属性赋值以及初始化时将属性注入到控制器的方式进行数据的正向传递：

```objc
//赋值
UIViewController *controllerB = [[UIViewController alloc] init];
controllerB.name = @"xiaoming";
controllerB.userId = @"123456";
[self.navigationController pushViewController:controllerB animated:YES];

//初始化属性注入
UIViewController *controllerB = [[UIViewController alloc] initWithName:@"xiaoming" userId:@"123456"];
[self.navigationController pushViewController:controllerB animated:YES];
```
若需要赋值的属性过多，这么操作将会变得很繁琐，代码也会过于冗余。同时注入的方式将使得两者间产生强依赖，`controllerA`若要跳转至`controllerB`，就必须要依赖`controllerB`，当随着业务的越来越复杂，将会产生错综复杂的依赖链，增加了代码耦合性。

# 二、`HHRouter`实现机制与使用

## 2.1、控制器间的数据传递

`HHRouter`是布丁动画开源的一个 router， URL Router 可以将控制器映射成唯一的 URL，其借鉴了 web 的开发思想，引入一个中介性质的 router，通过 router 完成 VC 间的数据传递。

`HHRouter`为`ViewController`提供了两种方法：

```objc
//将ViewController映射成对应的router
- (void)map:(NSString *)route toControllerClass:(Class)controllerClass;

//使用router匹配到对应的ViewController
- (UIViewController *)matchController:(NSString *)route;
```
使用`HHRouter`将 userId 传递给`TZLoginViewController`：

```objc
[[HHRouter shared] map:@"/login/:userId/" toControllerClass:[TZLoginViewController class]];
UIViewController *loginVC = [[HHRouter shared] matchController:@"/login/10009999/?a=6&b=7"];
[self.navigationController pushViewController:loginVC animated:YES];
```
代码中的` @"/login/10009999/"`作为路由的链接将`userId`、`a`、`b`的值传递给`TZLoginViewController`。
为了实现该机制，`HHRouter`会通过 `subRoutesToRoute` 函数将路由匹配成对应规则的字典：

```objc
- (void)map:(NSString *)route toControllerClass:(Class)controllerClass {
    NSMutableDictionary *subRoutes = [self subRoutesToRoute:route];
    subRoutes[@"_"] = controllerClass;
}

- (NSMutableDictionary *)subRoutesToRoute:(NSString *)route {
    NSArray *pathComponents = [self pathComponentsFromRoute:route];
    NSInteger index = 0;
    NSMutableDictionary *subRoutes = self.routes;
   while (index < pathComponents.count) {
        NSString *pathComponent = pathComponents[index];
        if (![subRoutes objectForKey:pathComponent]) {
            subRoutes[pathComponent] = [[NSMutableDictionary alloc] init];
        }
        subRoutes = subRoutes[pathComponent];
        index++;
    }
    return subRoutes;
}

```
例如：

```objc
[[HHRouter shared] map:@"/login/:userId/" toControllerClass:[TZLoginViewController class]];
[[HHRouter shared] map:@"/register/:registerId/" toControllerClass:[TZRegisterViewController class]];
[[HHRouter shared] map:@"/login/:userId/logout/?clearUserInfo = YES" toControllerClass:[TZLogoutViewController class]];
```

将这三条路由匹配成对应的路由规则字典：

```objc
@{
      @"register" : @{
              @":registerId" : @{
                      @"_" : @"TZRegisterViewController"
                      }
              },
      @"login" : @{
              @":userId" : @{
                      @"_" : @"TZLoginViewCOntroller",
                      @"logout" : @{
                              @"_" : @"TZLogoutViewController"
                              }
                      }
              }
}

```
匹配完成后，当有一条路由过来时，首先`HHRouter`将匹配对应的 scheme（login），当 scheme 存在时，生成参数字典 params，并传递给`TZLoginViewController`实例：

```objc
//通过router获取到对应的controller
UIViewController *loginVC = [[HHRouter shared] matchController:@"/login/920413/?autoLogin=YES&rememberPassword=YES"];

//生成参数字典
@{
      @"controller_class" : @"TZLoginViewController",
      @"router"           : @"/login/920413/",
      @"userId"           : @"920413",
      @"autoLogin"        : @(YES),
      @"rememberPassword" : @(YES)
}

//获取路由匹配的ViewController
 - (UIViewController *)matchController:(NSString *)route {
    NSDictionary *params = [self paramsInRoute:route];
    Class controllerClass = params[@"controller_class"];

    UIViewController *viewController = [[controllerClass alloc] init];

    if ([viewController respondsToSelector:@selector(setParams:)]) {
        [viewController performSelector:@selector(setParams:)
                             withObject:[params copy]];
    }
    return viewController;
}

```
`TZLoginViewController`中相应的参数都被绑定在 params 属性的字典里：

```objc
- (void)setParams:(NSDictionary *)params {
    _params = params;
    
    NSLog(@"Params: %@", params);
}
```

使用HHRouter大大减小了`UIVIewController`之间的相互依赖，若`ViewController`属性不断变化，我们只需要在`ViewController`中修改使用到的属性即可，它的各项参数均可通过 URL Router 的参数完成传递，大大降低了两者间的耦合度。

## 2.2 block 数据传递

`HHRouter`还提供了 block 传值方式，其主要包含了三个方法：

```objc
//设置路由规则
- (void)map:(NSString *)route toBlock:(HHRouterBlock)block;

//匹配路由规则
- (id)callBlock:(NSString *)route;
- (HHRouterBlock)matchBlock:(NSString *)route;
```
其中，map 用于设置路由规则，`matchBlock`用于匹配路由规则，找到指定的 block，但是不会主动调用该 block，需要在后面手动调用。`callBlock`方法在找到指定的 block 后，立即调用。

设置路由规则，映射成对应的 URL：

```objc
[[HHRouter shared] map:@"/user/add/" toBlock:^id(NSDictionary *params) {
        NSLog(@"b = %@", [params objectForKey:@"b"]);
        return nil;
}];
```
这条规则对应的会生成一个路由规则的字典：

```objc
@{
      @"user" : @{
              @": add" : @{
                      @"_" = "<__NSGlobalBlock__: 0x108edf138>"
                      }
              },
}
```

在对应触发事件处，匹配路由:

```objc
[[HHRouter shared] callBlock:@"/user/add/?b=20"];
```

匹配出的路由参数字典：

```objc
@{
      @"block"      :   @"<__NSGlobalBlock__: 0x108edf138>",
      @"router"     :   @"/user/add/?b=20",
      @"b"          :   @"20",
 }
```
这样匹配的参数就可以通过 block 进行回调了。

## 2.3 工厂`goPage`方法解析

我们平常的项目开放中，在做组件间的跳转时总是会用到工厂的`goPage`方法，工厂`goPage`方法其实也是类似这种使用路由的方式获取相对应的控制器进行 push：

```objc
NSString *url = @"cmp://com.nd.sdp.component.transaction-flow/transaction_main_page";

```
其中`cmp://`作为匹配的 scheme，只有当 scheme 匹配成功了才会继续进行匹配，`com.nd.sdp.component.transaction-flow/transaction_main_page`是组件页面的唯一路由地址，通过`getPage`方法获取到对应的`APFPageWrapper `实例，其包含了目的控制器以及相关的参数字典,通过`getController`和`getParam`来获取：

```objc

APFPageWrapper *pageWrapper = [self getPage:uri];
    
//获取URL匹配到的控制器
UIViewController *webViewController = [pageWrapper getController];

//获取URL匹配到的参数
NSString *strTitle = [[pageWrapper getParam] objectForKey: @"title"] ? : @"";

//获取源控制器
UIViewController *sourceViewController = context[KEY_CMP_SRC_CONTROLLER];

[sourceViewController.navigationController pushViewController:webViewController animated:YES];

```
# 三、小结

### 优点：
通过`HHrouter`将`UIViewController`映射成 URL，从而支持页面像 web 那样通过URL进行页面跳转，首先这能够极大的减小`UIViewController`之间的耦合度，其次当每个界面都拥有唯一且不重复的 URL，将带来额外的好处。譬如你将更容易实现 Push 打开指定的界面、追踪用户浏览记录等需求。

### 缺点：
- 这种基于`URL Router`方案只能传递常规对象，无法传递自定义对象。<Br>
- URL 的 map 规则是需要注册的，它们一般会在`load`方法里面写。这样会影响 App 启动速度的。<Br>
- URL 链接里面关于组件和页面的名字都是硬编码，参数也都是硬编码。而且每个 URL 参数字段都必须要一个文档进行维护，这将对业务开发人员造成负担。

### 该库为使用分享，并非建议大家在项目中再次引入.

### 使用到的第三方库：

#### `HHRouter`：[https://github.com/Huohua/HHRouter](https://github.com/Huohua/HHRouter)

#### CocoaPods：pod 'HHRouter', '~> 0.1.8'：


参考链接：

[https://github.com/Huohua/HHRouter#cocoapods](https://github.com/Huohua/HHRouter#cocoapods)

[http://www.cocoachina.com/ios/20170301/18811.html](http://www.cocoachina.com/ios/20170301/18811.html)

[https://segmentfault.com/a/1190000002585537](https://segmentfault.com/a/1190000002585537)
