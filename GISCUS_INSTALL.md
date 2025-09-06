# Giscus安装指南

## 错误解决：giscus is not installed on this repository

这个错误表示Giscus应用还没有安装到你的GitHub仓库。请按照以下步骤安装：

## 1. 安装Giscus应用

1. 访问 [Giscus应用页面](https://github.com/apps/giscus)
2. 点击 "Install" 按钮
3. 选择 "Install giscus on awesome-crypto-tutorial/awesome-crypto-tutorial.github.io"
4. 点击 "Install" 确认安装

## 2. 配置Giscus应用

安装完成后，Giscus会自动配置，但你需要确保：

1. **仓库是公开的**：Giscus只能在公开仓库中工作
2. **Discussions已启用**：确保仓库的Discussions功能已启用
3. **有General分类**：确保Discussions中有General分类

## 3. 验证安装

1. 访问你的仓库：`https://github.com/awesome-crypto-tutorial/awesome-crypto-tutorial.github.io`
2. 点击 "Settings" 标签
3. 在左侧菜单中找到 "Integrations" > "Installed GitHub Apps"
4. 确认 "giscus" 应用已安装

## 4. 测试评论功能

1. 构建并部署你的网站
2. 访问任意一篇文章
3. 在文章底部应该能看到Giscus评论框
4. 尝试发表一条评论测试功能

## 5. 如果仍然有问题

如果安装后仍然显示错误，请检查：

1. **仓库权限**：确保仓库是公开的
2. **Discussions状态**：确保Discussions功能已启用
3. **分类存在**：确保General分类已创建
4. **配置正确**：确保_config.yml中的配置正确

## 6. 替代方案

如果Giscus仍然有问题，可以考虑以下替代方案：

### 方案1：使用Utterances
- 基于GitHub Issues的评论系统
- 安装地址：https://github.com/apps/utterances

### 方案2：使用GitHub Issues作为评论
- 直接在文章中添加"发表评论"链接
- 链接到GitHub Issues页面

### 方案3：使用静态评论
- 使用Jekyll的data files功能
- 手动管理评论

## 7. 联系支持

如果问题仍然存在，可以：
1. 查看Giscus的[GitHub Issues](https://github.com/giscus/giscus/issues)
2. 在Giscus的[Discussions](https://github.com/giscus/giscus/discussions)中寻求帮助
3. 检查[Giscus文档](https://giscus.app/zh-CN)获取更多信息
