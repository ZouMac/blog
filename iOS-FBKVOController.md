---
title: FBKVOController源码分析

author: 檀邹

date: 2018-08-22 11:42:50

categories:

- 经验总结

tags: 

- KVO

- 源码分析

---



# 前言

FBKVOController 是 Facebook 开源的接口设计优雅的 KVO 框架。研读源码有助于加深对其框架和模式的理解，将其中的一些代码技巧运用到开发工作中，以提升自身开发水平。

<!-- more --> 



# 一、FBKVOController 简介

KVO (key-Value Observing) 是通过观察者监听指定`keyPath`路径下属性改变而触发响应的开发方案。开发者可以在工程中直接使用 Apple 原生的 KVO，支持多个观察者同时观察同一个`keyPath`属性。然而，Apple 原生 KVO 的使用较为麻烦，需要添加观察者，移除观察者，通知回调，且其回调方法与添加观察者方法过于分散。同时，移除未添加的观察者还会导致程序奔溃，重复添加观察者将造成回调函数执行多次。

FBKVOController 是 FaceBook 开源的简化封装后的 KVO 框架。它对原生 KVO 监听函数进行了封装，使用`block`或`@selector(SEL)`的回调操作，极大的简化了 KVO 调用方式，避免了在程序中处理通知回调函数逻辑散落的到处都是。同时将移除观察者方法巧妙的放到`dealloc`方法中，实现“自释放”。

```objc
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
```



### FBKVOController 使用

```objc
/** 初始化KVOController有两种方式：

 1.创建KVOController同时让self持有KVOCOntroller
 FBKVOController *KVOController = [FBKVOController controllerWithObserver:self];
 self.KVOController = KVOController;
 
 2.使用self.KVOController或self.KVOControllerNonRetaining作为观察者（分类 NSObject+FBKVOController会以懒加载的方式动态的给对象添加KVOController、KVOControllerNonRetaining属性）[推荐]
 
 */

// observe clock对象的 date属性
[self.KVOController observe:clock keyPath:@"date" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew block:^(ClockView *clockView, Clock *clock, NSDictionary *change) {
    
  // block 回调更新 date
  clockView.date = change[NSKeyValueChangeNewKey];

}];

```



# 二、NSHashTable 和 NSMapTable

`NSHashTable`和`NSMapTable`在平时的开发中用到的比较少，`NSHashTable`被设计为可以由于替换`NSMutableSet`的无序集。

- `NSSet / NSMutableSet`持有成员的强引用，通过`hash`和`isEqual:`方法来检测成员的散列值和相等性。

- `NSHashTable`是可变集合

- 可通过传入`NSPointerFunctionsWeakMemory`参数弱引用储存对象，对象被释放后将自动移除

- 储存对象是无序的且不能储存相同的对象

- 在添加对象时可以复制对象后再存放

- `NSHashTable`可以存储任意的指针，通过指针来进行相等性和散列检查。

  

`NSMapTable`是更广泛意义上的`NSMutableDictionary`，它可以处理`key -> obj`式的映射，也可以处理`obj -> obj`的映射（关联数组 map）。

- `NSDictionary / NSMutableDictionary`通过mutableCopy对键值进行拷贝，copy不会进行拷贝，但会使引用计数+1。
- `NSMapTable`是可变的
- 可通过传入`NSPointerFunctionsWeakMemory`参数对持有的`keys`和`values`弱引用，当键或者值当中的一个被释放时，整个就会被移除掉。
- 在添加`value`时对`value`进行复制
- `NSMapTable`可以存储任意的指针，通过指针来进行相等性和散列检查。



# 三、源码分析



## 3.1、FBKVOController 框架结构

- FBKVOController 
  - _FBKVOInfo 
  - _FBKVOSharedController 
  - FBKVOController 

- NSObject+FBKVOController 

`FBKVOController`分为三部分，其中`_FBKVOSharedController`是内部中间层，主要是用于将原生 KVO 的给观察对象添加监听的方式：

```objc
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
```

转换为观察者主动观察被监听对象的方式：

```objc
- (void)observe:(nullable id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(FBKVONotificationBlock)block;
```

`_FBKVOInfo`也是内部类，用于储存 KVO 的处理内容：

