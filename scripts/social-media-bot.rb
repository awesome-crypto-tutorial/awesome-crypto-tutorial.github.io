#!/usr/bin/env ruby
# 社交媒体自动发布机器人
# 功能：从 awesome-crypto-tutorial 中提取文章，用 AI 生成适合 Twitter 和 Telegram 的内容，并自动发布

require 'bundler/setup'
require 'yaml'
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'dotenv/load'
require_relative 'twitter-api'

class SocialMediaBot
  def initialize
    @posts_dir = '_posts'
    @data_dir = '_data'
    @logs_dir = 'logs'
    @deepseek_api_key = ENV['DEEPSEEK_API_KEY']
    @deepseek_api_url = 'https://api.deepseek.com/v1/chat/completions'
    @twitter_api_key = ENV['TWITTER_API_KEY']
    @twitter_api_secret = ENV['TWITTER_API_SECRET']
    @twitter_access_token = ENV['TWITTER_ACCESS_TOKEN']
    @twitter_access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    @telegram_bot_token = ENV['TELEGRAM_BOT_TOKEN']
    @telegram_chat_id = ENV['TELEGRAM_CHAT_ID']
    @base_url = 'https://awesome-crypto-tutorial.github.io'
    
    # 确保目录存在
    FileUtils.mkdir_p(@data_dir)
    FileUtils.mkdir_p(@logs_dir)
    
    # 初始化日志文件
    @log_file = File.join(@logs_dir, 'social-media-bot.log')
    
    # 初始化 Twitter API 客户端
    if @twitter_api_key && @twitter_api_secret && @twitter_access_token && @twitter_access_token_secret
      @twitter_client = TwitterAPI.new(@twitter_api_key, @twitter_api_secret, @twitter_access_token, @twitter_access_token_secret)
      @twitter_client.authenticate_with_oauth
      log("Twitter API credentials configured")
    else
      @twitter_client = nil
      log("Warning: Twitter API credentials not configured - will use simulation mode")
    end
    
    # 加载已发布的文章记录
    @published_file = File.join(@data_dir, 'published_posts.yml')
    @published_posts = load_published_posts
  end

  # 记录日志
  def log(message, level = 'INFO')
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    log_entry = "[#{timestamp}] [#{level}] #{message}"
    
    # 输出到控制台
    puts log_entry
    
    # 写入日志文件
    File.open(@log_file, 'a') do |f|
      f.puts log_entry
    end
  end

  # 加载已发布的文章记录
  def load_published_posts
    if File.exist?(@published_file)
      begin
        YAML.safe_load(File.read(@published_file)) || []
      rescue => e
        puts "Warning: Could not load published posts: #{e.message}"
        []
      end
    else
      []
    end
  end

  # 保存已发布的文章记录
  def save_published_posts
    File.write(@published_file, @published_posts.to_yaml)
  end

  # 获取所有文章，按日期排序
  def get_all_posts
    posts = Dir.glob("#{@posts_dir}/*.markdown")
    posts.sort_by { |file| File.basename(file) }
  end

  # 获取下一个要发布的文章
  def get_next_post_to_publish
    all_posts = get_all_posts
    all_posts.find { |post_file| !@published_posts.include?(File.basename(post_file)) }
  end

  # 解析文章内容
  def parse_post(post_file)
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

    {
      file: post_file,
      title: front_matter['title'] || 'Untitled',
      date: front_matter['date'],
      tags: front_matter['tags'] || [],
      permalink: front_matter['permalink'] || File.basename(post_file, '.markdown'),
      content: post_content,
      image: front_matter['image'],
      image_alt: front_matter['image_alt']
    }
  end

  # 调用 DeepSeek API 生成社交媒体内容
  def generate_social_content(post_data)
    return nil unless @deepseek_api_key

    begin
      # 构建提示词
      prompt = build_social_media_prompt(post_data)
      
      # 调用 API
      response = call_deepseek_api(prompt)
      
      if response && response['choices'] && response['choices'][0]
        content = response['choices'][0]['message']['content'].strip
        puts "Generated social media content for: #{post_data[:title]}"
        return content
      else
        puts "No valid response from AI"
        return nil
      end
    rescue => e
      puts "Error calling DeepSeek API: #{e.message}"
      return nil
    end
  end

  # 构建社交媒体提示词
  def build_social_media_prompt(post_data)
    <<~PROMPT
      你是一个专业的加密货币社交媒体内容创作专家。请根据以下文章信息，生成适合 Twitter 和 Telegram 发布的内容。

      文章标题: #{post_data[:title]}
      文章标签: #{post_data[:tags].join(', ')}
      文章内容摘要: #{post_data[:content][0..800]}...

      要求：
      1. 生成两条内容：一条适合 Twitter（280字符以内），一条适合 Telegram（500字符以内）
      2. 内容要吸引人，突出文章的核心价值
      3. 包含相关的加密货币标签，如 #Bitcoin #Crypto #Trading #Binance #OKX #Gateio
      4. 包含新用户注册相关的标签，如 #NewUser #Registration #SignUp
      5. 内容要简洁有力，适合社交媒体传播
      6. 使用 JSON 格式返回，包含 twitter 和 telegram 两个字段

      示例格式：
      {
        "twitter": "🚀 新手必看！加密货币入门完全指南，从注册到交易一步到位 #Crypto #Trading #NewUser #Binance",
        "telegram": "📚 加密货币新手入门指南\n\n✅ 交易所注册教程\n✅ 安全交易技巧\n✅ 风险控制方法\n\n适合完全零基础的新手，手把手教你进入币圈！\n\n#Crypto #Trading #NewUser #Registration #Binance #OKX"
      }

      请根据文章内容生成相应的社交媒体内容：
    PROMPT
  end

  # 调用 DeepSeek API
  def call_deepseek_api(prompt)
    uri = URI(@deepseek_api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@deepseek_api_key}"

    request.body = {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 1000,
      temperature: 0.7
    }.to_json

    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      puts "API Error: #{response.code} - #{response.body}"
      nil
    end
  end

  # 发布到 Twitter
  def post_to_twitter(content, image_url = nil, original_url = nil)
    log("Starting Twitter post process")
    
    if @twitter_client.nil?
      log("Twitter client not available - using simulation mode", "WARN")
      return simulate_twitter_post(content, image_url, original_url)
    end

    begin
      # 构建推文内容
      tweet_content = content
      if original_url
        tweet_content += "\n\n📖 阅读原文: #{original_url}"
      end

      # 添加相关标签
      tweet_content += "\n\n#Crypto #Trading #NewUser #Registration #Binance #OKX #Gateio"

      # 确保不超过 280 字符限制
      if tweet_content.length > 280
        tweet_content = tweet_content[0..276] + "..."
        log("Tweet content truncated to fit 280 character limit", "WARN")
      end

      log("Posting to Twitter: #{tweet_content")
      
      # 上传图片（如果有）
      media_ids = nil
      if image_url
        log("Uploading media: #{image_url}")
        media_id = @twitter_client.upload_media(image_url)
        if media_id
          media_ids = [media_id]
          log("Media uploaded successfully: #{media_id}")
        else
          log("Media upload failed", "ERROR")
        end
      end
      
      # 发布推文
      log("Publishing tweet with OAuth")
      result = @twitter_client.post_tweet_with_oauth(tweet_content, media_ids)
      
      if result[:success]
        log("✅ Posted to Twitter successfully: #{result[:tweet_id]}")
        return true
      else
        log("❌ Failed to post to Twitter: #{result[:error]}", "ERROR")
        return false
      end
      
    rescue => e
      log("Error posting to Twitter: #{e.message}", "ERROR")
      log("Backtrace: #{e.backtrace.first(3).join(', ')}", "ERROR")
      return false
    end
  end

  # 模拟 Twitter 发布
  def simulate_twitter_post(content, image_url = nil, original_url = nil)
    log("Simulating Twitter post (no real API configured)")
    
    begin
      # 构建推文内容
      tweet_content = content
      if original_url
        tweet_content += "\n\n📖 阅读原文: #{original_url}"
      end

      # 添加相关标签
      tweet_content += "\n\n#Crypto #Trading #NewUser #Registration #Binance #OKX #Gateio"

      # 确保不超过 280 字符限制
      if tweet_content.length > 280
        tweet_content = tweet_content[0..276] + "..."
      end

      log("Simulated tweet content: #{tweet_content[0..100]}...")
      
      # 模拟成功响应
      fake_tweet_id = "sim_#{Time.now.to_i}"
      log("✅ Twitter post simulated successfully: #{fake_tweet_id}")
      
      return true
      
    rescue => e
      log("Error in Twitter simulation: #{e.message}", "ERROR")
      return false
    end
  end

  # 发布到 Telegram
  def post_to_telegram(content, image_url = nil, original_url = nil)
    log("Starting Telegram post process")
    
    unless @telegram_bot_token && @telegram_chat_id
      log("Telegram credentials not configured", "ERROR")
      return false
    end

    begin
      # 构建 Telegram 内容
      telegram_content = content
      if original_url
        telegram_content += "\n\n📖 阅读原文: #{original_url}"
      end

      # 添加相关标签
      telegram_content += "\n\n#Crypto #Trading #NewUser #Registration #Binance #OKX #Gateio"

      log("Posting to Telegram: #{telegram_content[0..100]}...")
      log("Telegram Chat ID: #{@telegram_chat_id}")
      
      # 构建 Telegram Bot API 请求
      uri = URI("https://api.telegram.org/bot#{@telegram_bot_token}/sendMessage")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'

      request.body = {
        chat_id: @telegram_chat_id,
        text: telegram_content,
        parse_mode: 'HTML',
        disable_web_page_preview: false
      }.to_json

      log("Sending request to Telegram API")
      response = http.request(request)
      
      log("Telegram API response code: #{response.code}")
      
      if response.code == '200'
        result = JSON.parse(response.body)
        if result['ok']
          message_id = result['result']['message_id']
          log("✅ Posted to Telegram successfully, message ID: #{message_id}")
          return true
        else
          log("Telegram API Error: #{result['description']}", "ERROR")
          return false
        end
      else
        log("HTTP Error: #{response.code} - #{response.body}", "ERROR")
        return false
      end
      
    rescue => e
      log("Error posting to Telegram: #{e.message}", "ERROR")
      log("Backtrace: #{e.backtrace.first(3).join(', ')}", "ERROR")
      return false
    end
  end

  # 主执行方法
  def run
    log("Starting social media bot")
    log("Published posts count: #{@published_posts.length}")
    
    # 获取下一个要发布的文章
    next_post_file = get_next_post_to_publish
    
    if next_post_file.nil?
      log("No new posts to publish")
      return
    end

    log("Next post to publish: #{File.basename(next_post_file)}")
    
    # 解析文章内容
    post_data = parse_post(next_post_file)
    if post_data.nil?
      log("Failed to parse post", "ERROR")
      return
    end

    log("Post title: #{post_data[:title]}")
    log("Post permalink: #{post_data[:permalink]}")

    # 生成社交媒体内容
    social_content = generate_social_content(post_data)
    if social_content.nil?
      log("Failed to generate social content", "ERROR")
      return
    end

    log("AI content generated successfully")

    # 清理 AI 生成的内容
    cleaned_content = social_content
      .gsub(/[\x00-\x1F\x7F]/, '')  # 移除控制字符
      .gsub(/^```json\s*/, '')      # 移除开头的 ```json
      .gsub(/\s*```$/, '')          # 移除结尾的 ```
      .strip                        # 移除首尾空白
    
    # 解析 AI 生成的内容
    begin
      content_data = JSON.parse(cleaned_content)
      twitter_content = content_data['twitter']
      telegram_content = content_data['telegram']
      log("Content parsed successfully")
    rescue => e
      log("Error parsing AI content: #{e.message}", "ERROR")
      log("Raw content: #{social_content}")
      log("Cleaned content: #{cleaned_content}")
      return
    end

    # 构建原文链接
    original_url = "#{@base_url}/#{post_data[:permalink]}/"
    log("Original URL: #{original_url}")
    
    # 发布到社交媒体
    log("Starting social media publishing")
    twitter_success = post_to_twitter(twitter_content, post_data[:image], original_url)
    telegram_success = post_to_telegram(telegram_content, post_data[:image], original_url)

    # 记录发布状态
    log("Publishing results - Twitter: #{twitter_success}, Telegram: #{telegram_success}")
    
    if twitter_success || telegram_success
      @published_posts << File.basename(next_post_file)
      save_published_posts
      log("✅ Post published successfully and recorded")
    else
      log("❌ Failed to publish post to any platform", "ERROR")
    end
  end
end

# 执行脚本
if __FILE__ == $0
  bot = SocialMediaBot.new
  bot.run
end
