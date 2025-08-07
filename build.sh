#!/bin/bash

# Java GDAL Docker 构建脚本
# 使用方法: ./build.sh [GDAL_VERSION] [JAVA_VERSION] [IMAGE_NAME]

set -e

# 默认参数
GDAL_VERSION=${1:-"3.4.3"}
JAVA_VERSION=${2:-"8"}
IMAGE_NAME=${3:-"freelabspace/java-gdal"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Java GDAL Docker Image Builder${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}GDAL Version:${NC} ${GDAL_VERSION}"
echo -e "${GREEN}Java Version:${NC} ${JAVA_VERSION}"
echo -e "${GREEN}Image Name:${NC} ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION}"
echo -e "${BLUE}========================================${NC}"

# 检查Docker是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker未安装或不可用${NC}"
    exit 1
fi

# 检查GDAL版本是否有效（简单的格式检查）
if [[ ! $GDAL_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}错误: GDAL版本格式无效，应为 x.y.z 格式${NC}"
    exit 1
fi

# 检查Java版本是否支持
case $JAVA_VERSION in
    8|11|17|21)
        echo -e "${GREEN}✓ Java版本支持${NC}"
        ;;
    *)
        echo -e "${RED}错误: 不支持的Java版本。支持的版本: 8, 11, 17, 21${NC}"
        exit 1
        ;;
esac

# 构建镜像
echo -e "${YELLOW}开始构建Docker镜像...${NC}"
docker build \
    --build-arg GDAL_VERSION=${GDAL_VERSION} \
    --build-arg JAVA_VERSION=${JAVA_VERSION} \
    --tag ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION} \
    --tag ${IMAGE_NAME}:latest \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 构建成功!${NC}"
    
    # 测试镜像
    echo -e "${YELLOW}测试镜像...${NC}"
    echo -e "${BLUE}Java版本:${NC}"
    docker run --rm ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION} java -version
    
    echo -e "${BLUE}GDAL版本:${NC}"
    docker run --rm ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION} gdalinfo --version
    
    echo -e "${GREEN}✓ 所有测试通过!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}镜像构建完成:${NC}"
    echo -e "  ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION}"
    echo -e "  ${IMAGE_NAME}:latest"
    echo -e "${BLUE}========================================${NC}"
    
    # 显示镜像大小
    echo -e "${BLUE}镜像大小:${NC}"
    docker images ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION}
    
else
    echo -e "${RED}✗ 构建失败${NC}"
    exit 1
fi

# 询问是否运行交互式容器
read -p "是否要启动交互式容器进行测试？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}启动交互式容器...${NC}"
    docker run -it --rm ${IMAGE_NAME}:java${JAVA_VERSION}-gdal${GDAL_VERSION} bash
fi