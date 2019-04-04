# 开发模式学习

## 原型模式

- 原型模式申明了复制自身的接口，通过复制创建实例对象。

- 接口协议中可以定义属性

```objc
@protocol TZMark <NSObject>

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign, readonly) NSUInteger count;
@property (nonatomic, weak, readonly) id<TZMark> lastChild;


- (id)copy;
- (void)addMark:(id <TZMark>)mark;
- (void)removeMark:(id <TZMark>)mark;
- (id <TZMark>)childMarkAtIndex:(NSUInteger)index;

@end
```

但是在实现接口的类中，需要实现其setter和getter方法（协议不会自动给继承该协议的类添加合成方法）。

使用`@synthesize`

```objc
@synthesize location;
```

或是动态绑定`@dynamic`：告诉编译器,属性的setter与getter方法由用户自己实现，不自动生成。

```objc
@synthesize location;

#pragma mark - setter
- (void)setLocation:(CGPoint)location {}


#pragma mark -  getter
- (CGPoint)location {
    if ([self.childrenList count] > 0) {
        return [_childrenList objectAtIndex:0].location;
    } else {
        return CGPointZero;
    }
}
```



- 深浅拷贝与NSCopying协议

  copy `NS对象`时需要实现`NSCopying`的`copyWithZone`方法

```obj
- (id)copyWithZone:(NSZone *)zone {
    TZStorke *strokeCopy = [[[self class] allocWithZone:zone] init];
    [strokeCopy setColor:[UIColor colorWithCGColor:[color CGColor]]];
    [strokeCopy setSize:size];
    
    for (id <TZMark> child in _childrenList) {
        id <TZMark> childCopy = [child copy];
        [strokeCopy addMark:childCopy];
    }
    return strokeCopy;
}
```



## 工厂模式

