require 'cocoapods-TSPodfileTimeWatch/command'
require 'csv'
class Dir
  def self.size(dir)
    sum = 0
    Dir.foreach(dir) do |entry|
      begin
        next if entry =~ /^\./ && entry != '.git'
        next if entry == "lfs" # 不统计在lfs文件夹下的资源，git clone下载的是lfs内的资源，之后copy到真正目录下，导致大小统计了两次，所以这里不统计lfs目录下的资源
        path = File.join(dir, entry)
        FileTest.directory?(path) ? sum += Dir.size(path) : sum += File.size(path)  
      rescue => exception
        puts "\e[31mCocoapodsTSPodfileTimeWatch Dir.size error: #{exception}\e[0m"
        next
        retry
      end
    end
    sum
  end
end
$currentPodName = ""
$gitSize = 0
$cloneTime = 0
module CocoapodsTSPodfileTimeWatch
  class Pod::Downloader::Cache
    # 使用方法别名hook copy_and_clean方法
    alias :origin_copy_and_clean :copy_and_clean
    def copy_and_clean(source, destination, spec)
      # 执行之前的拷贝到cache并且清除git clone临时目录的方法
      origin_copy_and_clean(source, destination, spec)
      # 如果拷贝清除方法的pod名称与之前git clone记录下来的名称相同，则执行统计
      if $currentPodName.include? spec.name
        begin
          # 计算拷贝到的目录下所有文件总大小，单位为M
          dirSum = Dir.size(destination.to_s)/1000.0/1000.0
          # 标红输出cache文件大小，单位为M
          puts "\e[31mCocoapodsTSPodfileTimeWatch cachesize #{spec.name}: "+"#{dirSum}"+"M\e[0m"
          # 计算git clone大小和cache文件大小的差值，如果差值过大，则有优化空间
          diffSize = $gitSize - dirSum
          # 标红输出差值
          puts "\e[31mCocoapodsTSPodfileTimeWatch diffSize = #{diffSize}\e[0m"
          # 统计到csv中
          CSV.open("#{Dir.home}/Desktop/AllPodsTimeAndSize.csv", "ab") do |csv|
            csv << [spec.name, $cloneTime, $gitSize, dirSum, diffSize]
          end
          # 换行
          puts
        rescue => exception
          # 输出拷贝清除方法异常
          puts "\e[31mCocoapodsTSPodfileTimeWatch copy_and_clean error: #{exception}\e[0m"
        end
      end
      $currentPodName = ""
      $gitSize = 0
    end
  end

  class Pod::Downloader::Git
    # 使用方法别名hook clone方法
    alias :origin_clone :clone
    def clone(force_head = false, shallow_clone = true)
      # 获取clone执行前时间点
      time1 = Time.new

      # 执行之前的clone方法
      origin_clone(force_head, shallow_clone)

      # 捕获一下异常，不会因为plugin的原因导致pod失败
      begin
        # 获取clone执行后时间点
        time2 = Time.now

        # 获取时间差
        time = time2 - time1

        # 赋值一个给全局变量，之后时间统计要用到
        $cloneTime = time

        # 这里只能根据url获取到pod名称的开始index
        start = url.rindex("/") + 1
        # 获取pod名称
        podName = url[start, url.length]
        # 赋值给一个全局变量，之后输出会用到
        $currentPodName = podName
        # 标红输出git clone耗时
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone time: #{time}\e[0m"

        # 获取git clone下载的文件路径
        source = target_path.to_s
        # 计算git clone下载的文件大小，单位为M
        dirSum = Dir.size(source)/1000.0/1000.0
        # 赋值给一个全局变量，之后输出会用到
        $gitSize = dirSum

        # 标红输出git clone下载文件大小
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone allsize: "+"#{dirSum}"+"M\e[0m"
      rescue => exception
        # 标红输出git clone hook异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch clone error: #{exception}\e[0m"
      end
      
    end
  end
end