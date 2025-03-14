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

## 构建应用

### 方法一：使用Xcode界面构建

1. **打开项目**：
   - 双击`RestTimer.xcodeproj`文件在Xcode中打开项目

2. **选择正确的构建配置**：
   - 在Xcode顶部工具栏中，确保选择了"My Mac"作为目标设备
   - 确保选择了"Release"配置（如果要发布应用）或"Debug"配置（如果只是测试）

3. **构建应用**：
   - 在Xcode顶部菜单中，点击"Product" > "Build"（或使用快捷键⌘B）
   - 等待构建过程完成，状态栏会显示"Build Succeeded"

4. **找到构建好的.app文件**：
   - 在Xcode顶部菜单中，点击"Product" > "Show Build Folder in Finder"
   - 在打开的Finder窗口中，导航到"Products/Release/"或"Products/Debug/"文件夹
   - 在这里你可以找到`RestTimer.app`文件

### 方法二：使用命令行构建

如果你更喜欢使用命令行，可以按照以下步骤操作：

1. **打开终端**

2. **导航到项目目录**：
   ```bash
   cd /path/to/RestTimer
   ```

3. **使用xcodebuild命令构建项目**：
   ```bash
   xcodebuild -project RestTimer.xcodeproj -scheme RestTimer -configuration Release build
   ```

4. **找到构建好的.app文件**：
   构建完成后，.app文件通常位于：
   ```
   ./build/Release/RestTimer.app
   ```
   或者在DerivedData目录中：
   ```
   ~/Library/Developer/Xcode/DerivedData/RestTimer-随机字符串/Build/Products/Release/RestTimer.app
   ```

### 使用构建好的.app文件

1. **测试运行**：
   - 双击.app文件即可运行应用程序

2. **安装到应用程序文件夹**：
   - 将构建好的.app文件拖放到`/Applications`文件夹中

3. **创建DMG安装包**（可选）：
   - 如果你想分发应用，可以创建一个DMG文件
   - 在Finder中，选择"文件" > "新建磁盘映像" > "空白映像"
   - 创建一个合适大小的DMG
   - 将.app文件和一个指向Applications文件夹的快捷方式拖入DMG中
   - 弹出DMG并重新打开，调整布局和背景
   - 再次弹出，然后在Finder中选择"文件" > "新建磁盘映像" > "从'卷名'创建映像"

### 注意事项

1. 确保项目没有编译错误
2. 如果应用需要特殊权限，确保在Info.plist中正确配置了相关权限
3. 如果是第一次在Mac上运行自己构建的应用，可能需要在"系统偏好设置" > "安全性与隐私"中允许运行

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

## 许可证

[MIT License](./LICENSE)

## 致谢

- 感谢所有为这个项目提供建议和帮助的朋友
- 图标来源：[macOS Icons](https://macosicons.com/#/)
