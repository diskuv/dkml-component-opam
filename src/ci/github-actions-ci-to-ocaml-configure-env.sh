#!/bin/sh
# ----------------------------
# Copyright 2022 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# On entry the following non-exported environment variables will be available:
# * DKML_TARGET_ABI. If the ABIs are not android_* then this script will exit with failure.
# * DKMLDIR
#
# As well, on entry the Android Studio environment variables defined at
# https://github.com/actions/virtual-environments/blob/996eae034625eaa62cc81ce29faa04e11fa3e6cc/images/linux/Ubuntu2004-Readme.md#environment-variables-3
# or
# https://github.com/actions/virtual-environments/blob/996eae034625eaa62cc81ce29faa04e11fa3e6cc/images/macos/macos-11-Readme.md#environment-variables-2
# must be available.
#
# DKML's autodetect_compiler() function will have already set common ./configure variables as
# described in https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html. However
# the variables are ignored and overwritten by this script.
#
# On exit the variables needed for github.com/ocaml/ocaml/configure will be set and exported.

# -----------------------------------------------------

set -euf

# shellcheck disable=SC1091
. "$DKMLDIR"/vendor/dkml-runtime-common/unix/crossplatform-functions.sh

# Get BUILDHOST_ARCH
autodetect_buildhost_arch

# -----------------------------------------------------

# Documentation: https://developer.android.com/ndk/guides/other_build_systems

if [ -z "${ANDROID_NDK_LATEST_HOME:-}" ]; then
    printf "FATAL: The ANDROID_NDK_LATEST_HOME environment variable has not been defined. It is ordinarily set on macOS and Linux GitHub Actions hosts.\n" >&2
    exit 107
fi

#   Minimum API
#       The default is 23 but you can override it with the environment
#       variable ANDROID_API.
API=${ANDROID_API:-23}

#   Toolchain
case "$BUILDHOST_ARCH" in
    # HOST_TAG in https://developer.android.com/ndk/guides/other_build_systems#overview
    darwin_x86_64|darwin_arm64) HOST_TAG=darwin-x86_64 ;;
    linux_x86_64)               HOST_TAG=linux-x86_64 ;;
    *)
        printf "FATAL: The build host architecture %s does not have a Android Studio toolchain\n" "$BUILDHOST_ARCH"
        exit 107
esac
TOOLCHAIN=$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/$HOST_TAG

#   Triple
case "$DKML_TARGET_ABI" in
    # TOOLCHAIN_NAME_CLANG 'Triple' in https://developer.android.com/ndk/guides/other_build_systems#overview
    # TOOLCHAIN_NAME_AS     https://chromium.googlesource.com/android_ndk/+/401019bf85744311b26c88ced255cd53401af8b7/build/core/toolchains/aarch64-linux-android-clang/setup.mk#16
    # LLVM_TRIPLE           https://chromium.googlesource.com/android_ndk/+/401019bf85744311b26c88ced255cd53401af8b7/build/core/toolchains/aarch64-linux-android-clang/setup.mk#17
    android_arm64v8a) TOOLCHAIN_NAME_CLANG=aarch64-linux-android ;    TOOLCHAIN_NAME_AS=aarch64-linux-android ; LLVM_TRIPLE=aarch64-none-linux-android ;;
    android_arm32v7a) TOOLCHAIN_NAME_CLANG=armv7a-linux-androideabi ; TOOLCHAIN_NAME_AS=arm-linux-androideabi ; LLVM_TRIPLE=armv7-none-linux-androideabi ;;
    android_x86)      TOOLCHAIN_NAME_CLANG=i686-linux-android ;       TOOLCHAIN_NAME_AS=i686-linux-android ;    LLVM_TRIPLE=i686-none-linux-android;;
    android_x86_64)   TOOLCHAIN_NAME_CLANG=x86_64-linux-android ;     TOOLCHAIN_NAME_AS=x86_64-linux-android ;  LLVM_TRIPLE=x86_64-none-linux-android ;;
    *)
        printf "FATAL: The DKML_TARGET_ABI must be an DKML Android ABI, not %s\n" "$DKML_TARGET_ABI" >&2
        exit 107
        ;;
esac

#   Exports necessary for OCaml's ./configure
#       https://developer.android.com/ndk/guides/other_build_systems#autoconf
find "$TOOLCHAIN/bin" -type f -name '*-clang' # Show API versions for debugging
find "$TOOLCHAIN/bin" -type f -name '*-as'    # More debugging
#       Dump of Android NDK r23 flags. And -g3 and -g for debugging.
_android_cflags="-fPIE -fPIC -DANDROID -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fexceptions -g3 -g  -fno-limit-debug-info"
export AR="$TOOLCHAIN/bin/llvm-ar"
export CC="$TOOLCHAIN/bin/$TOOLCHAIN_NAME_CLANG$API-clang"
! [ -x "$CC" ] && printf "FATAL: No clang compiler at %s\n" "$CC" >&2 && exit 107
export LD="$TOOLCHAIN/bin/ld"
export DIRECT_LD="$LD"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export NM="$TOOLCHAIN/bin/llvm-nm"
export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"
export CFLAGS="$_android_cflags"
export LDFLAGS=
#       Android NDK comes with a) a Clang compiler and b) a GNU AS assembler and c) sometimes a YASM assembler
#       in its bin folder
#       (ex. ndk/23.1.7779620/toolchains/llvm/prebuilt/linux-x86_64/bin/{clang,arm-linux-androideabi-as,yasm}).
#
#       The GNU AS assembler (https://sourceware.org/binutils/docs/as/index.html) does not support preprocessing
#       so it cannot be used as the `ASPP` ./configure variable.
export AS="$TOOLCHAIN/bin/$TOOLCHAIN_NAME_AS-as"
! [ -x "$AS" ] && printf "FATAL: No assembler at %s\n" "$AS" >&2 && exit 107
export ASPP="$TOOLCHAIN/bin/clang --target=$LLVM_TRIPLE$API $_android_cflags -c"
