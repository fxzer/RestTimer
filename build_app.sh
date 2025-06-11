#!/bin/bash

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示信息
echo -e "${YELLOW}开始构建 RestTimer 应用...${NC}"

# 创建构建目录
mkdir -p build

# 清理旧的构建产物
echo -e "${YELLOW}清理旧的构建产物...${NC}"
rm -rf build/*

# 使用 xcodebuild 构建应用
echo -e "${YELLOW}编译应用程序...${NC}"
xcodebuild -project RestTimer.xcodeproj -scheme RestTimer -configuration Release -derivedDataPath ./build

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo -e "\033[0;31m构建失败，请检查错误信息。\033[0m"
    exit 1
fi

# 创建输出目录
mkdir -p ./output

# 复制应用程序到输出目录
echo -e "${YELLOW}打包应用程序...${NC}"
cp -R ./build/Build/Products/Release/RestTimer.app ./output/

# 创建 ZIP 包
cd ./output
zip -r RestTimer.zip RestTimer.app
cd ..

echo -e "${GREEN}构建完成!${NC}"
echo -e "${GREEN}应用程序位于: ${NC}./output/RestTimer.app"
echo -e "${GREEN}ZIP 包位于: ${NC}./output/RestTimer.zip"
echo ""
echo -e "${YELLOW}提示: 如需发布到 GitHub，请按照 RELEASE.md 中的指南操作${NC}" 
