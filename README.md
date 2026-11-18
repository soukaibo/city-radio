# 城市电台

macOS 原生 Swift / SwiftUI 网络电台播放器，内置 **1744 个**国内外中文电台，按省份分类，打开即听。

无广告、无追踪、免注册。

## 功能特点

- 内置 1744 个国内外中文电台，按省份分类浏览
- 搜索、收藏、最近播放
- 启动自动续播上次关闭前的电台
- 菜单栏常驻，快捷键 `⌃⌥⌘F` 随时唤出窗口
- 通用二进制（Universal），同时支持 Apple Silicon 与 Intel Mac

## 系统要求

- macOS 13 或更高版本

## 安装

前往 [Releases](https://github.com/soukaibo/city-radio/releases) 下载：

| 文件 | 说明 |
| --- | --- |
| `城市电台-1.0.0.dmg` | 双击打开，把「城市电台」拖入「应用程序」 |
| `城市电台-1.0.0.zip` | 解压后把「城市电台.app」拖入「应用程序」 |

应用未做代码签名，首次打开若提示「无法验证开发者」：

- 在「应用程序」中右键点击「城市电台」→ 打开，确认一次即可；或
- 终端执行：`xattr -cr /Applications/城市电台.app`

## 从源码构建

需要安装 Xcode 命令行工具（`swiftc`、`lipo`、`codesign`）。

```bash
# build.sh 从脚本同级目录读取图标资源，先复制到根目录
cp assets/AppIcon.icns assets/menuicon.png .
./build.sh
```

脚本会分别编译 arm64 与 x86_64 两个架构，并用 `lipo` 合并为通用二进制，产物为 `城市电台.app`。

## 目录结构

```
src/main.swift    应用入口、菜单栏与快捷键
src/Models.swift  数据模型、电台列表加载与播放控制
src/UI.swift      搜索、分类、收藏与播放界面
stations.json     电台数据（1744 条）
assets/           应用图标与菜单栏图标
build.sh          构建脚本
```

## 说明

电台音频流均来自公开网络地址，版权归各电台所有；本应用仅提供播放与整理，不存储、不转发任何音频内容。