```objc
- (instancetype)initWithController:(FBKVOController *)controller
                           keyPath:(NSString *)keyPath
                           options:(NSKeyValueObservingOptions)options
                             block:(nullable FBKVONotificationBlock)block
                            action:(nullable SEL)action
                           context:(nullable void *)context;
```

`FBKVOController`是实现 KVO 的主要类。
`NSObject+FBKVOController`用于提供强引用和弱引用的`FBKVOController`。


## 3.2、FBKVOController



### 初始化 FBKVOController

`FBKVOController`的`observe`对象是用`weak`持有的，对传入的观察者弱引用，以避免循环引用。

```objc
@property (nullable, nonatomic, weak, readonly) id observer;
```

`NSPointerFunctionsOptions`定义了`NSMapTable`中的`key`和`value`的内存管理策略，内存选项决定了内存管理，个性化定义了哈希和相等：

- `NSPointerFunctionsStrongMemory`创建了一个`retain/release`对象的集合，非常像常规的`NSSet`或`NSArray`。 
- `NSPointerFunctionsWeakMemory` 使用等价的`__weak`来存储对象并自动移除被销毁的对象。
- `NSPointerFunctionsCopyIn`在对象被加入到集合前拷贝它们，支持`NSCopying`协议。
- `NSPointerFunctionsObjectPersonality`使用对象的`hash`和`isEqual:`(默认)。=> 值相等
- `NSPointerFunctionsObjectPointerPersonality`对于`isEqual:`和`hash`使用直接的指针比较。=> 指针相等

此处`retainObserved = true` ,  定义了`key`为强引用、指针比较，`value`为强引用、值比较的`NSMapTable`对象`_objectInfosMap`。

```objc
- (instancetype)initWithObserver:(nullable id)observer retainObserved:(BOOL)retainObserved
{
  self = [super init];
  if (nil != self) {
    _observer = observer;
    NSPointerFunctionsOptions keyOptions = retainObserved ? NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality : NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality;
    _objectInfosMap = [[NSMapTable alloc] initWithKeyOptions:keyOptions valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality capacity:0];
    pthread_mutex_init(&_lock, NULL);
  }
  return self;
}
```

最后初始化自旋锁，自旋锁用于避免多个线程同时操作`critical section`。



### 监听对象 keyPath

- 监听对象、属性、回调` block`必须存在。
- 构造`_FBKVOInfo`对象，储存传入的 KVO 参数。
- 监听

```objc
- (void)observe:(nullable id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(FBKVONotificationBlock)block
{
  NSAssert(0 != keyPath.length && NULL != block, @"missing required parameters observe:%@ keyPath:%@ block:%p", object, keyPath, block);
  if (nil == object || 0 == keyPath.length || NULL == block) {
    return;
  }

  // create info
  _FBKVOInfo *info = [[_FBKVOInfo alloc] initWithController:self keyPath:keyPath options:options block:block];

  // observe object with info
  [self _observe:object info:info];
}

```



调用内部监听方法：

- 首先开启自旋锁，防止其他线程操作干扰。
- 根据被观察的对象获取 `infos`，避免对同一个`keyPath`添加多次观察，防止奔溃。
- 如果没有与此次观察相同的`info`，则将`info`添加到`_objectInfosMap`的`infos`中，并注册到中间层`_FBKVOSharedController`中。

```objc
- (void)_observe:(id)object info:(_FBKVOInfo *)info
{
  // lock
  pthread_mutex_lock(&_lock);

  NSMutableSet *infos = [_objectInfosMap objectForKey:object];

  // check for info existence
  _FBKVOInfo *existingInfo = [infos member:info];
  if (nil != existingInfo) {
    // observation info already exists; do not observe it again

    // unlock and return
    pthread_mutex_unlock(&_lock);
    return;
  }

  // lazilly create set of infos
  if (nil == infos) {
    infos = [NSMutableSet set];
    [_objectInfosMap setObject:infos forKey:object];
  }

  // add info and oberve
  [infos addObject:info];

  // unlock prior to callout
  pthread_mutex_unlock(&_lock);

  [[_FBKVOSharedController sharedController] observe:object info:info];
}
```



### 中间层 _FBKVOSharedController 转发处理

`_FBKVOSharedController ` 使用原生 KVO 对传进来的`object`进行观察。

