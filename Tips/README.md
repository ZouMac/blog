# Tips 
**踩坑笔记 - 记录开发中碰到的一些问题，以防日后继续踩坑**

:desktop_computer: :horse: :man_farmer: :knife: :bug:




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

​
​
​### 图片解压缩方案
​
​加载图片主要有以下三种方法：
​
​```objc
​+ (nullable UIImage *)imageNamed:(NSString *)name;//同时会加载图片到内存中
​+ (nullable UIImage *)imageWithContentsOfFile:(NSString *)path;//不会缓存到内存中，适合较大的不常用的图片
​+ (nullable UIImage *)imageWithData:(NSData *)data;//不缓存，适合于加载网络图片
​```
​
​**iOS加载图片流程：**
​
​当使用`imageWithContentsOfFile`从地址中获取图片时，图片并没有解压缩，此时的图片是无法显示的，在渲染到屏幕之前，必须先要得到图片的原始像素数据（位图）。
​
​将生成的image赋值给UIImageView，此时`CoreAnimation（CA）`的事务`（CATrasaction）`会捕获到`UIImageView`图层树的变化，在主线程的下一个`runloop`到来时，`CA`会提交这个事务:
​
​1. 分配内存缓冲区用于管理文件`IO`和解压缩操作。
​2. 从磁盘中读取图片数据到内存中。
​3. 在**主线程**中将图片数据解码成未压缩的位图形式（**耗时操作**）
​4. 最后将位图渲染到`UIImageView `的图层上
​
​在以上操作中将图片解码成位图是一个在主线程中的耗时操作，因此很有必要将它放到子线程中提前解码成位图，再在主线程中渲染图片。**而强制解压缩的原理就是对图片进行重新绘制，得到一张新的解压缩后的位图。**
​
​**SDWebImage图片解压缩**
​
​SDWebImage在从磁盘获取图片数据时，会根据图片是否包含Alpha通道以及是否图片存储时是否被缩小（iOS缓存操作60M的图片时，会缩小图片再进行缓存`SDImageCacheScaleDownLargeImages`）进行解压缩。
​
​```objc
​- (nullable UIImage *)sd_decompressedImageWithImage:(nullable UIImage *)image {
​if (![[self class] shouldDecodeImage:image]) {
​return image;
​}
​
​// autorelease the bitmap context and all vars to help system to free memory when there are memory warning.
​// on iOS7, do not forget to call [[SDImageCache sharedImageCache] clearMemory];
​@autoreleasepool{//自动释放池，释放变量
​
​CGImageRef imageRef = image.CGImage;
​// device color space
​CGColorSpaceRef colorspaceRef = SDCGColorSpaceGetDeviceRGB();//色域
​BOOL hasAlpha = SDCGImageRefContainsAlpha(imageRef);
​// iOS display alpha info (BRGA8888/BGRX8888)
​CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;//kCGBitmapByteOrder32Little iPhone是小端模式，数据以32位位单位
​//位图布局信息 有Alpha通道时，将A通道乘以RGB，无Alpha通道时，跳过
​bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
​
​size_t width = CGImageGetWidth(imageRef);
​size_t height = CGImageGetHeight(imageRef);
​
​// kCGImageAlphaNone is not supported in CGBitmapContextCreate.
​// Since the original image here has no alpha info, use kCGImageAlphaNoneSkipLast
​// to create bitmap graphics contexts without alpha info.
​CGContextRef context = CGBitmapContextCreate(NULL,//data系统会自动分配和是否内存
​width,//位图宽高，即像素数量
​height,
​kBitsPerComponent,//像素的每个颜色分量使用的 bit 数,
​0,//位图的每一行使用的字节数=》大小至少为4 * width，指定0时系统不仅会为我们自动计算，而且还会进行 cache line alignment 的优化。优化过程不了解。。。这么用就好
​colorspaceRef,//色域 使用RGB
​bitmapInfo//位图布局信息);
​if (context == NULL) {
​return image;
​}
​
​// Draw the image into the context and retrieve the new bitmap image without alpha
​CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
​CGImageRef imageRefWithoutAlpha = CGBitmapContextCreateImage(context);
​UIImage *imageWithoutAlpha = [[UIImage alloc] initWithCGImage:imageRefWithoutAlpha scale:image.scale orientation:image.imageOrientation];
​CGContextRelease(context);
​CGImageRelease(imageRefWithoutAlpha);
​
​return imageWithoutAlpha;//返回生成的位图
​}
​}
​```
​
​
​

