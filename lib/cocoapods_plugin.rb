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
$pluginIsVerbose = false
$gitSize = 0
$gitAllSize = 0
$cloneTime = 0
$cloneAllTime = 0
if ARGV.include?("--verbose")
  $pluginIsVerbose = true
end

module CocoapodsTSPodfileTimeWatch

  Pod::HooksManager.register("cocoapods-TSPodfileTimeWatch", :post_install) do |context|
    puts "\e[31mCocoapodsTSPodfileTimeWatch gitAllSize: #{$gitAllSize}M\e[0m"
    puts "\e[31mCocoapodsTSPodfileTimeWatch cloneAllTime: #{$cloneAllTime}S\e[0m"
    if $pluginIsVerbose == true
      puts "\e[31m 具体的统计数据请在#{Dir.home}/.AllPodsTimeAndSize.csv中查看"
    end
  end

  class Pod::Downloader::Cache
    # 使用方法别名hook copy_and_clean方法
    alias :origin_copy_and_clean :copy_and_clean
    def copy_and_clean(source, destination, spec)
      # 执行之前的拷贝到cache并且清除git clone临时目录的方法
      origin_copy_and_clean(source, destination, spec)
      # 如果是--verbose，则输出详细信息，生成csv
      if $pluginIsVerbose == true
        verboseCopy_and_clean(source, destination, spec)
      end
    end

    # --verbose输出详细信息，生成在home路劲下AllPodsTimeAndSize.csv的隐藏文件
    def verboseCopy_and_clean(source, destination, spec)
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
        CSV.open("#{Dir.home}/.AllPodsTimeAndSize.csv", "ab") do |csv|
          csv << [spec.name, $cloneTime, $gitSize, dirSum, diffSize]
        end
        # 换行
        puts
      rescue => exception
        # 输出拷贝清除方法异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch verboseCopy_and_clean error: #{exception}\e[0m"
      end
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
      
      # 如果不是--verbose，只输出总耗时，总下载大小
      # 捕获一下异常，不会因为plugin的原因导致pod失败
      begin
        # 获取clone执行后时间点
        time2 = Time.new
        # 获取时间差
        time = time2 - time1
        # 赋值一个给全局变量，之后时间统计要用到
        $cloneTime = time
        # 赋值一个给全局变量，之后时间统计要用到
        $cloneAllTime = $cloneAllTime + time
        # 获取git clone下载的文件路径
        source = target_path.to_s
        # 计算git clone下载的文件大小，单位为M
        dirSum = Dir.size(source)/1000.0/1000.0
        # 赋值给一个全局变量，之后输出会用到
        $gitAllSize = $gitAllSize + dirSum
        # 如果是--verbose，则输出详细信息，生成csv
        if $pluginIsVerbose == true
          verboseClone(force_head, shallow_clone, time, dirSum)
        end
      rescue => exception
        # 标红输出git clone hook异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch clone error: #{exception}\e[0m"
      end

    end

    # --verbose输出每个库的下载耗时
    def verboseClone(force_head, shallow_clone, time, dirSum)
      # 这里只能根据url获取到pod名称的开始index
      start = url.rindex("/") + 1
      # 获取pod名称
      podName = url[start, url.length]
      # 标红输出git clone耗时
      puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone time: #{time}\e[0m"
      # 赋值给一个全局变量，之后输出会用到
      $gitSize = dirSum
      # 标红输出git clone下载文件大小
      puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone allsize: "+"#{dirSum}"+"M\e[0m"
    end
  end
end