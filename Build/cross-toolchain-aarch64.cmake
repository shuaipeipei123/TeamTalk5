# CMake toolchain file for cross-compiling TeamTalk5 server for Ubuntu 22.04 ARM64
# on an x86_64 Linux host.
#
# Prerequisites (on x86_64 Ubuntu/Debian host):
#   sudo apt-get install \
#       gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
#       cmake ninja-build pkg-config
#   # ARM64 system libraries (for linking):
#   sudo dpkg --add-architecture arm64
#   sudo apt-get update
#   sudo apt-get install:arm64 libssl-dev:arm64 zlib1g-dev:arm64
#
# Usage:
#   cd TeamTalk5/Build
#   mkdir build-cross-arm64 && cd build-cross-arm64
#   cmake -G Ninja \
#       -DCMAKE_TOOLCHAIN_FILE=../cross-toolchain-aarch64.cmake \
#       -DCMAKE_BUILD_TYPE=Release \
#       -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
#       -DTOOLCHAIN_OPENSSL=OFF \
#       -DTOOLCHAIN_ZLIB=OFF \
#       -DTOOLCHAIN_LIBVPX=OFF -DTOOLCHAIN_FFMPEG=OFF \
#       -DTOOLCHAIN_OGG=OFF -DTOOLCHAIN_OPUS=OFF \
#       -DTOOLCHAIN_PORTAUDIO=OFF -DTOOLCHAIN_SPEEX=OFF \
#       -DTOOLCHAIN_SPEEXDSP=OFF -DTOOLCHAIN_CATCH2=OFF \
#       -DBUILD_TEAMTALK_CLIENTS=OFF -DBUILD_TEAMTALK_DOCUMENTATION=OFF \
#       -DBUILD_TEAMTALK_LIBRARIES=OFF -DBUILD_TEAMTALK_LIBRARY_DLL=OFF \
#       -DBUILD_TEAMTALK_LIBRARY_DLLPRO=OFF -DBUILD_TEAMTALK_LIBRARY_LIB=OFF \
#       -DBUILD_TEAMTALK_LIBRARY_LIBPRO=OFF \
#       -DBUILD_TEAMTALK_SERVER_SRVEXE=ON -DBUILD_TEAMTALK_SERVER_SRVEXEPRO=ON \
#       -DBUILD_TEAMTALK_LIBRARY_UNITTEST_CATCH2=OFF \
#       -DFEATURE_WEBRTC=OFF -DFEATURE_FFMPEG=OFF \
#       -DFEATURE_PORTAUDIO=OFF -DFEATURE_V4L2=OFF \
#       -DFEATURE_LIBVPX=OFF -DFEATURE_OGG=OFF \
#       -DFEATURE_OPUS=OFF -DFEATURE_OPUSTOOLS=OFF \
#       -DFEATURE_SPEEX=OFF -DFEATURE_SPEEXDSP=OFF \
#       ../../
#   ninja tt5srv tt5prosrv
#

# Target system
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Cross compilers
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

# Target root filesystem (for finding ARM64 libraries)
set(CMAKE_SYSROOT /usr/aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu)

# Search paths
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Let pkg-config find ARM64 libraries
set(ENV{PKG_CONFIG_PATH} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "/")
