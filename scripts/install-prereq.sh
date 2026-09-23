#!/bin/sh
SCRIPT_DIR="$( cd "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" && pwd )"
. "$SCRIPT_DIR/hardupdate"
#New installation or upgrade.
isupg=${isupg:-true}
GETPM=${GETPM:?}

if [ "${GETPM}" == "apt-get" ]; then
  apt-get update -y
  apt-get install -y ca-certificates
  cat > /etc/apt/sources.list.d/gku.list << 'EOF'
deb https://deb.debian.org/debian experimental main
deb https://deb.debian.org/debian unstable main
deb https://deb.debian.org/debian testing main
EOF
  sed -i 's/^[[:space:]]*//' /etc/apt/sources.list.d/gku.list
  cat > /etc/apt/preferences.d/gku.pref << 'EOF'
Package: *
Pin: release a=testing
Pin-Priority: -1

Package: *
Pin: release a=unstable
Pin-Priority: -1

Package: *
Pin: release a=experimental
Pin-Priority: -1
EOF
  sed -i 's/^[[:space:]]*//' /etc/apt/preferences.d/gku.pref
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  sh -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
  apt update -y
  apt-get update -y
  apt-get install -y build-essential autoconf automake libtool git
  hash -r
  if ! $isupg; then
    rm -rf /usr/local/ssl/share/man/man1/*.1ossl
    rm -rf /usr/local/ssl/share/man/man3/*.3ossl
    rm -rf /usr/local/ssl/share/man/man7/*.7ossl
    rm -rf /usr/local/ssl/share/doc/openssl
    rm -rf /usr/local/ssl/bin
    rm -rf /usr/local/ssl/include
    rm -rf /usr/local/ssl/lib
    rm -rf /root/openssl
    rm -rf /usr/bin/openssl
    getpack "openssl libssl-dev" 2 reinstall
  else
    getpack "openssl libssl-dev" 2 install
  fi
  OPENSSLDIR=$(openssl version -a 2>/dev/null | sed -n 's/.*OPENSSLDIR: "\([^"]*\)".*/\1/p' || true)
  if ! grep -q '^\s*\[nodejs_init\]' ${OPENSSLDIR}/openssl.cnf; then
    cat >> ${OPENSSLDIR}/openssl.cnf << 'EOF'

[nodejs_init]
providers = provider_node_sect

[provider_node_sect]
gostprov = gostprov_sect
default = gostprov_sect

[gostprov_sect]
activate = 1
EOF
  fi
  if ! $isupg; then
    rm -rf /usr/local/doc/cmake-*
    rm -rf /usr/local/bin/ccmake
    rm -rf /usr/local/bin/cmake
    rm -rf /usr/local/bin/ctest
    rm -rf /usr/local/bin/cpack
    rm -rf /usr/local/share/cmake-*
    rm -rf /usr/local/share/vim/vimfiles/indent/cmake.vim
    rm -rf /usr/local/share/vim/vimfiles/syntax/cmake.vim
    rm -rf /usr/local/share/emacs/site-lisp/cmake-mode.el
    rm -rf /usr/local/share/aclocal/cmake.m4
    rm -rf /usr/local/share/bash-completion/completions/cmake
    rm -rf /usr/local/share/bash-completion/completions/cpack
    rm -rf /usr/local/share/bash-completion/completions/ctest
    hash -r
    getpack cmake 3 reinstall
  else
    getpack cmake 3 install
  fi
elif [ "${GETPM}" == "pacman" ]; then
  pacman-key --init
  pacman -Syu --noconfirm
  pacman -Sy --needed --noconfirm bash grep gcc make autoconf automake libtool git openssl cmake
elif [ "${GETPM}" == "dnf" ]; then
  dnf -y update
  dnf -y install epel-release
  dnf -y groupinstall "Development Tools"
  dnf -y update
  GCCLATEST=$(dnf repoquery --available --qf '%{name}' 'gcc-toolset-[0-9]*' | \
    grep -E '^gcc-toolset-[0-9]+$' | sort -V | tail -1)
  dnf -y install "$GCCLATEST" kernel-devel make git autoconf automake libtool git openssl openssl-devel cmake
fi
exit 0