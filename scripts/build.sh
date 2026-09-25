#!/usr/bin/env bash
# Clone nodejs/node at NODE_SHA (main HEAD), cmake, build.
set -euo pipefail

NODE_SHA="${NODE_SHA:?set NODE_SHA (full git commit on nodejs/node)}"
BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/node-src"

if [ "${GETPM}" == "dnf" ]; then
  if ls /opt/rh/gcc-toolset-*/enable >/dev/null 2>&1; then
    source $(ls -1 /opt/rh/gcc-toolset-*/enable | sort -V | tail -1)
  fi
fi

LIBSSLPATH=""
for candidate in \
  /usr/lib64/libssl.so \
  /usr/lib/x86_64-linux-gnu/libssl.so \
  /usr/lib/libssl.so \
  /usr/lib/*/libssl.so
do
  if [[ -e "$candidate" ]]; then
    LIBSSLPATH=$(dirname "$candidate")
    break
  fi
done
if [ -z "$LIBSSLPATH" ]; then
  echo "ERROR: could not find libssl.so" >&2
  exit 1
fi

mkdir -p "$BUILD_ROOT"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "==> Cloning nodejs/node"
  git clone --filter=blob:none --no-checkout https://github.com/nodejs/node.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --depth=1 origin "$NODE_SHA" 2>/dev/null \
  || git fetch --depth=1 origin main
git checkout --force "$NODE_SHA" 2>/dev/null \
  || { git fetch --depth=50 origin main; git checkout --force "$NODE_SHA" 2>/dev/null; } \
  || git checkout --force main

echo "==> Building commit $(git rev-parse HEAD)"
echo "==> Configuring --shared-openssl"
./configure --shared-openssl --shared-openssl-libpath="$LIBSSLPATH" --shared-openssl-includes=/usr/include
echo "==> Building"
make
echo "==> Build finished"
./out/Release/node -p "process.versions"
exit 0
