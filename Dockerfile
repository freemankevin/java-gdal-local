# 构建阶段
FROM bellsoft/liberica-openjdk-debian:8-cds AS builder
ARG GDAL_VERSION=3.8.5
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/jdk-8u462-bellsoft-x86_64

# 使用国内镜像源加速 apt-get
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libproj-dev \
        libgeos-dev \
        libtiff-dev \
        libgeotiff-dev \
        libcurl4-gnutls-dev \
        libxml2-dev \
        libexpat-dev \
        libzstd-dev \
        default-jdk-headless \
        ant \
        build-essential \
        cmake \
        swig \
        python3-dev \
        python3-numpy \
        python3-setuptools \
        wget \
        pkg-config \
        bison \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 下载并解压 GDAL 源码，添加错误检查
RUN cd /tmp \
    && wget --no-check-certificate "https://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
    && [ -f "gdal-${GDAL_VERSION}.tar.gz" ] || { echo "Failed to download GDAL source"; exit 1; } \
    && tar -xzf "gdal-${GDAL_VERSION}.tar.gz" \
    && [ -d "gdal-${GDAL_VERSION}" ] || { echo "Failed to extract GDAL source"; exit 1; }

# 使用 CMake 编译 GDAL，修复 Java 路径配置
RUN cd /tmp/gdal-${GDAL_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_JAVA_BINDINGS=ON \
        -DJAVA_HOME=${JAVA_HOME} \
        -DJava_JAR_EXECUTABLE=${JAVA_HOME}/bin/jar \
        -DJava_JAVAC_EXECUTABLE=${JAVA_HOME}/bin/javac \
        -DJava_JAVAH_EXECUTABLE=${JAVA_HOME}/bin/javah \
        -DJava_JAVADOC_EXECUTABLE=${JAVA_HOME}/bin/javadoc \
        -DJAVA_INCLUDE_PATH=${JAVA_HOME}/include \
        -DJAVA_INCLUDE_PATH2=${JAVA_HOME}/include/linux \
        -DGDAL_ENABLE_DRIVER_OPENFILEGDB=ON \
        -DGDAL_USE_PROJ=ON \
        -DGDAL_USE_GEOS=ON \
        -DGDAL_USE_GEOTIFF=ON \
        -DGDAL_USE_CURL=ON \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /tmp/gdal-*

# 运行时阶段
FROM bellsoft/liberica-openjdk-debian:8-cds
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV GDAL_DATA=/usr/local/share/gdal
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV CLASSPATH="/usr/local/share/java/gdal.jar"
ENV JAVA_HOME=/usr/lib/jvm/jdk-8u462-bellsoft-x86_64

# 安装运行时依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libproj25 \
        libgeos-c1v5 \
        libtiff6 \
        libgeotiff5 \
        libcurl4 \
        libxml2 \
        libexpat1 \
        libzstd1 \
        ca-certificates \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 从构建阶段复制编译结果
COPY --from=builder /usr/local /usr/local

# 确保库文件可以找到
RUN ldconfig

# 验证 GDAL 安装
RUN gdalinfo --version && echo "GDAL安装成功"

WORKDIR /app

# 创建测试文件
RUN echo 'import org.gdal.gdal.gdal; \
public class GDALTest { \
    public static void main(String[] args) { \
        try { \
            gdal.AllRegister(); \
            System.out.println("GDAL version: " + gdal.VersionInfo()); \
            System.out.println("Java GDAL bindings loaded successfully!"); \
        } catch (UnsatisfiedLinkError e) { \
            System.err.println("Failed to load GDAL native library: " + e.getMessage()); \
            System.err.println("Library path: " + System.getProperty("java.library.path")); \
        } catch (Exception e) { \
            System.err.println("Error: " + e.getMessage()); \
        } \
    } \
}' > /app/GDALTest.java

CMD ["java", "-version"]