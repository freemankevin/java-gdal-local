ARG JAVA_VERSION=8
ARG GDAL_VERSION=3.4.3

FROM bellsoft/liberica-openjdk-debian:${JAVA_VERSION}-cds

LABEL maintainer="https://github.com/freemankevin/java-gdal-local"
LABEL version="1.0"
LABEL description="Java with GDAL and Java bindings"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV GDAL_DATA=/usr/local/share/gdal
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV CLASSPATH=/usr/local/share/java/gdal.jar

# 设置 JAVA_HOME
RUN JAVA_HOME=$(dirname $(dirname $(find /usr/lib/jvm -type f -name javac))) && \
    echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment && \
    export JAVA_HOME

# 重新声明ARG以在RUN中使用
ARG GDAL_VERSION
ARG JAVA_VERSION

# 安装基础包和依赖
RUN apt-get update && apt-get install -y \
    tzdata \
    curl \
    wget \
    net-tools \
    iputils-ping \
    software-properties-common \
    fonts-noto-cjk \
    python3-setuptools \
    # GDAL依赖库
    libproj-dev \
    libgeos-dev \
    libtiff-dev \
    libgeotiff-dev \
    libcurl4-gnutls-dev \
    libxml2-dev \
    libexpat-dev \
    libxerces-c-dev \
    libnetcdf-dev \
    libpoppler-dev \
    libpoppler-private-dev \
    libspatialite-dev \
    libhdf4-alt-dev \
    libhdf5-serial-dev \
    # 构建工具
    build-essential \
    cmake \
    swig \
    python3-dev \
    python3-numpy \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 验证 JDK 安装
RUN javac -version && java -version

# 下载并编译GDAL
RUN cd /tmp \
    && echo "Downloading GDAL version: ${GDAL_VERSION}" \
    && wget "https://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
    && tar -xzf "gdal-${GDAL_VERSION}.tar.gz" \
    && cd "gdal-${GDAL_VERSION}" \
    && ./configure \
        --with-java=${JAVA_HOME} \
        --with-python \
        --with-geos \
        --with-proj \
        --with-curl \
        --with-xml2 \
        --with-expat \
        --with-xerces \
        --with-netcdf \
        --with-hdf4 \
        --with-hdf5 \
        --with-poppler \
        --with-spatialite \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /tmp/gdal-*

# 验证GDAL安装
RUN gdalinfo --version && echo "GDAL安装成功"

# 设置工作目录
WORKDIR /app

# 创建测试脚本验证Java GDAL绑定
RUN echo 'import org.gdal.gdal.gdal; \
public class GDALTest { \
    public static void main(String[] args) { \
        gdal.AllRegister(); \
        System.out.println("GDAL version: " + gdal.VersionInfo()); \
        System.out.println("Java GDAL bindings loaded successfully!"); \
    } \
}' > /app/GDALTest.java

CMD ["java", "-version"]