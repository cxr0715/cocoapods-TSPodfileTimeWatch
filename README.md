# cocoapods-TSPodfileTimeWatch



## 安装：

    $ gem install cocoapods-TSPodfileTimeWatch

可以通过pod install/update --verbose获取每个pod的下载耗时（S），git clone文件大小（M），cache文件大小（M），大小差值（M）。如果大小差值过大则存在优化空间。具体的统计数据请在#{Dir.home}/.AllPodsTimeAndSize.csv中查看。