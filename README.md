# cocoapods-TSPodfileTimeWatch



## 统计每个pod库下载耗时插件
[![rnhmct.png](https://s3.ax1x.com/2020/12/14/rnhmct.png)](https://imgchr.com/i/rnhmct)

## 安装：

使用cocoapods plugin的方式实现

```bash
$ gem install cocoapods-TSPodfileTimeWatch
```

目前版本0.0.6（加入CDN耗时统计）--2020.12.14

## 使用方法

1. gem install cocoapods-TSPodfileTimeWatch（安装cocoapods-TSPodfileTimeWatch）
2. 删除pods文件夹（为了统计耗时，所以要先删除pods文件夹）
3. 删除podfile.lock文件（为了统计耗时，所以要先删除podfile.lock文件）
4. 删除pod缓存（pod cache clean --all，为了统计耗时，所以要先删除缓存）
5. 在podfile起始加入：

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

6. 执行pod update --verbose（或者是pod install --verbose，但是一定要加--verbose，只有加了--verbose才会输出csv以及详细下载耗时信息，并且会在每个库下载结束后输出对应信息）

   git方式：

   [![rn4bi4.png](https://s3.ax1x.com/2020/12/14/rn4bi4.png)](https://imgchr.com/i/rn4bi4)

   CDN方式：

   [![rn5pdO.png](https://s3.ax1x.com/2020/12/14/rn5pdO.png)](https://imgchr.com/i/rn5pdO)

7. pod结束后会在pods文件夹下生成AllPodsTimeAndSize.csv文件，用来记录所有pod下载耗时情况。（之前的pod install/update指令，无论加不加--verbose，都会在最后输出这次pod下载数据的信息）

   [![rn5tmV.png](https://s3.ax1x.com/2020/12/14/rn5tmV.png)](https://imgchr.com/i/rn5tmV)

8. 如果git clone文件大小和cache文件大的差值越大，说明下载的多余文件越多，则存在可优化空间。

9. 可以通过尝试把podfile中使用git commit集成的，修改为使用git tag集成的方式，减少git clone下载内容。也可以尝试把之前git方式下载的库，修改为CDN方式下载（需要自建CDN服务器），下载压缩包会使下载的资源小很多，速度进而加快很多。

10. 如果要卸载，gem uninstall cocoapods-TSPodfileTimeWatch
