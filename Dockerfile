# qBittorrent, OpenVPN and WireGuard, qbittorrentvpn
FROM ubuntu:jammy

LABEL org.opencontainers.image.authors="ghost@ghosthacker.com"
LABEL org.opencontainers.image.version="4.5.0"
LABEL org.opencontainers.image.description="qBittorrent, OpenVPN and WireGuard"
LABEL org.opencontainers.image.title="qBittorrentVPN"

ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.1.3.0

WORKDIR /opt

RUN usermod -u 99 nobody

# Make directories and install common packages
RUN mkdir -p /downloads /config/qBittorrent /etc/openvpn /etc/qbittorrent \
    && apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg2 \
        iproute2 \
        lsb-release \
        p7zip-full \
        tar \
        unrar \
        unzip \
        wget \
        xz-utils \
        zip \    
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Install s6-overlay
RUN case ${TARGETARCH} in \
        arm|arm/v7) ARCH="armf" ;; \
        arm/v6) ARCH="arm" ;; \
        arm64|arm/v8) ARCH="aarch64" ;; \
        386) ARCH="x86" ;; \
        amd64) ARCH="x86_64" ;; \
    esac \
    && wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && wget -P /tmp https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-${ARCH}.tar.xz \
    && apt -y purge \
        ca-certificates \
        xz-utils \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*    

