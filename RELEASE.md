# RestTimer 发布指南

本文档介绍如何使用 GitHub Actions 将 RestTimer 应用发布到 GitHub Releases。

## 准备工作

1. 确保你的代码已经推送到 GitHub 仓库
2. 确保你的代码是最新的，并且已经完成了所有测试

## 发布步骤

### 1. 创建新版本标签

发布流程通过 Git 标签触发。当你创建并推送一个以 `v` 开头的标签时，GitHub Actions 将自动构建应用并创建 Release。

```bash
# 首先确保你在主分支上
git checkout main

# 拉取最新代码
git pull origin main

# 创建一个新的标签（例如 v1.0.0）
git tag v1.0.0

# 推送标签到 GitHub
git push origin v1.0.0
```

### 2. 监控构建过程

1. 在 GitHub 仓库页面，点击 "Actions" 选项卡
2. 你应该能看到一个名为 "Build and Release" 的工作流正在运行
3. 等待工作流完成，这可能需要几分钟时间

### 3. 检查 Release

1. 工作流完成后，前往仓库的 "Releases" 页面
2. 你应该能看到一个新的 Release，包含了自动生成的 RestTimer.zip 文件
3. 如果需要，你可以编辑 Release 来添加更多详细的发行说明

### 4. 验证发布

1. 下载 RestTimer.zip 文件并解压
2. 确保应用可以正常运行

## 版本命名规范

建议使用语义化版本命名（Semantic Versioning）:

- 主版本号: 当你做了不兼容的 API 修改
- 次版本号: 当你添加了向下兼容的功能
- 修订号: 当你做了向下兼容的问题修正

例如: v1.0.0, v1.1.0, v1.1.1

## 故障排除

如果 GitHub Actions 构建失败:

1. 检查 Actions 日志以了解错误详情
2. 确保 Xcode 项目可以在本地正常构建
3. 验证 RestTimer.xcodeproj 文件的路径是否正确
4. 检查是否有任何依赖项缺失

如果有任何问题，请在 GitHub Issues 中报告。 
