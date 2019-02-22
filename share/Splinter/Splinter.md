# python使用splinter实现SDP组件自动化发布



## 背景

- 在ND项目开发中，每码完一个版本的代码或是改完bug都需要发布到SDP上，以便打包测试。
- 发布代码涉及打标签、检查`podfile`与`podspec`一致性（`appfactory`已提供验证方法）、发布等过程。发布流程较为麻烦。
- 开发者可以使用SDP组件自动化发布工具更方便的发布组件。



## 设计思路

使用`python`的 `splinter`库模拟组件发布流程，实现自动化发布：

- 下载Browser驱动（本文使用Chrome）
- 提取`podSpec`文件中的版本号和`homepage`。
- 打开组件标签页面，打上标签。
- 进入SDP对应的组件发布页面进行发布。



## 使用方法

### 一、安装脚本

1. 确保安装了Chrome

2. 确保安装python2.X

3. 确保安装pip

4. 安装SDP工具： pip install SDPPublishTool (   pip install SDPPublishTool-0.0.3-py2-none-any.whl   )

5. 移动执行脚本到根目录： mv  /usr/local/lib/python2.7/site-packages/SDP.*  ~/

### 二、发布命令：

python ~/sdp.py（确保 podspec 文件内 s.homepage 为对应组件 gitlab 地址，且s.version为要发布的版本号）

- userName : gitlab用户名（工号）
- password : 工号密码
- project dir ： 要发布的组件目录
- code-branch(dev or test or release)：发布分支分别对应开发、测试、正式环境
- publish content：发布内容（可为空）




![demo](images/demo.gif)


## 实现

### Splinter

- Splinter 是一个基于python的开源测试工具，可以进行基于浏览器的的自动化操作。
- 可以通过安装特定驱动（Firefox、Chrome）模拟浏览器行为，访问指定的URL。
- 支持模拟鼠标的动作，比如滑动到某个按钮上，焦点离开某个按钮等等。
- 支持模拟键盘的输入操作，对input等控件的输入可以模拟用户的输入。
- 最重要的，splinter的API非常简单，配合官方的文档学习成本几乎是0。
- 支持cookie操作，可以很方便的添加和删除cookie。
- 支持直接运行js或者调用页面的js。
- 支持模拟上传文件。
- 对radio和checkbox有专门的api支持，非常方便。
- 支持快速的获取页面的元素或者判断是否存在文本，用于开发判断页面提示信息是否准确非常方便。

### Splinter 的使用

- 指定浏览器驱动

  ```python
  b = Browser("chrome")
  b.visit('http://www.baidu.com')   
  ```


- 查找页面元素

  ```python
  browser.find_by_css('h1')
  browser.find_by_xpath('//h1')
  browser.find_by_tag('h1')
  browser.find_by_name('name')
  browser.find_by_text('Hello World!')
  browser.find_by_id('firstheader')
  browser.find_by_value('query')

  first_found = browser.find_by_name('name').first
  last_found = browser.find_by_name('name').last
  second_found = browser.find_by_name('name')[1]

  //链接
  links_found = browser.find_link_by_text('Link for Example.com')
  links_found = browser.find_link_by_partial_text('for Example')
  links_found = browser.find_link_by_href('http://example.com')
  links_found = browser.find_link_by_partial_href('example')
  ```


- 填充点击事件

  ```python
  b.fill('username', input_name)
  b.fill('password', input_pwd)
  b.find_by_id('login').click()
  ```



### 实现源码

#### 下载驱动

```python
packagePath = os.path.dirname(os.__file__)
file_path = os.path.join('/', packagePath, 'site-packages/chromedriver')

if not os.path.isfile(file_path):
    logging.info("Downloading chromedriver...")
    # replace with url you need
    url = 'http://npm.taobao.org/mirrors/chromedriver/70.0.3538.16/chromedriver_mac64.zip'

    def down(_save_path, _url):
        try:
            urllib.urlretrieve(_url, _save_path)
        except:
            print '\nError when retrieving the URL:', _save_path

    down(file_path, url)
    logging.info("Download finish") 
```

#### 输入用户信息

- 用户信息数据库存储与读取 （暂未加密）

  ```python
  import sqlite3

  # 建一个数据库
  def create_sql():
      sql = sqlite3.connect("user_data.db")
      sql.execute("CREATE TABLE IF NOT EXISTS \
              Writers(username, password)")
      sql.close()
     
  def get_cursor():

      create_sql()

      conn = sqlite3.connect("user_data.db")

      return conn.cursor()

  def insert_user(username, pwd):
      if (fetch_username() is None) | (fetch_pwd is None):
      sql = sqlite3.connect("user_data.db")
      sql.execute("insert into Writers(username,password) values(?,?)",
                (username, pwd))
      sql.commit()
      # print "添加成功"
      sql.close()
      
  def fetch_username():

        conn = sqlite3.connect("user_data.db")

        c = conn.cursor()

        return c.execute("select username from Writers").fetchone()

    def fetch_pwd():

        conn = sqlite3.connect("user_data.db")

        c = conn.cursor()

        return c.execute("select password from Writers").fetchone()
  def fetch_username():

        conn = sqlite3.connect("user_data.db")

        c = conn.cursor()

        return c.execute("select username from Writers").fetchone()

    def fetch_pwd():

        conn = sqlite3.connect("user_data.db")

        c = conn.cursor()

        return c.execute("select password from Writers").fetchone()

  ```


  