# Install boost
RUN apt update \
    && apt upgrade -y  \
    && apt install -y --no-install-recommends \
        ca-certificates \
        g++ \
        libxml2-utils \
    && BOOST_VERSION_DOT=$(curl -sX GET "https://www.boost.org/feed/news.rss" | xmllint --xpath '//rss/channel/item/title/text()' - | awk -F 'Version' '{print $2 FS}' - | sed -e 's/Version//g;s/\ //g' | xargs | awk 'NR==1{print $1}' -) \
    && BOOST_VERSION=$(echo ${BOOST_VERSION_DOT} | head -n 1 | sed -e 's/\./_/g') \
    && curl -o /opt/boost_${BOOST_VERSION}.tar.gz -L https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.gz \
    && tar -xzf /opt/boost_${BOOST_VERSION}.tar.gz -C /opt \
    && cd /opt/boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=/usr \
    && ./b2 --prefix=/usr install \
    && cd /opt \
    && rm -rf /opt/* \
    && apt -y purge \
        ca-certificates \
        g++ \
        libxml2-utils \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Install Ninja
RUN apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
        ca-certificates \
        jq \
    && NINJA_ASSETS=$(curl -sX GET "https://api.github.com/repos/ninja-build/ninja/releases" | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"') \
    && NINJA_DOWNLOAD_URL=$(curl -sX GET ${NINJA_ASSETS} | jq '.[] | select(.name | match("ninja-linux";"i")) .browser_download_url' | tr -d '"') \
    && curl -o /opt/ninja-linux.zip -L ${NINJA_DOWNLOAD_URL} \
    && unzip /opt/ninja-linux.zip -d /opt \
    && mv /opt/ninja /usr/local/bin/ninja \
    && chmod +x /usr/local/bin/ninja \
    && rm -rf /opt/* \
    && apt purge -y \
        ca-certificates \
        jq \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Install cmake
RUN case ${TARGETARCH} in \
        arm|arm/v7) ARCH="armf" ;; \
        arm/v6) ARCH="arm" ;; \
        arm64|arm/v8) ARCH="aarch64" ;; \
        386) ARCH="x86" ;; \
        amd64) ARCH="x86_64" ;; \
    esac \
    && apt update \
    && apt upgrade -y \
    && apt install -y  --no-install-recommends \
        ca-certificates \
        jq \
    && CMAKE_ASSETS=$(curl -sX GET "https://api.github.com/repos/Kitware/CMake/releases" | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"') \
    && CMAKE_DOWNLOAD_URL=$(curl -sX GET ${CMAKE_ASSETS} | jq '.[] | select(.name | match("Linux-'${ARCH}'.sh";"i")) .browser_download_url' | tr -d '"') \
    && curl -o /opt/cmake.sh -L ${CMAKE_DOWNLOAD_URL} \
    && chmod +x /opt/cmake.sh \
    && /bin/bash /opt/cmake.sh --skip-license --prefix=/usr \
    && rm -rf /opt/* \
    && apt purge -y \
        ca-certificates \
        jq \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Compile and install libtorrent-rasterbar
RUN apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        jq \
        libssl-dev \
    && LIBTORRENT_ASSETS=$(curl -sX GET "https://api.github.com/repos/arvidn/libtorrent/releases" | jq '.[] | select(.prerelease==false) | select(.target_commitish=="RC_2_0") | .assets_url' | head -n 1 | tr -d '"') \
    && LIBTORRENT_DOWNLOAD_URL=$(curl -sX GET ${LIBTORRENT_ASSETS} | jq '.[0] .browser_download_url' | tr -d '"') \
    && LIBTORRENT_NAME=$(curl -sX GET ${LIBTORRENT_ASSETS} | jq '.[0] .name' | tr -d '"') \
    && curl -o /opt/${LIBTORRENT_NAME} -L ${LIBTORRENT_DOWNLOAD_URL} \
    && tar -xzf /opt/${LIBTORRENT_NAME} \
    && rm /opt/${LIBTORRENT_NAME} \
    && cd /opt/libtorrent-rasterbar* \
    && cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/* \
    && apt purge -y \
        build-essential \
        ca-certificates \
        jq \
        libssl-dev \
    && apt-get clean \
    && apt --purge autoremove -y  \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Compile and install qBittorrent
RUN apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        jq \
        libssl-dev \
        pkg-config \
        qtbase5-dev \
        qttools5-dev \
        zlib1g-dev \
    && QBITTORRENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/qBittorrent/qBittorrent/tags" | jq '.[] | select(.name | index ("alpha") | not) | select(.name | index ("beta") | not) | select(.name | index ("rc") | not) | .name' | head -n 1 | tr -d '"') \
    && curl -o /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz -L "https://github.com/qbittorrent/qBittorrent/archive/${QBITTORRENT_RELEASE}.tar.gz" \
    && tar -xzf /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && rm /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && cd /opt/qBittorrent-${QBITTORRENT_RELEASE} \
    && cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DGUI=OFF -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/* \
    && apt purge -y \
        build-essential \
        ca-certificates \
        git \
        jq \
        libssl-dev \
        pkg-config \
        qtbase5-dev \
        qttools5-dev \
        zlib1g-dev \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Install Jackett
RUN case ${TARGETARCH} in \
        arm|arm/v6|arm/v7) ARCH="ARM32" ;; \
        arm64|arm/v8) ARCH="ARM64" ;; \
        amd64) ARCH="AMDx64" ;; \
    esac \
    && apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
        ca-certificates \
    && cd /opt \
    && f=Jackett.Binaries.Linux${ARCH}.tar.gz \
    && release=$(wget -q https://github.com/Jackett/Jackett/releases/latest -O - | grep "title>Release" | cut -d " " -f 4) \
    && wget -Nc https://github.com/Jackett/Jackett/releases/download/$release/"$f" \
    && tar -xzf "$f" \
    && chown -R root:root /opt/Jackett \
    && rm -f "$f" \
    && apt purge -y \
        ca-certificates \
    && apt-get clean \
    && apt --purge autoremove -y \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Install WireGuard and some other dependencies some of the scripts in the container rely on.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0E98404D386FA1D9 \
    && echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable-wireguard.list \
    && printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable \
    && apt update \
    && apt install -y --no-install-recommends \
        ca-certificates \
        dos2unix \
        inetutils-ping \
        ipcalc \
        iptables \
        kmod \
        libqt5network5 \
        libqt5xml5 \
        libqt5sql5 \
        libssl3 \
        moreutils \
        net-tools \
        openresolv \
        openvpn \
        procps \
        wireguard-tools \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Remove src_valid_mark from wg-quick
RUN sed -i /net\.ipv4\.conf\.all\.src_valid_mark/d `which wg-quick`

VOLUME /config /downloads

ADD openvpn/ /etc/openvpn/
ADD qbittorrent/ /etc/qbittorrent/
ADD root/ /

RUN chmod +x /etc/qbittorrent/*.sh /etc/qbittorrent/*.init /etc/openvpn/*.sh /healthcheck.sh

EXPOSE 8080
EXPOSE 8999
EXPOSE 8999/udp
EXPOSE 9117

# ENTRYPOINT [ "/init" ]
CMD ["/bin/bash", "/etc/openvpn/start.sh"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 CMD /healthcheck.sh || exit 1
