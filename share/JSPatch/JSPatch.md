#JSPatch学习实践

## JSPatch介绍

JSPatch是一个开源的项目[Github](https://github.com/bang590/JSPatch)，只需要在项目里引入极小的引擎文件，就可以使用 JavaScript 调用任何 Objective-C 的原生接口，替换任意 Objective-C 原生方法。目前主要用于下发 JS 脚本替换原生 Objective-C 代码，实时修复线上 bug。

### 实现原理

- 类名 方法名 映射 相应的类和方法

  ```objective-c
  //    生成类
  Class destinationClass = NSClassFromString(@"SecondViewController");
  id viewController = [[destinationClass alloc] init];
  //    生成方法
  SEL selector = NSSelectorFromString(@"changeBackgroundColor");
  [viewController performSelector:selector];
      
  [self.navigationController pushViewController:viewController animated:YES];
  ```

- 为注册的新类添加方法

  ```objective-c
  Class superCls = NSClassFromString(@"ViewController");
  Class cls = objc_allocateClassPair(superCls, "childViewController", 0);
  objc_registerClassPair(cls);
  
  SEL selector = NSSelectorFromString(@"setBlueBackground");
  class_addMethod(cls, selector, setBlueBackground, "v@:");
  
  id newVC = [[cls alloc] init];
  [self.navigationController pushViewController:newVC animated:YES];
  [newVC performSelector:@selector(setBlueBackground)];
  ```

- 替换某个类的方法为新的实现

  ```objective-c
  Class sourceClass = NSClassFromString(@"ViewController");
  id sourceControler = [[sourceClass alloc] init];
   
  SEL changeTitle = NSSelectorFromString(@"changeTitle");   
  class_replaceMethod(sourceClass, changeTitle, donotChangeTitle, "");    [sourceControler performSelector:changeTitle];
  ```
  实现原理：JS传递字符串给OC，OC通过 Runtime 接口调用和替换OC方法。

###方法调用

引入JSPatch后，可以通过以下代码创建一个UIView对象，并且设置背景颜色和透明度。涵盖了 require 引入类，JS 调用接口，消息传递，对象持有和转换，参数转换这五个方面。

```js
require('UIView')
var view = UIView.alloc().init()
view.setBackgroundColor(require('UIColor').grayColor())
view.setAlpha(0.5)
```

####require

调用 `require('UIView')` 后，就可以直接使用 `UIView` 这个变量去调用相应的类方法了，require 做的事很简单，就是在JS全局作用域上创建一个同名变量，变量指向一个对象，对象属性 `__clsName` 保存类名，同时表明这个对象是一个 OC Class。

```js
var _require = function(clsName) {
  if (!global[clsName]) {
    global[clsName] = {
      __clsName: clsName
    }
  }
  return global[clsName]
}
```

####JS调用接口

a.`require('UIView')` 这句话在 JS 全局作用域生成了 `UIView` 这个对象，它有个属性叫 `__isCls`，表示这代表一个 OC 类。调用 `UIView` 这个对象的 `alloc()` 方法，会去到 `__c()`函数，在这个函数里判断到调用者 `__isCls` 属性，知道它是代表 OC 类，把方法名和类名传递给 OC 完成调用。实现类似OC/Lua/Ruby等的消息转发机制：

```javascript
UIView.alloc().init()
->
UIView.__c('alloc')().__c('init')()
```

```javascript
Object.prototype.__c = function(methodName) {
  if (!this.__obj && !this.__clsName) return this[methodName].bind(this);
  var self = this
  return function(){
    var args = Array.prototype.slice.call(arguments)
    return _methodFunc(self.__obj, self.__clsName, methodName, args, self.__isSuper)
  }
}
```

`_methodFunc()` 就是把相关信息传给OC，OC用 Runtime 接口调用相应方法，返回结果值，这个调用就结束了。

b.对于一个自定义id对象，JavaScriptCore 会把这个自定义对象的指针传给 JS，这个对象在 JS 无法使用，但在回传给 OC 时 OC 可以找到这个对象。对于这个对象生命周期的管理，如果JS有变量引用时，这个 OC 对象引用计数就加1 ，JS 变量的引用释放了就减1，如果 OC 上没别的持有者，这个OC对象的生命周期就跟着 JS 走了，会在 JS 进行垃圾回收时释放。

####消息传递

消息传递使用了JavaScriptCore 的接口，OC端在启动JSPatch引擎时会创建一个 JSContext 实例，JSContext 是JS代码的执行环境，可以给 JSContext 添加方法，JS就可以直接调用这个方法。JS通过调用 JSContext 定义的方法把数据传给OC，OC通过返回值传会给JS：

```javascript
JSContext *context = [[JSContext alloc] init];
context[@"hello"] = ^(NSString *msg) {
    NSLog(@"hello %@", msg);
};
[_context evaluateScript:@"hello('word')"];   
```

#### 方法替换

让`ORIGViewDidLoad`指向`viewDidLoad`,`viewDidLoad`指向新的实现`viewDidLoadIMP`。

```objective-c
static void viewDidLoadIMP (id slf, SEL sel) {
   JSValue *jsFunction = …;
   [jsFunction callWithArguments:nil];
}
 
Class cls = NSClassFromString(@"UIViewController");
SEL selector = @selector(viewDidLoad);
Method method = class_getInstanceMethod(cls, selector);
 
//获得viewDidLoad方法的函数指针
IMP imp = method_getImplementation(method)
 
//获得viewDidLoad方法的参数类型
char *typeDescription = (char *)method_getTypeEncoding(method);
 
//新增一个ORIGViewDidLoad方法，指向原来的viewDidLoad实现
class_addMethod(cls, @selector(ORIGViewDidLoad), imp, typeDescription);
 
//把viewDidLoad IMP指向自定义新的实现
class_replaceMethod(cls, selector, viewDidLoadIMP, typeDescription);
```

替换 UIViewController 的 -viewWillAppear: 方法为例：

1. 把UIViewController的 `-viewWillAppear:` 方法通过 `class_replaceMethod()` 接口指向 `_objc_msgForward`，这是一个全局 IMP，OC 调用方法不存在时都会转发到这个 IMP 上，这里直接把方法替换成这个 IMP，这样调用这个方法时就会走到 `-forwardInvocation:`。

2. 为UIViewController添加 `-ORIGviewWillAppear:` 和 `-_JPviewWillAppear:` 两个方法，前者指向原来的IMP实现，后者是新的实现，稍后会在这个实现里回调JS函数。

3. 改写UIViewController的 `-forwardInvocation:` 方法为自定义实现。一旦OC里调用 UIViewController 的 `-viewWillAppear:` 方法，经过上面的处理会把这个调用转发到 `-forwardInvocation:` ，这时已经组装好了一个 NSInvocation，包含了这个调用的参数。在这里把参数从 NSInvocation 反解出来，带着参数调用上述新增加的方法 `-_JPviewWillAppear:`，在这个新方法里取到参数传给JS，调用JS的实现函数。整个调用过程就结束了，整个过程图示如下：

   ![JSPatch方法替换](https://camo.githubusercontent.com/48cbbd8ee1c8af0ef8f18a2e0ab0d50a085afab1/687474703a2f2f626c6f672e636e62616e672e6e65742f77702d636f6e74656e742f75706c6f6164732f323031352f30362f4a535061746368322e706e67)

   ​

##JSPatch使用

### OC与JSPatch代码转换

```objective-c
//OC
@interface CompareJSPatchController : UITableViewController
@end
    
@interface CompareJSPatchController()<UIAlertViewDelegate>
    
@end
    
@implementation CompareJSPatchController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self dataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = [self dataSource][indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Alert" message:[self dataSource][indexPath.row] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    NSLog(@"click btn %@",[alertView buttonTitleAtIndex:buttonIndex]);
}


- (NSArray *)dataSource {
    
    if (_data == nil) {
        _data = [NSMutableArray array];
        for (int i = 0; i < 20; i++) {
            [_data addObject:[NSString stringWithFormat:@"cell from js %d",i]];
        }
    }
    return _data;
}

@end
```



```js
//JSPatch
defineClass('CompareJSPatchController : UITableViewController <UIAlertViewDelegate>', ['data'], {
            
    dataSource: function() {
    var data = self.data();
    if (data) return data;
    var data = [];
    for (var i = 0; i < 20; i ++) {
    data.push("cell from js " + i);
    }
    self.setData(data)
    return data;
    },


    numberOfSectionsInTableView: function(tableView) {
    return 1;
    },


    tableView_numberOfRowsInSection: function(tableView, section) {
    return self.dataSource().length;
    },


    tableView_cellForRowAtIndexPath: function(tableView, indexPath) {
    var cell = tableView.dequeueReusableCellWithIdentifier("cell")
    if (!cell) {
    cell = require('UITableViewCell').alloc().initWithStyle_reuseIdentifier(0, "cell")
    }
    cell.textLabel().setText(self.dataSource()[indexPath.row()])
    return cell
    },


    tableView_heightForRowAtIndexPath: function(tableView, indexPath) {
    return 60
    },


    tableView_didSelectRowAtIndexPath: function(tableView, indexPath) {
    var alertView = require('UIAlertView').alloc().initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles("Alert",self.dataSource()[indexPath.row()], self, "OK",  null);
    alertView.show()
    },


    alertView_willDismissWithButtonIndex: function(alertView, idx) {
    console.log('click btn ' + alertView.buttonTitleAtIndex(idx).toJS())
    }
    })
})
```

#### defineClass

`defineClass(classDeclaration, [properties] instanceMethods, classMethods)`

@param `classDeclaration`: 字符串，`className:superClassName <Protocol>`

@param `properties`: 新增property，字符串数组，可省略 

@param `instanceMethods`: 要添加或覆盖的实例方法 

@param `classMethods`: 要添加或覆盖的类方法

```js
defineClass("类名",["成员变量"], {
    //实例方法,不同方法之间使用逗号分隔
    viewDidLoad:function() {
        //do something
    },
    ...
},
    {
    //类方法,不同方法之间使用逗号分隔
    getClassName:function() {
        console.log(self.class());
        return self.class();
    },
    ...
})
```

####ORIG使用原方法

```javascript
defineClass("类名",["成员变量"], {
    //覆盖原方法
    viewDidLoad:function() {
        //do something
    },
    //使用原方法
    ORGIviewDidLoad:function() {
        //do something
    },
    ...
})
```

#### 导入头文件

`require('UIColor,UIView,NSURL,NSURLRequest,UIFont,UILabel'); `

```javascript
require('UIView')
var view = UIView.alloc().init()
view.setBackgroundColor(require('UIColor').grayColor())
view.setAlpha(0.5)
```

####Protocol

```javascript
//JSPatch
defineClass("JPViewController: UIViewController <UIAlertViewDelegate>", {
  viewDidAppear: function(animated) {
    var alertView = require('UIAlertView').alloc().initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles("Alert", self.dataSource().objectAtIndex(indexPath.row()), self, "OK", null)
     alertView.show()
  },
    
  alertView_clickedButtonAtIndex: function(alertView, buttonIndex) {
    console.log('clicked index ' + buttonIndex)
  }
})
```

####动态新增 Property

```js
defineClass("JPTableViewController", ['data', 'totalCount'], {
  init: function() {
     self = self.super().init()
     self.setData(["a", "b"])     //添加新的 Property (id data)
     self.setTotalCount(2)
     return self
  },
  viewDidLoad: function() {
     var data = self.data()     //获取 Property 值
     var totalCount = self.totalCount()
  },
})
```

####结构体

`JSPatch`原生支持 `CGRect / CGPoint / CGSize / NSRange` 这四个 `struct` 类型，用 `JS` 对象表示:

```objective-c
CGRectMake(20, 20, 100, 100)                      //OC
{x:20, y:20, width:100, height:100}               //JSPatch

CGPointMake(10,10)                                //OC
{x: 10, y: 10}                                    //JSPatch

CGSizeMake(100, 100)                              //OC
{width: 100, height:100}                          //JSPatch

NSMakeRange(0, 1)                                 //OC
{location: 0, length: 1}                          //JSPatch
```

- 若要让 JS 脚本支持其他 struct 类型，需要先手动注册[添加 struct 类型支持](https://github.com/bang590/JSPatch/wiki/添加-struct-类型支持)

  ```
  //支持 CGAffineTransform
  require('JPEngine').defineStruct({
    "name": "CGAffineTransform",
    "types": "FFFFFF",
    "keys": ["a", "b", "c", "d", "tx", "ty"]
  })
  ```

####Selector 

在JS使用字符串代表 `Selector`（需要使用“ ”包裹字符串）:

```objective-c
//Obj-C
[self performSelector:@selector(viewWillAppear:) withObject:@(YES)];

//JS
self.performSelector_withObject("viewWillAppear:", 1)
```

#### 打印

`console.log()`

####nil

JS 上的 `null` 和 `undefined` 都代表 OC 的 `nil`，如果要表示 `NSNull`, 用 `nsnull` 代替，如果要表示 `NULL`, 也用 `null` 代替

####NSArray / NSString / NSDictionary

`NSArray / NSString / NSDictionary` 不会自动转成对应的 JS 类型，像普通 `NSObject` 一样使用它们

```objective-c
//在OC中创建的数组和字典
@implementation JPObject
+ (NSArray *)data {
  return @[[NSMutableString stringWithString:@"JS"]]
}
+ (NSMutableDictionary *)dict {
    return [[NSMutableDictionary alloc] init];
}
@end
```

```javascript
//在JSPatch中获取与使用
require('JPObject')
var ocStr = JPObject.data().objectAtIndex(0)
ocStr.appendString("Patch")

var dict = JPObject.dict()
dict.setObject_forKey(ocStr, 'name')
console.log(dict.objectForKey('name'))
```

####weak / strong

```js
var weakSelf = __weak(self)
self.setCompleteBlock(block(function(){
    ...
    var strongSelf = __strong(self)
    ...
}))
```

####Block

- block传值

  将JS函数作为block传递给OC

  需要使用`block(paramTypes, function)`接口包装

  ```objective-c
  + (void)request:(void(^)(NSString *content, BOOL success))callback {
      callback(@"I'm content", YES);
  }
  ```

  ```javascript
  require('JPEngine').addExtensions(['JPBlock']);//接入JPBlock扩展，使用完整的block
  require('ViewController').request(block("void, NSString *, BOOL", function(ctn, succ) {
        if (succ) log(ctn)  //output: I'm content
  }));
  ```

  将OC中的block传递给JSPatch

  ```objective-c
  typedef void(^JPBlock)(NSDictionary *dict);
  + (JPBlock)getBlock {
      NSString *ctn = @"JSPatch";
      JPBlock block = ^(NSDictionary *dict) {
          NSLog(@"I'm %@, version: %@", ctn, dict[@"version"]);
      };
      return block;
  }
  ```

  ```javascript
  var block = require('ViewController').getBlock();
  block({version:'1.0.0'});
  ```

  总结：JS 没有 block 类型的变量，OC 的 block 对象传到 JS 会变成 JS function，所有要从 JS 传 block 给 OC 都需要用 `block()` 接口包装。

- [JPBlock扩展](https://github.com/bang590/JSPatch/wiki/JPBlock-扩展使用文档)

####GCD

使用 `dispatch_after() dispatch_async_main()` `dispatch_sync_main() dispatch_async_global_queue()` 接口调用GCD方法:

```javascript
dispatch_after(1.0, function(){
  // do something
})
dispatch_async_main(function(){
  // do something
})
dispatch_sync_main(function(){
  // do something
})
dispatch_async_global_queue(function(){
  // do something
})
```

####枚举、宏、全局变量

- OC中的枚举 要直接换成 具体值替换 `UIControlEventTouchUpInside` => `1<<6`

  ```objective-c
  [btn addTarget:self action:@selector(handleBtn) forControlEvents:UIControlEventTouchUpInside];
  ```

  ```js
  btn.addTarget_action_forControlEvents(self, "handleBtn", 1<<6);
  ```

- 宏

  Objective-C 里的宏不能直接在 JS 上使用，可以使用全局变量替代

- 全局变量

  在类里定义的 `static` 全局变量无法在 JS 上获取到，若要在 JS 拿到这个变量，需要在 OC 用get方法返回：

  ```objective-c
  static NSString *name;
  @implementation JPTestObject
  + (NSString *)name {
    return name;
  }
  @end
  ```

  ```javascript
  var name = JPTestObject.name() //拿到全局变量值
  ```



###[JSPatch 代码转换器](https://jspatch.com/Tools/convertor)



## 调试

#####在 iOS8 下，JSPatch 支持使用 Safari 自带的调试工具对 JS 脚本进行断点调试

- 开启 Safari 调试菜单：Safari -> 偏好设置 -> 高级 -> 勾选[在菜单栏中显示“开发”菜单]
- 启动APP -> Safari -> 开发 -> 选择你的机器 -> JSContext
- 连接真机调试时，需要打开真机的web检查器：设置 -> Safari -> 高级 -> Web检查器

![JSContext](JSContext.png)

## 实践

[JSPatchDemo]()





