```objc
- (void)observe:(id)object info:(nullable _FBKVOInfo *)info
{
  if (nil == info) {
    return;
  }

  // register info
  pthread_mutex_lock(&_mutex);
  [_infos addObject:info];
  pthread_mutex_unlock(&_mutex);

  // add observer
  [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(void *)info];

  if (info->_state == _FBKVOInfoStateInitial) {
    info->_state = _FBKVOInfoStateObserving;
  } else if (info->_state == _FBKVOInfoStateNotObserving) {
    // this could happen when `NSKeyValueObservingOptionInitial` is one of the NSKeyValueObservingOptions,
    // and the observer is unregistered within the callback block.
    // at this time the object has been registered as an observer (in Foundation KVO),
    // so we can safely unobserve it.
    [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
  }
}

```

并在响应方法中，将原生 KVO 的给观察对象添加监听的方式转换为观察者主动观察被监听对象的方式, 并将监听到的`change`赋值到`block`中进行传递：

```objc
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context
{
  NSAssert(context, @"missing context keyPath:%@ object:%@ change:%@", keyPath, object, change);

  _FBKVOInfo *info;

  {
    // lookup context in registered infos, taking out a strong reference only if it exists
    pthread_mutex_lock(&_mutex);
    info = [_infos member:(__bridge id)context];
    pthread_mutex_unlock(&_mutex);
  }

  if (nil != info) {

    // take strong reference to controller
    FBKVOController *controller = info->_controller;
    if (nil != controller) {

      // take strong reference to observer
      id observer = controller.observer;
      if (nil != observer) {

        // dispatch custom block or action, fall back to default action
        if (info->_block) {
          NSDictionary<NSKeyValueChangeKey, id> *changeWithKeyPath = change;
          // add the keyPath to the change dictionary for clarity when mulitple keyPaths are being observed
          if (keyPath) {
            NSMutableDictionary<NSString *, id> *mChange = [NSMutableDictionary dictionaryWithObject:keyPath forKey:FBKVONotificationKeyPathKey];
            [mChange addEntriesFromDictionary:change];
            changeWithKeyPath = [mChange copy];
          }
          info->_block(observer, object, changeWithKeyPath);
        } else if (info->_action) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
          [observer performSelector:info->_action withObject:change withObject:object];
#pragma clang diagnostic pop
        } else {
          [observer observeValueForKeyPath:keyPath ofObject:object change:change context:info->_context];
        }
      }
    }
  }
}
```



### 循环引用

在以下` block`中使用到 `self`，势必会造成循环引用的问题，但是要给`self.layer`赋值，那就需要加上`@weakify(self)；`。为了解决这个问题， FBKVOController 做了巧妙的处理：初始化时将`observe`传入，并做了`weak`处理，对其弱引用，最后再将`observe`添加到`block`回调中，这样就可以直接在`block`回调中使用`observe`来替代`self`。

```objc
[self.KVOController observe:clock keyPath:@"date" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew block:^(ClockView *clockView, Clock *clock, NSDictionary *change) {
      // update observer with new value
      clockView.layer.date = change[NSKeyValueChangeNewKey];
 }];
```



### 移除监听

`FBKVOController`实现了自释放，`self.KVOController`会随着观察者释放而释放，当`KVOController`释放时，在其`dealloc`方法中移除监听，巧妙的将观察者的`remove`转移到动态属性的`dealloc`函数中。



# 四、小结



### 优点：

- 它对原生KVO监听函数进行了封装，使用`block`或`@selector(SEL)`的回调操作，极大的简化了 KVO 调用方式，避免了在程序中处理通知回调函数逻辑散落的到处都是。<Br>

- 将移除观察者方法巧妙的放到`dealloc`方法中，实现“自释放”。<Br>

  

### 缺点：

- 无法监听自己的属性,会造成循环引用。<Br>



# 参考链接：

[http://www.isaced.com/post-235.html](http://www.isaced.com/post-235.html)<Br>

[FBKVOController](https://github.com/facebook/KVOController)<Br>

[https://nshipster.cn/nshashtable-and-nsmaptable/](https://nshipster.cn/nshashtable-and-nsmaptable/)<Br>

[https://mp.weixin.qq.com/s/ZrJhx8ItmUBco0frxl2NJw](https://mp.weixin.qq.com/s/ZrJhx8ItmUBco0frxl2NJw)<Br>

