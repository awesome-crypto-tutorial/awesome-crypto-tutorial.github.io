#!/usr/bin/env ruby
# Twitter API 客户端
# 支持 Twitter API v2 的推文发布功能

require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'oauth'

class TwitterAPI
  def initialize(api_key, api_secret, access_token, access_token_secret)
    @api_key = api_key
    @api_secret = api_secret
    @access_token = access_token
    @access_token_secret = access_token_secret
    @base_url = 'https://api.twitter.com/2'
  end

  # 发布推文
  def post_tweet(text, media_ids = nil)
    begin
      uri = URI("#{@base_url}/tweets")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@bearer_token}" if @bearer_token

      # 构建请求体
      request_body = { text: text }
      if media_ids && !media_ids.empty?
        request_body[:media] = { media_ids: media_ids }
      end

      request.body = request_body.to_json

      response = http.request(request)
      
      if response.code == '201'
        result = JSON.parse(response.body)
        puts "✅ Tweet posted successfully: #{result['data']['id']}"
        return { success: true, tweet_id: result['data']['id'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        puts "❌ Twitter API Error: #{response.code} - #{error_data['detail'] || response.body}"
        return { success: false, error: error_data['detail'] || response.body }
      end
      
    rescue => e
      puts "❌ Error posting tweet: #{e.message}"
      return { success: false, error: e.message }
    end
  end

  # 上传媒体文件
  def upload_media(image_url)
    begin
      # 下载图片
      uri = URI(image_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      response = http.get(uri.path)
      if response.code != '200'
        puts "❌ Failed to download image: #{response.code}"
        return nil
      end

      image_data = response.body
      
      # 上传到 Twitter
      upload_uri = URI('https://upload.twitter.com/1.1/media/upload.json')
      upload_http = Net::HTTP.new(upload_uri.host, upload_uri.port)
      upload_http.use_ssl = true

      request = Net::HTTP::Post.new(upload_uri)
      request['Content-Type'] = 'multipart/form-data'
      
      # 构建 multipart 请求
      boundary = "----WebKitFormBoundary#{rand(1000000)}"
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      
      body = ""
      body += "--#{boundary}\r\n"
      body += "Content-Disposition: form-data; name=\"media\"; filename=\"image.jpg\"\r\n"
      body += "Content-Type: image/jpeg\r\n\r\n"
      body += image_data
      body += "\r\n--#{boundary}--\r\n"
      
      request.body = body

      upload_response = upload_http.request(request)
      
      if upload_response.code == '200'
        result = JSON.parse(upload_response.body)
        puts "✅ Media uploaded successfully: #{result['media_id_string']}"
        return result['media_id_string']
      else
        puts "❌ Media upload failed: #{upload_response.code} - #{upload_response.body}"
        return nil
      end
      
    rescue => e
      puts "❌ Error uploading media: #{e.message}"
      return nil
    end
  end

  # 使用 Bearer Token 认证
  def authenticate_with_bearer_token
    @bearer_token = ENV['TWITTER_BEARER_TOKEN']
    puts "Debug: Bearer Token from ENV: #{@bearer_token ? 'Present' : 'Missing'}"
    if @bearer_token && !@bearer_token.empty?
      puts "✅ Twitter Bearer Token configured"
      return true
    else
      puts "❌ Twitter Bearer Token not configured"
      return false
    end
  end

  # 使用 Bearer Token 发布推文
  def post_tweet_with_bearer_token(text, media_ids = nil)
    return { success: false, error: "Not authenticated" } unless @bearer_token

    begin
      uri = URI("#{@base_url}/tweets")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@bearer_token}"

      # 构建请求体
      request_body = { text: text }
      if media_ids && !media_ids.empty?
        request_body[:media] = { media_ids: media_ids }
      end

      request.body = request_body.to_json

      response = http.request(request)
      
      if response.code == '201'
        result = JSON.parse(response.body)
        puts "✅ Tweet posted successfully: #{result['data']['id']}"
        return { success: true, tweet_id: result['data']['id'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        puts "❌ Twitter API Error: #{response.code} - #{error_data['detail'] || response.body}"
        return { success: false, error: error_data['detail'] || response.body }
      end
      
    rescue => e
      puts "❌ Error posting tweet: #{e.message}"
      return { success: false, error: e.message }
    end
  end

  # OAuth 1.0a 认证
  def authenticate_with_oauth
    begin
      consumer = OAuth::Consumer.new(@api_key, @api_secret, {
        site: 'https://api.twitter.com',
        scheme: :header
      })
      
      access_token = OAuth::AccessToken.from_hash(consumer, {
        oauth_token: @access_token,
        oauth_token_secret: @access_token_secret
      })
      
      @oauth_consumer = consumer
      @oauth_access_token = access_token
      
      puts "✅ OAuth 1.0a authentication successful"
      return true
      
    rescue => e
      puts "❌ OAuth 1.0a authentication failed: #{e.message}"
      return false
    end
  end

  # 使用 OAuth 1.0a 发布推文
  def post_tweet_with_oauth(text, media_ids = nil)
    return { success: false, error: "Not authenticated" } unless @oauth_access_token

    begin
      uri = URI("#{@base_url}/tweets")
      
      request_body = { text: text }
      if media_ids && !media_ids.empty?
        request_body[:media] = { media_ids: media_ids }
      end

      response = @oauth_access_token.post(uri.path, request_body.to_json, {
        'Content-Type' => 'application/json'
      })
      
      if response.code == '201'
        result = JSON.parse(response.body)
        puts "✅ Tweet posted successfully with OAuth 1.0a: #{result['data']['id']}"
        return { success: true, tweet_id: result['data']['id'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        puts "❌ Twitter API Error: #{response.code} - #{error_data['detail'] || response.body}"
        return { success: false, error: error_data['detail'] || response.body }
      end
      
    rescue => e
      puts "❌ Error posting tweet with OAuth 1.0a: #{e.message}"
      return { success: false, error: e.message }
    end
  end
end

# 使用示例
if __FILE__ == $0
  # 从环境变量获取认证信息
  api_key = ENV['TWITTER_API_KEY']
  api_secret = ENV['TWITTER_API_SECRET']
  access_token = ENV['TWITTER_ACCESS_TOKEN']
  access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  bearer_token = ENV['TWITTER_BEARER_TOKEN']
  
  if api_key && api_secret && access_token && access_token_secret
    twitter = TwitterAPI.new(api_key, api_secret, access_token, access_token_secret)
    
    if twitter.authenticate_with_oauth
      # 测试发布推文
      test_tweet = "🚀 测试推文：加密货币新手入门指南 #Crypto #Trading #NewUser"
      result = twitter.post_tweet_with_oauth(test_tweet)
      
      if result[:success]
        puts "推文发布成功！"
      else
        puts "推文发布失败：#{result[:error]}"
      end
    end
  elsif bearer_token
    # 使用 Bearer Token 测试
    twitter = TwitterAPI.new('', '', '', '')
    if twitter.authenticate_with_bearer_token
      test_tweet = "🚀 测试推文：加密货币新手入门指南 #Crypto #Trading #NewUser"
      result = twitter.post_tweet_with_bearer_token(test_tweet)
      
      if result[:success]
        puts "推文发布成功！"
      else
        puts "推文发布失败：#{result[:error]}"
      end
    end
  else
    puts "请设置 Twitter API 环境变量"
  end
end
