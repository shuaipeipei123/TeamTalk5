# TeamTalk5 服务器端 Ubuntu 22.04 ARM64 编译指南

## 一、项目代码结构分析

TeamTalk5 是 BearWare.dk 开发的跨平台音视频会议 SDK。以下是代码结构概览：

```
TeamTalk5/
├── CMakeLists.txt              # 根 CMake 构建文件 (CMake 3.15+)
├── env.sh                      # 环境变量设置脚本
├── Build/                      # 构建系统入口
│   ├── Makefile                # 跨平台构建 Makefile (ubuntu/android/ios/mac/rasp)
│   ├── build-ubuntu22-arm64.sh # ★ 新增: ARM64 Docker 构建脚本
│   ├── cross-toolchain-aarch64.cmake # ★ 新增: 交叉编译工具链文件
│   └── Docker/                  # Docker 构建环境
│       ├── Dockerfile_ubuntu24
│       ├── Dockerfile_ubuntu26
│       ├── Dockerfile_ubuntu22_arm64  # ★ 新增
│       └── docker-compose.yml
├── Library/                    # 核心库
│   ├── TeamTalkLib/            # C++ 核心源码 (服务器+客户端库)
│   │   ├── teamtalk/server/    # 服务器逻辑 (ServerNode, ServerChannel, ServerUser)
│   │   ├── bin/ttsrv/          # 服务器入口 (Main.cpp, ServerConfig, ServerXML)
│   │   ├── build/              # CMake 构建模块 + ExternalProject 依赖
│   │   └── CMakeLists.txt      # 核心库构建配置 (C++23, 静态链接)
│   ├── TeamTalk_DLL/           # C-API 头文件和输出 DLL
│   ├── TeamTalkJNI/            # Java 绑定
│   ├── TeamTalk.NET/           # C# 绑定
│   └── TeamTalkPy/             # Python 绑定
├── Server/                     # 服务器示例
│   ├── TeamTalkServer/         # C++ 服务器示例 (链接 libTeamTalk5Pro)
│   ├── TeamTalkServer.NET/     # C# 服务器示例 (仅 Windows)
│   └── jTeamTalkServer/        # Java 服务器示例
├── Client/                     # 客户端示例 (Qt, iOS, Android, Python, Rust...)
├── Setup/                      # 安装包配置 (Portable, Installer)
└── .github/workflows/          # CI/CD (ubuntu.yml, android.yml, ios.yml...)
```

### 服务器构建目标

核心库 `TeamTalkLib/CMakeLists.txt` 构建以下服务器可执行文件：

| 目标 | 说明 | 构建选项 |
|------|------|----------|
| `tt5srv` | 标准服务器 (非加密) | `BUILD_TEAMTALK_SERVER_SRVEXE=ON` |
| `tt5prosrv` | 专业服务器 (支持加密) | `BUILD_TEAMTALK_SERVER_SRVEXEPRO=ON` |
| `tt5svc.exe` | Windows NT 服务版 | 仅 MSVC |
| `tt5prosvc.exe` | Windows NT 专业服务版 | 仅 MSVC |

### 服务器依赖链

```
tt5srv / tt5prosrv
  └── ttsrv (ServerConfig, ServerGuard, ServerXML, UPnP, Main)
       └── ttsrvlib (ServerNode, ServerChannel, ServerUser, PacketHandler...)
            └── ttlib → ACE (网络框架) + OpenSSL (加密)
       └── miniupnpc (UPnP NAT 穿越)
       └── tinyxml2 (XML 配置解析)
```

> **重要**: 服务器只需要 ACE + OpenSSL + miniupnpc + tinyxml2 + zlib。
> 不需要 OPUS/Speex/WebRTC/FFmpeg/PortAudio 等客户端编解码和音视频库。

### 构建系统特点

