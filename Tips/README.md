# Tips
开发中遇到的问题


## 2019.3

### 微信小程序camera组件录像30s偶发超时问题

在初始化`camera`上下文时，若要多次进行录像操作，必须制定`id`（文档中没有相关说明）。

不指定`id`,在进行多次录制时，会初始化多个上下文，`stop`操作会造成上一次的录制未停止，导致录制超时。

```objc
wx.createCameraContext('myCamera')
```


### 保证当前是主线程的正确姿势

之前在开发中刷新UI时回到主线程一般都是使用：

```objc
if ([NSThread isMainThread]) {
	block();
} else {
	dispatch_async(dispatch_get_main_queue(), block);
}
```

但是在一些场合需要判断的是**如果在主线程执行非主队列调度的API，而这个API需要检查是否是在主队列上调度，那么将会出现问题。**也就是说需要判断的是**主队列**而不是**主线程**。

更安全的方法：

```objc
dispatch_main_async_safe(block) {
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);\
    }
}
```

解析：

`dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)`：每个`queue`都有一个唯一的`label`，这是获取当前队列的`label`。

`dispatch_queue_get_label(dispatch_get_main_queue()`：获取主队列的`label`。

`strcmp（A, B）== 0`: 判断当前队列是否是主队列。

**这个方法将判断是否在主线程执行改为了是否在主队列执行，因为主队列无论是同步还是异步，都不会开辟新的线程，即都是在主线程执行。=> 主队列调度的任务一定在主线程执行，而主线程执行的任务则不一定是在主队列调度**



### NSMapTable 的使用

在翻看`SDWebImage`源码时，无意中发现原本的`imageCache`从`NSCache`为了`NSMapTable`。正好复习一下`NSMapTable`。

`NSMapTable`一般都是和`NSDictionary`一起讲解的。`NSDictionary`一般适用于`key` => `object`，且`key`和`object`都只能是`OC`对象，由于`NSDictionary`是通过`key`来索引`object`的，`key`一旦被修改就无法找到`object`了，所以`NSDictionary`始终会复制`key`到自己的私有空间（`key`必须支持 `NSCopying` 协议）。因此一般使用简单高效的对象来作为key（例如`NSString`、`NSNumber`），以至于复制的时候不会对 CPU 和内存造成负担。

如果要做对象到对象的映射，我们可以使用**`NSMapTable`**：

```objc
- (instancetype)initWithKeyPointerFunctions:(NSPointerFunctions *)keyFunctions valuePointerFunctions:(NSPointerFunctions *)valueFunctions capacity:(NSUInteger)initialCapacity;
```

- `NSMapTableStrongMemory`: 强引用
- `NSMapTableWeakMemory`: 弱引用
- `NSMapTableObjectPointerPersonality` :将对象添加到集合中时是否调用对象上的 `isEqualTo：` 和 `hash` 方法
- `NSMapTableCopyIn`:  复制一份，可以设置`key`为该属性 => `NSDictionary`