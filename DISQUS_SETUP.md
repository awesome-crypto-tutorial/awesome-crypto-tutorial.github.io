# Giscus评论系统设置指南

## 1. 启用GitHub Discussions

1. 访问你的GitHub仓库：`https://github.com/awesome-crypto-tutorial/awesome-crypto-tutorial.github.io`
2. 点击 "Settings" 标签
3. 在左侧菜单中找到 "General"
4. 滚动到 "Features" 部分
5. 勾选 "Discussions" 选项
6. 点击 "Set up discussions" 按钮

## 2. 创建Discussion分类

1. 在Discussions页面，点击 "New category"
2. 创建分类：
   - **Category name**: `General`
   - **Description**: `General discussions for the blog`
   - **Emoji**: 选择你喜欢的emoji
3. 点击 "Create category"

## 3. 获取仓库ID和分类ID

### 获取仓库ID
1. 访问 [GitHub API](https://api.github.com/repos/awesome-crypto-tutorial/awesome-crypto-tutorial.github.io)
2. 找到 `"id"` 字段，复制这个数字（例如：`123456789`）

### 获取分类ID
1. 访问 [GitHub API](https://api.github.com/repos/awesome-crypto-tutorial/awesome-crypto-tutorial.github.io/discussions/categories)
2. 找到对应分类的 `"id"` 字段，复制这个数字（例如：`DIC_kwDOKhQAAIc`）

## 4. 更新配置文件

在 `_config.yml` 文件中，更新Giscus配置：

```yaml
# 评论系统配置 - 使用Giscus (基于GitHub Discussions的免费评论系统)
giscus:
  repo: awesome-crypto-tutorial/awesome-crypto-tutorial.github.io  # 你的GitHub仓库
  repo_id: R_kgDOKhQAAA  # 替换为你的仓库ID
  category: General
  category_id: DIC_kwDOKhQAAIc  # 替换为你的分类ID
  mapping: pathname
  strict: 0
  reactions_enabled: 1
  emit_metadata: 0
  input_position: bottom
  theme: light
  lang: zh-CN
```

## 5. 验证设置

1. 构建并部署网站
2. 访问任意一篇文章
3. 在文章底部应该能看到Giscus评论框
4. 如果看不到，请检查：
   - 仓库ID和分类ID是否正确
   - GitHub Discussions是否已启用
   - 网站是否已部署

## 6. 自定义设置（可选）

在 `_config.yml` 中，你可以调整以下设置：
- `theme`: 主题（light/dark/auto）
- `lang`: 语言（zh-CN/en等）
- `mapping`: 映射方式（pathname/title/og:title）
- `reactions_enabled`: 是否启用反应（1/0）

## 优势

- **完全免费**：基于GitHub Discussions，无使用限制
- **开源**：代码开源，可自定义
- **快速**：加载速度快
- **功能丰富**：支持反应、回复、搜索等
- **无需注册**：用户使用GitHub账号即可评论

## 注意事项

- 评论者需要有GitHub账号
- 评论数据存储在GitHub Discussions中
- 需要启用GitHub Discussions功能
- 评论会显示在GitHub仓库的Discussions页面

## 故障排除

如果评论框不显示：
1. 检查浏览器控制台是否有JavaScript错误
2. 确认仓库ID和分类ID配置正确
3. 确认GitHub Discussions已启用
4. 检查网络连接
5. 确认仓库是公开的