- **ExternalProject 机制**: 所有第三方依赖 (ACE, OpenSSL, OPUS 等) 从 Git 源码编译
- **C++23 标准**: 因 WebRTC 的 std::optional 和 ACE 需要
- **Linux 静态链接**: 默认 `-static-libgcc -static-libstdc++`
- **无自定义 toolchain 文件**: Android 用 NDK 自带 toolchain, iOS/macOS 用 CMake 内建支持

---

## 二、编译方案

提供了两种编译方案，根据你的环境选择：

### 方案 A: Docker + QEMU 模拟（推荐，适用于 Windows）

在 Windows 上通过 Docker Desktop + QEMU 用户模式模拟运行 ARM64 Ubuntu 22.04 容器，在容器内原生编译。

**优点**: 自包含，不依赖 WSL，构建结果即为原生 ARM64 二进制
**缺点**: QEMU 模拟导致编译较慢 (约 30-60 分钟)

#### 前置条件

1. 安装 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. 确保 Docker Desktop 已启用 WSL2 后端
3. Docker Desktop 默认已包含 QEMU binfmt 支持

#### 步骤

```bash
# 在 Git Bash 中执行
cd /d/TeamTalk5/Build
bash build-ubuntu22-arm64.sh
```

脚本会自动完成:
1. 注册 QEMU binfmt 处理器 (支持 ARM64 指令模拟)
2. 构建 Ubuntu 22.04 ARM64 Docker 镜像
3. 在 ARM64 容器内执行 CMake 配置 + Ninja 编译
4. 验证二进制文件
5. 输出到 `Server/ubuntu22-arm64/` 目录

#### 输出

```
D:/TeamTalk5/Server/ubuntu22-arm64/
├── tt5srv       # 标准服务器 (ELF ARM64)
└── tt5prosrv    # 专业服务器 (ELF ARM64, 支持加密)
```

---

### 方案 B: 交叉编译（适用于 x86_64 Linux 主机）

在 x86_64 Linux 上使用 aarch64 交叉编译器编译。

**优点**: 编译速度快 (原生 x86 编译)
**缺点**: 需要配置交叉编译环境，部分依赖可能需要手动处理

#### 前置条件 (x86_64 Ubuntu/Debian)

```bash
# 安装交叉编译器
sudo apt-get install \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    cmake ninja-build pkg-config git autoconf libtool wget xz-utils

# 安装 ARM64 系统库
sudo dpkg --add-architecture arm64
sudo apt-get update
sudo apt-get install libssl-dev:arm64 zlib1g-dev:arm64
```

#### 步骤

```bash
cd TeamTalk5/Build
mkdir build-cross-arm64 && cd build-cross-arm64

cmake -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=../cross-toolchain-aarch64.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DTOOLCHAIN_OPENSSL=OFF \
    -DTOOLCHAIN_ZLIB=OFF \
    -DTOOLCHAIN_LIBVPX=OFF -DTOOLCHAIN_FFMPEG=OFF \
    -DTOOLCHAIN_OGG=OFF -DTOOLCHAIN_OPUS=OFF \
    -DTOOLCHAIN_PORTAUDIO=OFF -DTOOLCHAIN_SPEEX=OFF \
    -DTOOLCHAIN_SPEEXDSP=OFF -DTOOLCHAIN_CATCH2=OFF \
    -DBUILD_TEAMTALK_CLIENTS=OFF -DBUILD_TEAMTALK_DOCUMENTATION=OFF \
    -DBUILD_TEAMTALK_LIBRARIES=OFF -DBUILD_TEAMTALK_LIBRARY_DLL=OFF \
    -DBUILD_TEAMTALK_LIBRARY_DLLPRO=OFF -DBUILD_TEAMTALK_LIBRARY_LIB=OFF \
    -DBUILD_TEAMTALK_LIBRARY_LIBPRO=OFF \
    -DBUILD_TEAMTALK_SERVER_SRVEXE=ON -DBUILD_TEAMTALK_SERVER_SRVEXEPRO=ON \
    -DBUILD_TEAMTALK_LIBRARY_UNITTEST_CATCH2=OFF \
    -DFEATURE_WEBRTC=OFF -DFEATURE_FFMPEG=OFF \
    -DFEATURE_PORTAUDIO=OFF -DFEATURE_V4L2=OFF \
    -DFEATURE_LIBVPX=OFF -DFEATURE_OGG=OFF \
    -DFEATURE_OPUS=OFF -DFEATURE_OPUSTOOLS=OFF \
    -DFEATURE_SPEEX=OFF -DFEATURE_SPEEXDSP=OFF \
    ../../

ninja tt5srv tt5prosrv
```

