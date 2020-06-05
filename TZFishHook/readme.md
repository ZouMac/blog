# fishhook源码分析



## 一、fishhook是什么

在使用OC开发











## 二、fishhook能用来做什么









## 三、fishhook使用

### 3.1 创建行数指针用于保存原函数

```objc
static void (*orig_nslog)(NSString *format, ...);
```

### 3.2 添加替换行数实现

```
void my_NSLog(NSString *format, ...) {
    orig_nslog(@"has hook NSLog %@ \n", format);
}
```

### 3.3 hook

- hook前调用一次NSLog

  ```objc
  NSLog(@"before hook"); 
  ```

  输出：

  ```
  2020-06-05 17:48:38.548500+0800 TZFishHook[90088:423227] before hook
  ```

- hook

  ```objc
  /**
   * A structure representing a particular intended rebinding from a symbol
   * name to its replacement
  struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
  };
  */
  struct rebinding logBind;
  logBind.name = "NSLog"; // 原函数名
  logBind.replacement = my_NSLog; // 替换的函数
  logBind.replaced = (void *)&orig_nslog; // 原函数
  
  /**
  FISHHOOK_VISIBILITY
  int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);
  */
  struct rebinding rebs[] = {logBind};
  rebind_symbols(rebs, 1);
  ```

  

- hook后再调用一次NSLog

  此时调用NSLog就会去执行`my_NSLog`

  ```
  2020-06-05 17:48:38.552269+0800 TZFishHook[90088:423227] after hook: nslog has been hook 
  ```



## 四、fishhook源码分析

### 4.1 fishhook原理

fishhook是通过加载mach-o文件

![Visual explanation](images/fishhook.png)

