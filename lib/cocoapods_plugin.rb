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
        puts "\e[31mCocoapodsTSPodfileTimeWatch Dir.size error(已捕获): #{exception}\e[0m"
        next
        retry
      end
    end
    sum
  end
end
$pluginIsVerbose = false
$pluginCurrentTarget = ""
$pluginCurrentPodName = ""
$pluginCurrentZipSize = 0
$pluginCurrentZipAllSize = 0
$gitSize = 0
$gitAllSize = 0
$cloneTime = 0
$cloneAllTime = 0
$downloadTime = 0
$downloadAllTime = 0
$cdnDownloadTime = 0
$cdnDownloadAllTime = 0
$cdnUnZipTime = 0
$cdnUnZipAllTime = 0
if ARGV.include?("--verbose")
  $pluginIsVerbose = true
end

module CocoapodsTSPodfileTimeWatch

  Pod::HooksManager.register("cocoapods-TSPodfileTimeWatch", :pre_install) do |context|
    begin
      if $pluginIsVerbose == true
        # home路径下是否存在.AllPodsTimeAndSize.csv的隐藏文件
        if File.exist?("#{Dir.home}/.AllPodsTimeAndSize.csv")
          # 如果存在则先删除，每次都生成新的csv文件
          File.delete("#{Dir.home}/.AllPodsTimeAndSize.csv")
        end
        # 统计到csv中
        CSV.open("#{Dir.home}/.AllPodsTimeAndSize.csv", "ab:utf-8") do |csv|
          csv << ["\xEF\xBB\xBF名称", "下载耗时（S）", "下载文件大小（M）", "cache文件大小（M）", "大小差值(Git专用)", "CDN/Git", "CDN下载耗时", "CDN解压耗时"]
        end
      end
    rescue => exception
      
    end
  end
  Pod::HooksManager.register("cocoapods-TSPodfileTimeWatch", :post_install) do |context|
    begin
      puts "\e[31mCocoapodsTSPodfileTimeWatch GitCloneAllSize: #{$gitAllSize} M\e[0m"
      puts "\e[31mCocoapodsTSPodfileTimeWatch GitCloneAllTime: #{$cloneAllTime} S\e[0m"
      puts "\e[31mCocoapodsTSPodfileTimeWatch CDNDownloadAllSize: #{$pluginCurrentZipAllSize} M\e[0m"
      puts "\e[31mCocoapodsTSPodfileTimeWatch CDNAllTime: #{$downloadAllTime} S\e[0m"
      puts "\e[31mCocoapodsTSPodfileTimeWatch CDNDownloadAllTime: #{$cdnDownloadAllTime} S\e[0m"
      puts "\e[31mCocoapodsTSPodfileTimeWatch CDNUnzipAllTime: #{$cdnUnZipAllTime} S\e[0m"
      # 如果是--verbose模式且$gitAllSize与$cloneAllTime（不为0表示有下载pod）
      if $pluginIsVerbose == true && $gitAllSize != 0 && $cloneAllTime != 0 && $pluginCurrentZipAllSize != 0 && $downloadAllTime != 0
        File.rename "#{Dir.home}/.AllPodsTimeAndSize.csv", "#{context.sandbox_root}/AllPodsTimeAndSize.csv"
        puts "\e[31m具体的统计数据请在#{context.sandbox_root}/AllPodsTimeAndSize.csv中查看\e[0m"
      end
    rescue => exception
      # 如果没有下载则#{Dir.home}/.AllPodsTimeAndSize.csv文件不会生成，产生异常
      puts "\e[31mCocoapodsTSPodfileTimeWatch post_install error(已捕获): #{exception}\e[0m"
    end
  end

  class Pod::Downloader::Cache
    # 使用方法别名hook copy_and_clean方法
    alias :origin_copy_and_clean :copy_and_clean
    def copy_and_clean(source, destination, spec)
      time1 = Time.new
      # 执行之前的拷贝到cache并且清除git clone临时目录的方法
      origin_copy_and_clean(source, destination, spec)
      time2 = Time.new
      # 获取时间差
      time = time2 - time1
      puts "\e[31mCocoapodsTSPodfileTimeWatch #{spec.name} copy_and_clean time: #{time}"+" S\e[0m"
      # 如果是--verbose，则输出详细信息，生成csv
      if $pluginIsVerbose == true
        verboseCopy_and_clean(source, destination, spec)
      end
    end

    # --verbose输出详细信息，生成在home路径下.AllPodsTimeAndSize.csv的隐藏文件
    def verboseCopy_and_clean(source, destination, spec)
      begin
        # 计算拷贝到的目录下所有文件总大小，单位为M
        dirSum = Dir.size(destination.to_s)/1000.0/1000.0
        # 标红输出cache文件大小，单位为M
        puts "\e[31mCocoapodsTSPodfileTimeWatch cachesize #{spec.name}: "+"#{dirSum}"+" M\e[0m"
        # 如果相等则为CDN的下载方式
        if $gitSize == 0
          # CDN的下载方式
          CSV.open("#{Dir.home}/.AllPodsTimeAndSize.csv", "a+") do |csv|
            csv << [spec.name, $downloadTime, $pluginCurrentZipSize, dirSum, "CDN不统计此项", "CDN", $cdnDownloadTime, $cdnUnZipTime]
          end
        else
          # git的下载方式
          # 计算git clone大小和cache文件大小的差值，如果差值过大，则有优化空间
          diffSize = $gitSize - dirSum
          # 标红输出差值
          puts "\e[31mCocoapodsTSPodfileTimeWatch diffSize = #{diffSize}"+"M \e[0m"
          CSV.open("#{Dir.home}/.AllPodsTimeAndSize.csv", "a+") do |csv|
            csv << [spec.name, $cloneTime, $gitSize, dirSum, diffSize, "Git", "Git不统计此项", "Git不统计此项"]
          end
        end
        
        # 换行
        puts

      rescue => exception
        # 输出拷贝清除方法异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch verboseCopy_and_clean error(已捕获): #{exception}\e[0m"
      end
      $gitSize = 0
    end
  end


  class Pod::Downloader::Cache

    alias :origin_download :download

    def download(request, target)
      # 获取downloader下载的文件路径
      source = target.to_s
      # 赋值当前正在下载的文件路径给全局变量，为了解压zip的时候做判断
      $pluginCurrentTarget = source
      # 赋值当前正在下载的pod名称给全局变量，为了解压zip的时候做输出
      $pluginCurrentPodName = request.name.to_s
      # 获取clone执行前时间点
      time1 = Time.new
      # 执行之前的download_source方法，接收该方法的返回值
      result, podspecs = origin_download(request, target)

      # 如果不是--verbose，只输出总耗时，总下载大小
      # 捕获一下异常，不会因为plugin的原因导致pod失败
      begin
        # 获取clone执行后时间点
        time2 = Time.new
        # 获取时间差
        time = time2 - time1
        if request.params["git".to_sym]
          # 说明是git方式
          # 赋值一个给全局变量，之后时间统计要用到
          $cloneTime = time
          # 赋值一个给全局变量，之后时间统计要用到
          $cloneAllTime = $cloneAllTime + time
          # 计算downloader下载的文件大小，单位为M
          dirSum = Dir.size(source)/1000.0/1000.0
          # 赋值给一个全局变量，之后输出会用到
          $gitAllSize = $gitAllSize + dirSum
        else
          # 说明是CDN方式
          # 赋值一个给全局变量，之后时间统计要用到
          $downloadTime = time
          # 赋值一个给全局变量，之后时间统计要用到
          $downloadAllTime = $downloadAllTime + time
          # 赋值给一个全局变量，之后输出会用到
          $cdnDownloadAllTime = $cdnDownloadAllTime + $cdnDownloadTime
          # 赋值给一个全局变量，之后输出会用到
          $cdnUnZipAllTime = $cdnUnZipAllTime + $cdnUnZipTime
          # 赋值给一个全局变量，之后输出会用到
          $pluginCurrentZipAllSize = $pluginCurrentZipAllSize + $pluginCurrentZipSize
        end
        
        # 如果是--verbose，则输出详细信息，生成csv
        if $pluginIsVerbose == true
          verboseDownload(request, time, dirSum)
        end
        # 返回值
        [result, podspecs]
      rescue => exception
        # 标红输出git clone hook异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch download error(已捕获): #{exception}\e[0m"
      end
    end

    def verboseDownload(request, time, dirSum)
      if request.params["git".to_sym]
        # 说明是git方式
        # 标红输出git clone耗时
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} clone time: #{time}"+" S\e[0m"
        # 赋值给一个全局变量，之后输出会用到
        $gitSize = dirSum
        # 标红输出git clone下载文件大小
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} clone allsize: "+"#{dirSum}"+" M\e[0m"
      else
        # 说明是CDN方式
        # 标红输出CDN 下载耗时
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} CDN download time: #{$cdnDownloadTime}"+" S\e[0m"
        # 标红输出CDN 解压耗时
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} CDN unzip time: #{$cdnUnZipTime}"+" S\e[0m"
        # 标红输出CDN 总耗时
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} CDN All time: #{$downloadTime}"+" S\e[0m"
        # 标红输出CDN clone下载文件大小
        puts "\e[31mCocoapodsTSPodfileTimeWatch #{request.name.to_s} CDN zipSize: "+"#{$pluginCurrentZipSize}"+" M\e[0m"
      end
      
    end

  end

  class Pod::Downloader::Http
    # 使用方法别名hook解压方法，获取解压之前的文件大小
    alias :origin_download_file :download_file
    alias :origin_extract_with_type :extract_with_type

    def download_file(_full_filename)
      # 捕获一下异常，不会因为plugin的原因导致pod失败
      begin
        if _full_filename.to_s.include?($pluginCurrentTarget)
          # 说明是之前被赋值的开始下载了

          # 获取CDN下载执行前时间点
          time1 = Time.new
          # 执行原来的CDN下载方法
          origin_download_file(_full_filename)
          # 获取CDN下载执行后时间点
          time2 = Time.new
          # 赋值CDN下载耗时给全局变量，用于之后输出以及写在csv中
          $cdnDownloadTime = time2 - time1
        else
          # 说明不是之前被赋值的开始下载了，输出一下，然后清空
          puts "\e[31mCocoapodsTSPodfileTimeWatch unzip warning: #{$pluginCurrentTarget} target error\e[0m"
          puts "\e[31mCocoapodsTSPodfileTimeWatch unzip warning: #{$pluginCurrentPodName} name error\e[0m"
          $pluginCurrentTarget = ""
          $pluginCurrentPodName = ""
        end
      rescue => exception
        # 输出CDM下载方法异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch download_file error(已捕获): #{exception}\e[0m"
      end
      
    end

    def extract_with_type(full_filename, type = :zip)
      # 捕获一下异常，不会因为plugin的原因导致pod失败
      begin
        if full_filename.to_s.include?($pluginCurrentTarget)
          # 说明是之前被赋值的下载完成了，开始进行解压了

          # 计算拷贝到的目录下所有文件总大小，单位为M
          dirSum = File.size(full_filename.to_s)/1000.0/1000.0
          # 赋值给当前正在解压的zip大小，之后输出到csv要用
          $pluginCurrentZipSize = dirSum
        else
          # 说明不是之前被赋值的下载完成了，输出一下，然后清空
          puts "\e[31mCocoapodsTSPodfileTimeWatch unzip warning: #{$pluginCurrentTarget} target error\e[0m"
          puts "\e[31mCocoapodsTSPodfileTimeWatch unzip warning: #{$pluginCurrentPodName} name error\e[0m"
          $pluginCurrentTarget = ""
          $pluginCurrentPodName = ""
        end
      rescue => exception
        # 输出CDN解压方法异常
        puts "\e[31mCocoapodsTSPodfileTimeWatch extract_with_type error(已捕获): #{exception}\e[0m"
      end
      # 获取CDN解压前时间点
      time1 = Time.new
      # 执行之前的解压方法
      origin_extract_with_type(full_filename, type)
      # 获取CDN解压后时间点
      time2 = Time.new
      # 赋值CDN解压耗时给全局变量，用于之后输出以及写在csv中
      $cdnUnZipTime = time2 - time1
    end
  end

  # class Pod::Downloader::Git
  #   # 使用方法别名hook clone方法
  #   alias :origin_clone :clone
  #   def clone(force_head = false, shallow_clone = true)
  #     # 获取clone执行前时间点
  #     time1 = Time.new
  #     # 执行之前的clone方法
  #     origin_clone(force_head, shallow_clone)
      
  #     # 如果不是--verbose，只输出总耗时，总下载大小
  #     # 捕获一下异常，不会因为plugin的原因导致pod失败
  #     begin
  #       # 获取clone执行后时间点
  #       time2 = Time.new
  #       # 获取时间差
  #       time = time2 - time1
  #       # 赋值一个给全局变量，之后时间统计要用到
  #       $cloneTime = time
  #       # 赋值一个给全局变量，之后时间统计要用到
  #       $cloneAllTime = $cloneAllTime + time
  #       # 获取git clone下载的文件路径
  #       source = target_path.to_s
  #       # 计算git clone下载的文件大小，单位为M
  #       dirSum = Dir.size(source)/1000.0/1000.0
  #       # 赋值给一个全局变量，之后输出会用到
  #       $gitAllSize = $gitAllSize + dirSum
  #       # 如果是--verbose，则输出详细信息，生成csv
  #       if $pluginIsVerbose == true
  #         verboseClone(force_head, shallow_clone, time, dirSum)
  #       end
  #     rescue => exception
  #       # 标红输出git clone hook异常
  #       puts "\e[31mCocoapodsTSPodfileTimeWatch clone error(已捕获): #{exception}\e[0m"
  #     end

  #   end

  #   # --verbose输出每个库的下载耗时
  #   def verboseClone(force_head, shallow_clone, time, dirSum)
  #     # 这里只能根据url获取到pod名称的开始index
  #     start = url.rindex("/") + 1
  #     # 获取pod名称
  #     podName = url[start, url.length]
  #     # 标红输出git clone耗时
  #     puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone time: #{time}\e[0m"
  #     # 赋值给一个全局变量，之后输出会用到
  #     $gitSize = dirSum
  #     # 标红输出git clone下载文件大小
  #     puts "\e[31mCocoapodsTSPodfileTimeWatch #{podName} clone allsize: "+"#{dirSum}"+"M\e[0m"
  #   end
  # end
end