- 输入用户信息、发布环境、发布内容

  ```python
  from dataBase.dataBase import get_cursor
  from dataBase.dataBase import insert_user
  from dataBase.dataBase import fetch_pwd
  from dataBase.dataBase import fetch_username

  # 用户信息
  c = get_cursor()
  username = fetch_username()
  pwd = fetch_pwd()

  if (username is None) | (pwd is None):
      # 输入信息
      username = raw_input('please input userName:')
      pwd = getpass.getpass('please input password:')
      
  env = raw_input('please input code-branch(dev or test or release):')
  detail = raw_input('please input publish content:')
  ```



####  检查获取组件的podspec

```python
# 判断目录路径是否存在
def file_name(file_dir):
    for roots, dirs, files in os.walk(file_dir):

        for child_file in files:
            if os.path.splitext(child_file)[1] == '.podspec':
                return os.path.join(roots, child_file)


filename = file_name(dir)

while filename is None:
    print 'invalid path'
    dir = raw_input('please input project dir:')
    filename = file_name(dir)

print(filename)
```

- 提取组件名、版本号（标签）、homePage

  ```python
  f = open(filename, 'r')

  lines = f.readlines()
  # 版本号
  versionNo = ''
  # 组件名
  component_name = ''

  for line in lines:
      if ("s.name" in line) & (line.find("{") == -1):
          tempList = line.split('"')
          component_name = tempList[1]
          print component_name

      if ("s.version" in line) & (line.find("{") == -1):
          tempList = line.split('"')
          for str2 in tempList:
              if ("." in str2) & (str2.find('=') == -1):
                  versionNo = str2
                  print versionNo

      if "s.homepage" in line:
          tempList = line.split('"')
          for str1 in tempList:
              if "http://" in str1:
                  url = str1
                  print url
               
  f.close()
  ```


  ####  

打Tag

  ```python
# 版本标签
b = Browser("chrome")

def add_version_tag(input_name, input_pwd):
    b.visit(url + '/tags/new')
    time.sleep(1)
    b.fill('username', input_name)
    b.fill('password', input_pwd)
    b.find_by_name('remember_me').click()
    b.find_by_name('button').click()
    if b.find_by_id('tag_name').__len__() == 0:
        print 'invalid userName or password'
        input_name = raw_input('please input userName:')
        input_pwd = getpass.getpass('please input password:')
        add_version_tag(input_name, input_pwd)
        print 'login fail'
        return
    else:
        insert_user(input_name, input_pwd)
        return 1


login_success = add_version_tag(username, pwd)

b.fill('tag_name', versionNo)
b.find_by_name('button').click()
  ```

#### 发布

```python
# 发布
b.visit('http://sdp.nd/main.html')
time.sleep(0.5)
b.find_by_id('login').click()

username = fetch_username()
pwd = fetch_pwd()

b.find_by_id('object_id').fill(username)
b.find_by_id('password').fill(pwd)
b.find_by_name('keep_pwd')
b.find_by_id('confirmLogin').click()
time.sleep(1)
b.visit('http://sdp.nd/main.html')

b.find_by_id('appSearchTxt').fill(component_name)


while b.find_link_by_partial_href('/modules/mobileComponent/detail.html?appId') is []:
    print '.'

b.find_link_by_partial_href('/modules/mobileComponent/detail.html?appId').click()


# 选择分支
time.sleep(0.5)
b.find_by_xpath('/html/body/div[4]/a[2]').first.click()

b.find_by_xpath('//*[@id="appDeatil"]/div[1]/span[2]/span').first.click()
b.find_by_id(env_id).first.find_by_tag('a').click()
b.find_by_id('publish').first.click()

# 版本号
b.find_by_id('version').fill(versionNo)
b.find_by_id('versionDesc').fill(detail)

# b.find_by_xpath('//*[@id="gitlist"]/div').first.click()
# b.find_by_id('publishConfirm').click()
```



### python打包发布pip

- 注册PyPi

- setup.py

  ```python
  #!/usr/bin/env python
  #-*- coding:utf-8 -*-

  #############################################
  # File Name: setup.py
  # Author: tanzou
  # Mail: 'tanzou34@gmail.com'
  # Created Time:  2018-10-10 19:17:34
  #############################################
   from setuptools import setup, find_packages

    setup(

          name='SDPPublishTool',

          version = "0.0.4",

          keywords = ("pip", "SDP"),

          zip_safe = False,
          
           description = "SDP publish",
          long_description = "SDP publish for NetDragon",
          license = "MIT Licence",
      
          url = "https://github.com/ZouMac/SDPPublishTool",
          author = "tanzou",
          author_email = "tanzou34@gmail.com",
      
          packages = find_packages(),
          include_package_data = True,
          platforms = "any",
          install_requires = ["splinter", "getpass2"]
        }
  ```


- 打包上传

```python
python setup.py sdist     #会生成SDPPublishTool-0.0.3.tar.gz文件用于上传到PyPi上

twine upload dist/magetool-0.1.0.tar.gz  #如果报权限问题，可以在前面加上python -m
```



### 参考文献















