#!/usr/bin/env ruby
# AI关键词生成器 - 使用DeepSeek API分析文章内容并生成图片关键词

require 'yaml'
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'


class AIKeywordGenerator
  def initialize
    @posts_dir = '_posts'
    @deepseek_api_key = ENV['DEEPSEEK_API_KEY']
    @deepseek_api_url = 'https://api.deepseek.com/v1/chat/completions'
    @keyword_cache = {}
    @cache_file = '_data/ai_keywords_cache.yml'
    
    # 加载缓存
    load_cache
  end

  # 加载关键词缓存
  def load_cache
    if File.exist?(@cache_file)
      begin
        @keyword_cache = YAML.safe_load(File.read(@cache_file)) || {}
      rescue => e
        puts "Warning: Could not load cache file: #{e.message}"
        @keyword_cache = {}
      end
    end
  end

  # 保存关键词缓存
  def save_cache
    FileUtils.mkdir_p('_data')
    File.write(@cache_file, @keyword_cache.to_yaml)
  end

  # 调用DeepSeek API生成关键词
  def generate_keyword_with_ai(title, content, tags)
    # 检查缓存
    cache_key = "#{title}_#{content[0..100]}_#{tags.join('_')}".hash
    if @keyword_cache[cache_key]
      puts "Using cached keywords for: #{title}"
      return @keyword_cache[cache_key]
    end

    unless @deepseek_api_key
      puts "Warning: DEEPSEEK_API_KEY not set, using fallback keyword"
      return {
        'detailed' => generate_fallback_keyword(title, content, tags),
        'simple' => generate_simple_fallback_keyword(title, content, tags)
      }
    end

    begin
      # 构建提示词
      prompt = build_prompt(title, content, tags)
      
      # 调用API
      response = call_deepseek_api(prompt)
      
      if response && response['choices'] && response['choices'][0]
        keyword = response['choices'][0]['message']['content'].strip
        puts "AI generated keyword for '#{title}': #{keyword}"
        
        # 生成简短关键词
        simple_keyword = generate_simple_keyword(keyword, title, tags)
        
        result = {
          'detailed' => keyword,
          'simple' => simple_keyword
        }
        
        # 缓存结果
        @keyword_cache[cache_key] = result
        save_cache
        
        return result
      else
        puts "API response error, using fallback"
        return {
          'detailed' => generate_fallback_keyword(title, content, tags),
          'simple' => generate_simple_fallback_keyword(title, content, tags)
        }
      end
    rescue => e
      puts "Error calling DeepSeek API: #{e.message}"
      return {
        'detailed' => generate_fallback_keyword(title, content, tags),
        'simple' => generate_simple_fallback_keyword(title, content, tags)
      }
    end
  end

  # 生成简短关键词（1-2个词）
  def generate_simple_keyword(detailed_keyword, title, tags)
    # 从详细关键词中提取核心词汇
    words = detailed_keyword.split('-')
    
    # 优先选择最核心的1-2个词
    if words.length >= 2
      # 选择前两个最重要的词
      "#{words[0]}-#{words[1]}"
    else
      # 如果只有一个词，尝试从标题中提取相关词
      title_words = title.downcase.split(/[\s\-_]+/)
      tag_words = tags.map(&:downcase)
      
      # 寻找与详细关键词相关的词
      related_word = nil
      (title_words + tag_words).each do |word|
        if word.length > 2 && !word.match?(/[\u4e00-\u9fff]/) # 排除中文和太短的词
          related_word = word
          break
        end
      end
      
      if related_word && words[0] != related_word
        "#{words[0]}-#{related_word}"
      else
        words[0]
      end
    end
  end

  # 生成简短的备用关键词
  def generate_simple_fallback_keyword(title, content, tags)
    # 从标题和标签中提取核心词汇
    text = "#{title} #{tags.join(' ')}".downcase
    
    # 常见关键词映射（简短版本）
    simple_keyword_map = {
      'binance' => 'binance',
      'okx' => 'okx',
      'gate' => 'gate',
      'trading' => 'trading',
      'exchange' => 'exchange',
      'crypto' => 'crypto',
      'bitcoin' => 'bitcoin',
      'ethereum' => 'ethereum',
      'wallet' => 'wallet',
      'security' => 'security',
      'legal' => 'legal',
      'bank' => 'bank',
      'card' => 'card',
      'frozen' => 'frozen',
      'money' => 'money',
      'investment' => 'investment',
      'blockchain' => 'blockchain',
      'defi' => 'defi',
      'nft' => 'nft',
      'mining' => 'mining'
    }
    
    simple_keyword_map.each do |key, value|
      return value if text.include?(key)
    end
    
    'crypto'
  end

  # 构建AI提示词
  def build_prompt(title, content, tags)
    <<~PROMPT
      你是一个专业的图片关键词生成专家。请根据以下文章信息，生成一个适合用于搜索相关图片的英文关键词。

      文章标题: #{title}
      文章标签: #{tags.join(', ')}
      文章内容摘要: #{content[0..500]}...

      要求：
      1. 生成一个简洁的英文关键词或短语（2-4个单词）
      2. 关键词应该能够准确反映文章的核心主题
      3. 适合用于图片搜索引擎（如Unsplash、Pexels等）
      4. 使用连字符连接多个单词，如：cryptocurrency-trading-charts
      5. 只返回关键词，不要其他解释

      示例：
      - 关于币安交易所的文章 → cryptocurrency-exchange-trading
      - 关于银行卡冻结的文章 → frozen-bank-card-money
      - 关于交易图表的文章 → trading-charts-analysis
      - 关于法律风险的文章 → legal-compliance-risk

      请为这篇文章生成关键词：
    PROMPT
  end

  # 调用DeepSeek API
  def call_deepseek_api(prompt)
    uri = URI(@deepseek_api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@deepseek_api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: 'deepseek-chat',
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 50,
      temperature: 0.3
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      puts "API request failed: #{response.code} - #{response.body}"
      nil
    end
  end

  # 生成备用关键词（当AI不可用时）
  def generate_fallback_keyword(title, content, tags)
    text = "#{title} #{content} #{tags.join(' ')}".downcase
    
    # 关键词映射表
    keyword_map = {
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
    
    # 查找匹配的关键词
    keyword_map.each do |key, value|
      return value if text.include?(key)
    end
    
    # 默认关键词
    'cryptocurrency-blockchain'
  end

  # 为文章生成AI关键词
  def generate_keyword_for_post(post_file)
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
    
    # 生成AI关键词
    ai_keywords = generate_keyword_with_ai(title, post_content, tags)
    puts "AI keywords for #{title}: detailed=#{ai_keywords['detailed']}, simple=#{ai_keywords['simple']}"
    
    {
      file: post_file,
      title: title,
      ai_keyword: ai_keywords['detailed'],
      ai_keyword_simple: ai_keywords['simple'],
      fallback_keyword: generate_fallback_keyword(title, post_content, tags)
    }
  end

  # 处理所有文章（支持增量处理）
  def process_all_posts(incremental = true)
    posts = Dir.glob("#{@posts_dir}/*.markdown")
    results = []
    
    # 如果启用增量处理，检查已存在的关键词
    existing_keywords = {}
    if incremental && File.exist?('_data/ai_keywords.yml')
      begin
        existing_keywords = YAML.safe_load(File.read('_data/ai_keywords.yml')) || {}
      rescue => e
        puts "Warning: Could not load existing keywords: #{e.message}"
      end
    end
    
    puts "Processing #{posts.length} posts with AI keyword generation..."
    puts "Incremental mode: #{incremental ? 'ON' : 'OFF'}"
    
    posts.each_with_index do |post_file, index|
      # 检查是否需要处理这篇文章
      permalink = extract_permalink_from_file(post_file)
      if incremental && existing_keywords[permalink]
        puts "Skipping #{index + 1}/#{posts.length}: #{File.basename(post_file)} (already processed)"
        next
      end
      
      puts "Processing #{index + 1}/#{posts.length}: #{File.basename(post_file)}"
      
      result = generate_keyword_for_post(post_file)
      if result
        results << result
      end
      
      # 添加延迟避免API限制
      sleep(2) if index < posts.length - 1
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

  # 生成关键词配置文件（支持增量更新）
  def generate_keyword_config(results)
    # 加载现有的配置
    config = {}
    if File.exist?('_data/ai_keywords.yml')
      begin
        config = YAML.safe_load(File.read('_data/ai_keywords.yml')) || {}
      rescue => e
        puts "Warning: Could not load existing config: #{e.message}"
      end
    end
    
    # 更新或添加新的关键词
    results.each do |result|
      # 从文章文件中读取真正的 permalink
      permalink = extract_permalink_from_file(result[:file])
      config[permalink] = {
        'ai_keyword' => result[:ai_keyword],
        'ai_keyword_simple' => result[:ai_keyword_simple],
        'fallback_keyword' => result[:fallback_keyword],
        'title' => result[:title]
      }
    end
    
    File.write('_data/ai_keywords.yml', config.to_yaml)
    puts "Updated _data/ai_keywords.yml with #{results.length} new keywords (total: #{config.length})"
  end

  # 主执行方法
  def run
    puts "Starting AI keyword generation..."
    
    # 检查命令行参数
    incremental = !ARGV.include?('--full')
    
    puts "Mode: #{incremental ? 'Incremental' : 'Full'}"
    
    # 确保目录存在
    FileUtils.mkdir_p('_data')
    
    # 处理所有文章
    results = process_all_posts(incremental)
    
    # 生成配置文件
    generate_keyword_config(results)
    
    puts "Completed! Generated AI keywords for #{results.length} posts"
    puts "Cache saved to #{@cache_file}"
  end
end

# 执行脚本
if __FILE__ == $0
  generator = AIKeywordGenerator.new
  generator.run
end
