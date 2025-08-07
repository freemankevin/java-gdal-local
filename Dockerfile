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
        libjni-dev \
        build-essential \
        cmake \
        swig \
        python3-dev \
        python3-numpy \
        python3-setuptools \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 下载并解压 GDAL 源码，添加错误检查
RUN cd /tmp \
    && wget --no-check-certificate "https://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
    && [ -f "gdal-${GDAL_VERSION}.tar.gz" ] || { echo "Failed to download GDAL source"; exit 1; } \
    && tar -xzf "gdal-${GDAL_VERSION}.tar.gz" \
    && [ -d "gdal-${GDAL_VERSION}" ] || { echo "Failed to extract GDAL source"; exit 1; }

# 使用 CMake 编译 GDAL
RUN cd /tmp/gdal-${GDAL_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_JAVA_BINDINGS=ON \
        -DJava_JAR_EXECUTABLE=${JAVA_HOME}/bin/jar \
        -DJava_JAVAC_EXECUTABLE=${JAVA_HOME}/bin/javac \
        -DJava_JAVAH_EXECUTABLE=${JAVA_HOME}/bin/javah \
        -DJava_JAVADOC_EXECUTABLE=${JAVA_HOME}/bin/javadoc \
        -DGDAL_ENABLE_DRIVER_OPENFILEGDB=ON \
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
ENV CLASSPATH=/usr/local/share/java/gdal.jar
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# 使用国内镜像源
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
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY --from=builder /usr/local /usr/local

# 验证 GDAL 安装
RUN gdalinfo --version && echo "GDAL安装成功"

WORKDIR /app
RUN echo 'import org.gdal.gdal.gdal; \
public class GDALTest { \
    public static void main(String[] args) { \
        gdal.AllRegister(); \
        System.out.println("GDAL version: " + gdal.VersionInfo()); \
        System.out.println("Java GDAL bindings loaded successfully!"); \
    } \
}' > /app/GDALTest.java

CMD ["java", "-version"]