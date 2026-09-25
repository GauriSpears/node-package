#!/usr/bin/env bash
set -euo pipefail

NODE_SHA="${NODE_SHA:?}"
BUILD_ID="${BUILD_ID:-${NODE_SHA:0:12}}"
DISTRO="${DISTRO:?}"
DISTRO_VERSION="${DISTRO_VERSION:-}"
BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/node-src"
NODE_BIN="$SRC_DIR/out/Release/node"
OUT="${OUT_DIR:-$(pwd)/out}"
PREFIX="${PREFIX:-/usr}"
# Version string for packages: YYYY.mm.dd-<sha12> (valid enough for fpm/dpkg)
VERSION="${VERSION:-$(date +'%Y.%m.%d')-${NODE_SHA:0:12}}"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) DEB_ARCH=amd64; RPM_ARCH=x86_64 ;;
  aarch64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;;
  *) DEB_ARCH="$ARCH"; RPM_ARCH="$ARCH" ;;
esac

mkdir -p "$OUT"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

echo "==> Staging into $STAGE$PREFIX"
make -C "$SRC_DIR" install DESTDIR="$STAGE" PREFIX="$PREFIX" || true
install -Dm755 "$NODE_BIN" "$STAGE$PREFIX/bin/node"

PKG_NAME="nodejs-shared"
DESCRIPTION="Node.js main@${NODE_SHA:0:12} built with --shared-openssl"

package_deb() {
  local suite="${DISTRO_VERSION:-unknown}"
  DEPS=$(objdump -p "$NODE_BIN" | grep -oP 'NEEDED\s+\K\S+' | while read -r lib; do
      path=$(ldd "$NODE_BIN" | grep -oP "$lib => \K\S+" || true)
      if [ -n "$path" ] && [ "$path" != "not" ]; then
        real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
        dpkg -S "$real_path" 2>/dev/null | cut -d: -f1
      fi
    done | sort -u | paste -sd ',' -)
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t deb -n "$PKG_NAME" -v "$VERSION" \
      -a "$DEB_ARCH" --description "$DESCRIPTION" --url "https://github.com/GauriSpears/nodejs-package" \
      --depends "$DEPS" -C "$STAGE" usr
    for f in ${PKG_NAME}_*.deb; do mv -f "$f" "$OUT/${f%_${DEB_ARCH}.deb}-debian-${suite}_${DEB_ARCH}.deb"; done
  fi
  if ! ls "$OUT"/*.deb >/dev/null 2>&1; then
    mkdir -p "$STAGE/DEBIAN"
    local size; size=$(du -sk "$STAGE/usr" 2>/dev/null | awk '{print $1}')
    cat > "$STAGE/DEBIAN/control" <<CTRL
Package: $PKG_NAME
Version: $VERSION
Section: libs
Priority: optional
Architecture: $DEB_ARCH
Maintainer: nodejs-package CI <ci@localhost>
Depends: $DEPS
Installed-Size: ${size:-1}
Description: $DESCRIPTION
CTRL
    dpkg-deb --build "$STAGE" "$OUT/${PKG_NAME}_${VERSION}-debian-${suite}_${DEB_ARCH}.deb"
  fi
}

package_rpm() {
  local el="${DISTRO_VERSION:-el}"
  DEPS=$(objdump -p "$NODE_BIN" | grep -oP 'NEEDED\s+\K\S+' | while read -r lib; do
      path=$(ldd "$NODE_BIN" | grep -oP "$lib => \K\S+" || true)
      if [ -n "$path" ] && [ "$path" != "not" ]; then
        real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
        rpm -qf "$real_path" 2>/dev/null | sed 's/-[0-9].*//'
      fi
    done | sort -u | paste -sd ', ' -)
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t rpm -n "$PKG_NAME" -v "$VERSION" --iteration 1 \
      -a "$RPM_ARCH" --description "$DESCRIPTION" --depends "$DEPS" \
      -C "$STAGE" usr
    for f in ${PKG_NAME}-*.rpm; do mv -f "$f" "$OUT/${f%.${RPM_ARCH}.rpm}-almalinux_${el}.${RPM_ARCH}.rpm"; done
  fi
  if ! ls "$OUT"/*.rpm >/dev/null 2>&1; then
    tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-${VERSION}-1-almalinux_${el}.${RPM_ARCH}.tar.gz" usr
  fi
}

package_arch() {
  DEPS=$(objdump -p "$NODE_BIN" | grep -oP 'NEEDED\s+\K\S+' | while read -r lib; do
      path=$(ldd "$NODE_BIN" | grep -oP "$lib => \K\S+" || true)
      if [ -n "$path" ] && [ "$path" != "not" ]; then
        real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
        pacman -Qo "$real_path" 2>/dev/null | awk '{print $5}'
      fi
    done | sort -u | paste -sd ', ' -)
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t pacman -n "$PKG_NAME" -v "$VERSION" \
      -a "$ARCH" --description "$DESCRIPTION" --depends "$DEPS" -C "$STAGE" usr
    for f in ${PKG_NAME}-*.pkg.tar*; do mv -f "$f" "$OUT/${f%-${ARCH}.pkg.tar.zst}-arch-rolling-${ARCH}.pkg.tar.zst"; done
  fi
  if ! ls "$OUT"/${PKG_NAME}-* >/dev/null 2>&1; then
    if command -v zstd >/dev/null; then
      tar -C "$STAGE" -cf - usr | zstd -o "$OUT/${PKG_NAME}-${VERSION}-arch-rolling-${ARCH}.tar.zst"
    else
      tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-${VERSION}-arch-rolling-${ARCH}.tar.gz" usr
    fi
  fi
}

case "$DISTRO" in
  debian|ubuntu) package_deb ;;
  almalinux|rhel|fedora|centos) package_rpm ;;
  arch|archlinux) package_arch ;;
  *) tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-${BUILD_ID}-${DISTRO}-${ARCH}.tar.gz" usr ;;
esac

ls -la "$OUT"
exit 0
