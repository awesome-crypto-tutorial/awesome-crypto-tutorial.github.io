---
layout: default
title: 标签索引
permalink: /tags/
---

<h1>标签索引</h1>

<div id="tag-container">
  <div id="tag-list">
    <p>点击下方标签查看相关文章：</p>
    <div id="tags">
      {% assign _tag_items = '' %}
      {% for tag in site.tags %}
        {% assign tag_name = tag[0] %}
        {% assign tag_posts = tag[1] %}
        {% assign tag_count = tag_posts | size %}
        {% capture padded_count %}{{ '0000' | append: tag_count }}{% endcapture %}
        {% capture padded_count %}{{ padded_count | slice: -4, 4 }}{% endcapture %}
        {% capture tag_item %}{{ padded_count }}#{{ tag_name }}{% endcapture %}
        {% capture _tag_items %}{{ _tag_items }}{{ tag_item }}|{% endcapture %}
      {% endfor %}
      {% assign tag_list = _tag_items | split: '|' | sort | reverse %}
      
      {% for item in tag_list %}
        {% unless item == '' %}
          {% assign parts = item | split: '#' %}
          {% assign tag_count = parts[0] | plus: 0 %}
          {% assign tag_name = parts[1] %}
          <span class="tag-item" data-tag="{{ tag_name }}">{{ tag_name }} ({{ tag_count }})</span>
        {% endunless %}
      {% endfor %}
    </div>
  </div>
  
  <div id="posts-container" style="display: none;">
    <div id="posts-header">
      <h2 id="selected-tag-title"></h2>
      <button id="back-to-tags">← 返回标签列表</button>
    </div>
    <ul id="posts-list"></ul>
  </div>
</div>

<style>
#tag-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

#tags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin: 20px 0;
}

.tag-item {
  background-color: #f0f0f0;
  border: 1px solid #ddd;
  border-radius: 20px;
  padding: 8px 16px;
  cursor: pointer;
  transition: all 0.3s ease;
  font-size: 14px;
}

.tag-item:hover {
  background-color: #e0e0e0;
  border-color: #999;
}

.tag-item.active {
  background-color: #007cba;
  color: white;
  border-color: #007cba;
}

#posts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 10px;
  border-bottom: 2px solid #eee;
}

#back-to-tags {
  background-color: #6c757d;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

#back-to-tags:hover {
  background-color: #5a6268;
}

#posts-list {
  list-style: none;
  padding: 0;
}

#posts-list li {
  background-color: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 8px;
  padding: 15px;
  margin-bottom: 10px;
  transition: all 0.3s ease;
}

#posts-list li:hover {
  background-color: #e9ecef;
  border-color: #007cba;
}

#posts-list li a {
  text-decoration: none;
  color: #007cba;
  font-weight: 500;
  font-size: 16px;
}

#posts-list li a:hover {
  text-decoration: underline;
}

#posts-list li small {
  color: #6c757d;
  margin-left: 10px;
}
</style>

<script>
let allPosts = [];

// 加载文章数据
async function loadPosts() {
  try {
    const response = await fetch('/search.json');
    allPosts = await response.json();
    return allPosts;
  } catch (error) {
    console.error('加载文章数据失败:', error);
    return [];
  }
}

// 显示标签列表
function showTagList() {
  document.getElementById('tag-list').style.display = 'block';
  document.getElementById('posts-container').style.display = 'none';
  
  // 移除所有标签的active状态
  document.querySelectorAll('.tag-item').forEach(tag => {
    tag.classList.remove('active');
  });
}

// 显示指定标签的文章
function showPostsByTag(tagName) {
  console.log('showPostsByTag 被调用，标签:', tagName, '总文章数:', allPosts.length);
  
  const filteredPosts = allPosts.filter(post => 
    post.tags && post.tags.includes(tagName)
  );
  
  console.log('过滤后的文章数:', filteredPosts.length);
  
  // 按日期排序（最新的在前）
  filteredPosts.sort((a, b) => new Date(b.date) - new Date(a.date));
  
  // 更新标题
  document.getElementById('selected-tag-title').textContent = `标签: ${tagName} (${filteredPosts.length} 篇文章)`;
  
  // 生成文章列表
  const postsList = document.getElementById('posts-list');
  postsList.innerHTML = '';
  
  if (filteredPosts.length === 0) {
    postsList.innerHTML = '<li>该标签下暂无文章</li>';
  } else {
    filteredPosts.forEach(post => {
      const li = document.createElement('li');
      li.innerHTML = `
        <a href="${post.url}">${post.title}</a>
        <small>${post.date}</small>
      `;
      postsList.appendChild(li);
    });
  }
  
  // 显示文章容器，隐藏标签列表
  document.getElementById('tag-list').style.display = 'none';
  document.getElementById('posts-container').style.display = 'block';
  
  console.log('文章列表已显示');
}

// 检查URL hash并显示对应标签的文章
function checkUrlHash() {
  const hash = window.location.hash.substring(1); // 移除#号
  const decodedHash = decodeURIComponent(hash); // URL解码
  console.log('检查URL hash:', hash, '解码后:', decodedHash, '文章数量:', allPosts.length);
  
  if (hash && allPosts.length > 0) {
    // 先尝试解码后的hash
    let tagExists = document.querySelector(`[data-tag="${decodedHash}"]`);
    
    // 如果没找到，再尝试原始hash
    if (!tagExists) {
      tagExists = document.querySelector(`[data-tag="${hash}"]`);
    }
    
    console.log('找到标签元素:', tagExists);
    
    if (tagExists) {
      const tagName = tagExists.getAttribute('data-tag');
      // 添加active状态
      document.querySelectorAll('.tag-item').forEach(t => t.classList.remove('active'));
      tagExists.classList.add('active');
      
      console.log('显示标签文章:', tagName);
      showPostsByTag(tagName);
    } else {
      console.log('标签不存在，尝试查找所有可用标签:');
      document.querySelectorAll('.tag-item').forEach(tag => {
        console.log('可用标签:', tag.getAttribute('data-tag'));
      });
    }
  } else if (hash && allPosts.length === 0) {
    console.log('数据未加载完成，等待中...');
  }
}

// 初始化
document.addEventListener('DOMContentLoaded', function() {
  console.log('页面DOM加载完成');
  
  loadPosts().then(() => {
    console.log('文章数据加载完成，文章数量:', allPosts.length);
    // 数据加载完成后，稍微延迟一下再检查URL hash，确保DOM完全准备好
    setTimeout(() => {
      checkUrlHash();
    }, 100);
  });
  
  // 为所有标签添加点击事件
  document.querySelectorAll('.tag-item').forEach(tag => {
    tag.addEventListener('click', function() {
      const tagName = this.getAttribute('data-tag');
      console.log('点击标签:', tagName);
      
      // 更新URL hash
      window.location.hash = tagName;
      
      // 添加active状态
      document.querySelectorAll('.tag-item').forEach(t => t.classList.remove('active'));
      this.classList.add('active');
      
      showPostsByTag(tagName);
    });
  });
  
  // 返回按钮事件
  document.getElementById('back-to-tags').addEventListener('click', function() {
    console.log('点击返回按钮');
    // 清除URL hash
    window.location.hash = '';
    showTagList();
  });
  
  // 监听hash变化（支持浏览器前进后退）
  window.addEventListener('hashchange', function() {
    console.log('Hash变化:', window.location.hash);
    if (allPosts.length > 0) {
      checkUrlHash();
    }
  });
});
</script>


