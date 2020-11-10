# cocoapods-TSPodfileTimeWatch



## 统计每个pod库下载耗时插件
[![Bb8zIx.png](https://s1.ax1x.com/2020/11/09/Bb8zIx.png)](https://imgchr.com/i/Bb8zIx)

## 安装：

使用cocoapods plugin的方式实现

    $ gem install cocoapods-TSPodfileTimeWatch

## 使用方法

1.gem install cocoapods-TSPodfileTimeWatch（安装cocoapods-TSPodfileTimeWatch）

2.删除pods文件夹

3.删除podfile.lock文件

4.删除pod缓存（pod cache clean --all）

5.在podfile起始加入：

```ruby
# 在这里判断是否启动插件，再加个异常保护
begin
  if system "gem list | grep \"cocoapods-TSPodfileTimeWatch\""
    # 判断是否有装cocoapods-TSPodfileTimeWatch插件
    plugin "cocoapods-TSPodfileTimeWatch"
  end
  # 其他plugin...
end
```

6.执行pod update --verbose（或者是pod install --verbose，但是一定要加--verbose，只有加了--verbose才会输出csv以及详细下载耗时信息）

7.pod结束后会在pods文件夹下生成AllPodsTimeAndSize.csv文件，用来记录所有pod下载耗时情况

8.如果git clone文件大小和cache文件大的差值越大，说明下载的多余文件越多，则存在可优化空间。

9.可以通过尝试把podfile中使用git commit集成的，修改为使用git tag集成的方式，减少git clone下载内容