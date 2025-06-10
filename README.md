<p align="center">
<img src="./AppIcon/64x64.png" width="100" height="100" align="center" style="margin:0 auto;" />
</p>

<h1 align="center">RestTimer</h1>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

<p align="center">
一款简单而强大的 macOS 休息提醒应用，帮助你保持健康的工作节奏
</p>

## 技术栈

- SwiftUI - 用于构建现代化的用户界面
- AppKit - 提供原生 macOS 功能支持
- Combine - 处理响应式数据流
- UserDefaults - 本地数据持久化
- System Services - 系统服务集成

## 主要功能

### 🕒 定时提醒
- 自定义工作时长和休息时长
- 智能的休息提醒机制
- 多显示器全屏覆盖支持

### 🎯 强制休息
- 全屏遮罩确保休息
- 优雅的倒计时显示
- 随机显示激励名言

### ⚙️ 个性化设置
- 自定义工作/休息时间
- 开机自启动选项
- 休息时是否显示跳过按钮
- 状态栏显示剩余时间

### 🎨 界面设计
- 简洁现代的用户界面
- 深色模式支持
- 状态栏快捷操作

## 安装说明

1. 从 [Releases](https://github.com/yourusername/RestTimer/releases) 下载最新版本
2. 将应用拖入应用程序文件夹
3. 首次运行时授予必要的系统权限

## 使用说明

1. 启动应用后会在状态栏显示计时器图标
2. 点击状态栏图标可以：
   - 查看剩余工作时间
   - 暂停/继续计时
   - 打开设置
   - 退出应用
3. 在设置中可以自定义：
   - 工作时长（默认25分钟）
   - 休息时长（默认5分钟）
   - 是否开机自启
   - 是否显示跳过按钮

## 开发环境要求

- macOS 12.0+
- Xcode 14.0+
- Swift 5.5+

## 本地开发
```bash
# 克隆项目
git clone https://github.com/fxzer/RestTimer.git
# 打开项目
cd RestTimer
open RestTimer.xcodeproj
# 构建运行
Command + R
```
## 直接使用运行产生的App 文件

```bash
#  在 Xcode 中打开项目并运行
# 生成的 .app 文件通常位于：
~/Library/Developer/Xcode/DerivedData/RestTimer-[一串随机字符]/Build/Products/Debug/RestTimer.app
```

## 打包

```bash
# 在 Xcode 中选择 "Product" > "Archive"
# 在打开的 Organizer 窗口中选择 "Distribute App"
# 按照提示导出 .app 文件
```


## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

## 许可证

[MIT License](./LICENSE)

## 致谢

- 感谢所有为这个项目提供建议和帮助的朋友
- 图标来源：[macOS Icons](https://macosicons.com/#/)
