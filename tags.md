---
layout: default
title: 标签索引
permalink: /tags/
---

<h1>标签索引</h1>

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

<ul>
{% for item in tag_list %}
  {% unless item == '' %}
    {% assign parts = item | split: '#' %}
    {% assign tag_count = parts[0] | plus: 0 %}
    {% assign tag_name = parts[1] %}
    <li id="{{ tag_name }}">
      <h2>{{ tag_name }} ({{ tag_count }})</h2>
      <ul>
        {% for post in site.tags[tag_name] %}
          <li><a href="{{ post.url | relative_url }}">{{ post.title }}</a> <small>{{ post.date | date: "%Y-%m-%d" }}</small></li>
        {% endfor %}
      </ul>
    </li>
  {% endunless %}
{% endfor %}
</ul>