> **注意**: ACE 库在 Linux 上使用 GNU Make 构建 (非 CMake)，交叉编译时
> 需要确保 `CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++` 环境变量
> 已设置。如果 ACE 构建失败，可尝试 `export CC=aarch64-linux-gnu-gcc` 和
> `export CXX=aarch64-linux-gnu-g++` 后重新构建。

---

### 方案 C: 原生 ARM64 机器编译

如果你有 ARM64 的 Ubuntu 22.04 机器 (如树莓派 4/5、AWS Graviton 等):

```bash
# 安装依赖
cd TeamTalk5/Build
sudo make depend-ubuntu22

# 编译
cd TeamTalk5
source env.sh
make -C Build ubuntu22-arm64

# 或者只编译服务器:
cd Build
mkdir build-release-ubuntu22-arm64 && cd build-release-ubuntu22-arm64
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DTOOLCHAIN_OPENSSL=OFF -DTOOLCHAIN_ZLIB=OFF \
    -DBUILD_TEAMTALK_CLIENTS=OFF -DBUILD_TEAMTALK_DOCUMENTATION=OFF \
    -DBUILD_TEAMTALK_LIBRARIES=OFF \
    -DBUILD_TEAMTALK_LIBRARY_DLL=OFF -DBUILD_TEAMTALK_LIBRARY_DLLPRO=OFF \
    -DBUILD_TEAMTALK_LIBRARY_LIB=OFF -DBUILD_TEAMTALK_LIBRARY_LIBPRO=OFF \
    -DBUILD_TEAMTALK_SERVER_SRVEXE=ON -DBUILD_TEAMTALK_SERVER_SRVEXEPRO=ON \
    -DFEATURE_WEBRTC=OFF -DFEATURE_FFMPEG=OFF \
    -DFEATURE_PORTAUDIO=OFF -DFEATURE_V4L2=OFF \
    -DFEATURE_LIBVPX=OFF -DFEATURE_OGG=OFF \
    -DFEATURE_OPUS=OFF -DFEATURE_OPUSTOOLS=OFF \
    -DFEATURE_SPEEX=OFF -DFEATURE_SPEEXDSP=OFF \
    ../../
ninja tt5srv tt5prosrv
```

---

## 三、运行时依赖

在目标 Ubuntu 22.04 ARM64 机器上运行:

```bash
sudo apt-get install libssl3 zlib1g

# 启动标准服务器
./tt5srv -d

# 启动专业服务器 (加密)
./tt5prosrv -d
```

---

## 四、新增/修改的文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Build/Docker/Dockerfile_ubuntu22_arm64` | 新增 | Ubuntu 22.04 ARM64 Docker 镜像 |
| `Build/Docker/docker-compose.yml` | 修改 | 添加 ubuntu22-arm64 服务 |
| `Build/Makefile` | 修改 | 添加 `ubuntu22`, `ubuntu22-arm64`, `depend-ubuntu22` 目标 |
| `Build/build-ubuntu22-arm64.sh` | 新增 | Docker + QEMU 构建脚本 |
| `Build/cross-toolchain-aarch64.cmake` | 新增 | CMake 交叉编译工具链文件 |
