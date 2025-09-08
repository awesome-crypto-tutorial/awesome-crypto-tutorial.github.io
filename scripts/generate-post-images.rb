#!/usr/bin/env ruby
# 自动为文章生成配图的 Ruby 脚本
# require 'byebug'

require 'yaml'
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'
require 'debug'

class PostImageGenerator
  def initialize
    @posts_dir = '_posts'
    @images_dir = 'assets/images/posts'
    @ai_keywords_file = '_data/ai_keywords.yml'
    @ai_keywords = load_ai_keywords
    @keyword_map = {
      # 交易所相关
      'binance' => 'cryptocurrency-exchange-trading',
      'okx' => 'cryptocurrency-exchange-trading',
      'gateio' => 'cryptocurrency-exchange-trading',
      'gate' => 'cryptocurrency-exchange-trading',
      
      # 安全相关
      'frozen' => 'frozen-money-bank-card',
      'dirty' => 'money-laundering-prevention',
      'fraud' => 'fraud-prevention-security',
      'kyc' => 'identity-verification-security',
      '2fa' => 'two-factor-authentication',
      
      # 交易相关
      'trading' => 'cryptocurrency-trading-charts',
      'futures' => 'futures-trading-charts',
      'leverage' => 'leverage-trading-risk',
      'fees' => 'trading-fees-calculator',
      'rebate' => 'cashback-rebate-money',
      
      # 出入金相关
      'deposit' => 'money-deposit-banking',
      'withdrawal' => 'money-withdrawal-banking',
      'cashout' => 'cash-withdrawal-atm',
      'bank' => 'banking-financial-services',
      
      # 法律相关
      'legal' => 'legal-law-justice',
      'illegal' => 'law-enforcement-police',
      'compliance' => 'compliance-regulation',
      
      # 技术相关
      'wallet' => 'crypto-wallet-security',
      'network' => 'blockchain-network',
      'usdt' => 'stablecoin-cryptocurrency'
    }
  end

  # 加载AI生成的关键词
  def load_ai_keywords
    if File.exist?(@ai_keywords_file)
      begin
        YAML.safe_load(File.read(@ai_keywords_file)) || {}
      rescue => e
        puts "Warning: Could not load AI keywords file: #{e.message}"
        {}
      end
    else
      puts "AI keywords file not found: #{@ai_keywords_file}"
      puts "Run 'ruby scripts/ai-keyword-generator.rb' first to generate AI keywords"
      {}
    end
  end

  # 提取文章关键词（返回详细和简短两组关键词）
  def extract_keywords(title, content, tags, permalink)
    detailed_keyword = nil
    simple_keyword = nil
    
    # 获取AI生成的关键词
    if @ai_keywords[permalink]
      detailed_keyword = @ai_keywords[permalink]['ai_keyword']
      simple_keyword = @ai_keywords[permalink]['ai_keyword_simple']
    end
    
    # 如果没有AI关键词，使用传统关键词匹配
    if !detailed_keyword && !simple_keyword
      text = "#{title} #{content} #{tags.join(' ')}".downcase
      
      @keyword_map.each do |key, value|
        detailed_keyword = value
        break
      end
      
      # 如果没有匹配到，使用默认关键词
      detailed_keyword ||= 'cryptocurrency-blockchain'
      simple_keyword = detailed_keyword.split('-').first(2).join('-') # 取前两个词作为简短关键词
    end
    
    {
      detailed: detailed_keyword,
      simple: simple_keyword
    }
  end

  # 生成占位图片 URL
  def generate_placeholder_url(keyword, width = 800, height = 400)
    seed = keyword.gsub(/\s+/, '').gsub(/[^a-zA-Z0-9]/, '')[0..9]
    "https://picsum.photos/seed/#{seed}/#{width}/#{height}"
  end

  # 从 Unsplash 获取图片 (需要 API key)
  def get_unsplash_image(keyword, access_key = nil)
    return nil unless access_key
    
    sleep(1)
    begin
      uri = URI("https://api.unsplash.com/search/photos?query=#{URI.encode_www_form_component(keyword)}&per_page=10&orientation=landscape")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Client-ID #{access_key}"
      
      response = http.request(request)
      puts "Searching Unsplash for keyword: #{keyword}"
      if response.code == '200'
        data = JSON.parse(response.body)
        if data['results'] && data['results'].length > 0
            index = [rand(0..data['results'].length-1), 5].min
            result = data['results'][index]
            puts "Found Unsplash image for keyword: #{keyword}, index: #{index}, result: #{result['urls']['regular']}"
          return {
            url: result['urls']['regular'],
            alt: result['alt_description'] || keyword,
            photographer: result['user']['name'],
            photographer_url: result['user']['links']['html']
          }
        else
          puts "No results found for keyword: #{keyword}"
        end
      else
        puts "Unsplash API error for keyword: #{keyword}, status: #{response.code}"
      end
    rescue => e
      puts "Error fetching from Unsplash for keyword #{keyword}: #{e.message}"
    end
    
    nil
  end

  # 尝试多个关键词获取图片
  def get_image_with_fallback_keywords(keywords, access_key = nil)
    return nil unless access_key
    
    # 优先尝试详细关键词
    if keywords[:detailed]
      puts "Trying detailed keyword: #{keywords[:detailed]}"
      image = get_unsplash_image(keywords[:detailed], access_key)
      return image if image
    end
    
    # 如果详细关键词没有结果，尝试简短关键词
    if keywords[:simple] && keywords[:simple] != keywords[:detailed]
      puts "Trying simple keyword: #{keywords[:simple]}"
      image = get_unsplash_image(keywords[:simple], access_key)
      return image if image
    end
    
    # 如果都没有结果，返回 nil
    puts "No images found for any keyword"
    nil
  end

  # 为文章生成配图信息
  def generate_image_for_post(post_file)
    content = File.read(post_file)
    
    # 解析 front matter
    if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)/m
      begin
        front_matter = YAML.safe_load($1, permitted_classes: [Date, Time])
        post_content = $2
      rescue => e
        puts "Error parsing YAML in #{post_file}: #{e.message}"
        return nil
      end
    else
      puts "Invalid post format: #{post_file}"
      return nil
    end
    
    title = front_matter['title'] || 'Untitled'
    tags = front_matter['tags'] || []
    permalink = front_matter['permalink'] || File.basename(post_file, '.markdown')
    
    # 确保 permalink 格式正确（去掉前后的斜杠）
    permalink = permalink.gsub(/^\/+|\/+$/, '') if permalink
    
    # 提取关键词
    keywords = extract_keywords(title, post_content, tags, permalink)
    
    # 生成图片信息
    image_info = {
      keyword: keywords[:detailed] || keywords[:simple],
      placeholder_url: generate_placeholder_url(keywords[:detailed] || keywords[:simple]),
      alt: "#{title} - 配图",
      photographer: 'Placeholder',
      photographer_url: ''
    }
    
    # 尝试从 Unsplash 获取 (如果有 API key)
    unsplash_key = ENV['UNSPLASH_ACCESS_KEY']
    if unsplash_key
      unsplash_image = get_image_with_fallback_keywords(keywords, unsplash_key)
      if unsplash_image
        image_info.merge!(unsplash_image)
      end
    end
    
    image_info
  end

  # 处理所有文章
  def process_all_posts(incremental = true)
    posts = Dir.glob("#{@posts_dir}/*.markdown")
    results = []
    
    # 如果启用增量处理，检查已存在的图片
    existing_images = {}
    if incremental && File.exist?('_data/post_images.yml')
      begin
        existing_images = YAML.safe_load(File.read('_data/post_images.yml')) || {}
      rescue => e
        puts "Warning: Could not load existing images: #{e.message}"
      end
    end
    
    puts "Processing #{posts.length} posts..."
    puts "Incremental mode: #{incremental ? 'ON' : 'OFF'}"
    
    posts.each_with_index do |post_file, index|
      # 检查是否需要处理这篇文章
      permalink = extract_permalink_from_file(post_file)
      if incremental && existing_images[permalink]
        puts "Skipping #{index + 1}/#{posts.length}: #{File.basename(post_file)} (already has image)"
        next
      end
      
      puts "Processing #{index + 1}/#{posts.length}: #{File.basename(post_file)}"
      # if index <= 51
      #   next
      # end
      image_info = generate_image_for_post(post_file)
      if image_info
        results << {
          file: post_file,
          permalink: permalink,
          image: image_info
        }
      end
      
      # 添加延迟避免 API 限制
      sleep(1) if index < posts.length - 1
    end
    
    puts "Processed #{results.length} new posts"
    results
  end

  # 从文章文件中提取 permalink
  def extract_permalink_from_file(post_file)
    content = File.read(post_file)
    
    # 解析 front matter
    if content.match(/^---\s*\n(.*?)\n---\s*\n(.*)/m)
      front_matter_content = $1
      begin
        front_matter = YAML.safe_load(front_matter_content, permitted_classes: [Date, Time])
        permalink = front_matter['permalink']
        
        # 如果 permalink 存在，去掉前后的斜杠
        if permalink
          return permalink.gsub(/^\/+|\/+$/, '')
        end
      rescue => e
        puts "Warning: Could not parse front matter for #{post_file}: #{e.message}"
      end
    end
    
    # 如果没有 permalink，使用文件名（去掉日期前缀）
    filename = File.basename(post_file, '.markdown')
    # 去掉日期前缀 (YYYY-MM-DD-)
    filename.gsub(/^\d{4}-\d{2}-\d{2}-/, '')
  end

  # 生成图片配置文件（支持增量更新）
  def generate_image_config(results)
    # 加载现有的配置
    config = {}
    if File.exist?('_data/post_images.yml')
      begin
        config = YAML.safe_load(File.read('_data/post_images.yml')) || {}
      rescue => e
        puts "Warning: Could not load existing config: #{e.message}"
      end
    end
    
    # 更新或添加新的图片
    results.each do |result|
      permalink = result[:permalink]
      image = result[:image]
      
      config[permalink] = {
        'url' => image[:url] || image[:placeholder_url],
        'alt' => image[:alt],
        'photographer' => image[:photographer],
        'photographer_url' => image[:photographer_url],
        'keyword' => image[:keyword]
      }
    end
    
    File.write('_data/post_images.yml', config.to_yaml)
    puts "Updated _data/post_images.yml with #{results.length} new images (total: #{config.length})"
  end

  # 更新文章添加图片 front matter
  def update_posts_with_images(results)
    results.each do |result|
      post_file = result[:file]
      image = result[:image]
      
      content = File.read(post_file)
      
      # 解析 front matter
      if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)/m
        begin
          front_matter = YAML.safe_load($1, permitted_classes: [Date, Time])
          post_content = $2
        rescue => e
          puts "Error parsing YAML in #{post_file}: #{e.message}"
          next
        end
        
        # 添加图片信息到 front matter
        front_matter['image'] = image[:url] || image[:placeholder_url]
        front_matter['image_alt'] = image[:alt]
        front_matter['image_photographer'] = image[:photographer]
        front_matter['image_photographer_url'] = image[:photographer_url]
        
        # 重新写入文件
        new_content = "#{front_matter.to_yaml}---\n#{post_content}"
        File.write(post_file, new_content)
        
        puts "Updated #{File.basename(post_file)} with image"
      end
    end
  end

  # 主执行方法
  def run
    puts "Starting post image generation..."
    
    # 检查命令行参数
    incremental = !ARGV.include?('--full')
    update_posts = ARGV.include?('--update-posts')
    
    puts "Mode: #{incremental ? 'Incremental' : 'Full'}"
    puts "Update posts: #{update_posts ? 'Yes' : 'No'}"
    
    # 确保目录存在
    FileUtils.mkdir_p(@images_dir)
    FileUtils.mkdir_p('_data')
    
    # 处理所有文章
    results = process_all_posts(incremental)
    
    # 生成配置文件
    generate_image_config(results)
    
    # 更新文章 (可选)
    if update_posts
      update_posts_with_images(results)
    end
    
    puts "Completed! Generated images for #{results.length} posts"
    puts "Run with --update-posts to automatically add images to post front matter"
  end
end

# 执行脚本
if __FILE__ == $0
  generator = PostImageGenerator.new
  generator.run
end
