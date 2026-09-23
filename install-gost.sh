#!/bin/sh
GETPM=${GETPM:?}
#Determine existing package version
getpackver() {
  if [ "${GETPM}" == "apt-get" ]; then
    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
      IVERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null)
    fi
  elif [ "${GETPM}" == "pacman" ]; then
    if pacman -Q "$PACKAGE" >/dev/null 2>&1; then
      IVERSION=$(pacman -Q "$PACKAGE" 2>/dev/null | awk '{print $2}')
    fi
  elif [ "${GETPM}" == "dnf" ]; then
    #exact name
    if rpm -q "$PACKAGE" >/dev/null 2>&1; then
      IVERSION=$(rpm -q --qf '%{IVERSION}-%{ITERATION}' "$PACKAGE" 2>/dev/null)
    fi
    # names starting with "PACKAGE-"
    if ! [ -n "$IVERSION" ]; then
      FOUND=$(rpm -qa --qf '%{NAME} %{IVERSION}-%{ITERATION}\n' 2>/dev/null | grep -E "^${PACKAGE}-[0-9]")
      if [ -n "$FOUND" ]; then
          REAL_NAME=$(echo "$FOUND" | head -n1 | awk '{print $1}')
          IVERSION=$(echo "$FOUND" | head -n1 | awk '{print $2}')
      fi
    fi
  fi
}
#Find suitable package from github release and install it
getasset() {
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
  RELEASE_JSON=$(curl -fsSL "$API_URL")
  #Existing version check.
  getpackver
  if [ -n "${IVERSION}" ]; then
    NEWVERSION=$(echo "$RELEASE_JSON" | \
      grep -m 1 -oE '"name":\s*"[^"]*"' | \
      sed -E 's/.*"([^"]+)".*/\1/')
  fi
  if ! [ -n "${IVERSION}" ] || [ "${IVERSION}" != "${NEWVERSION}" ]; then
    mapfile -t AVAILABLE < <(
      echo "$RELEASE_JSON" | \
      grep -oE '"browser_download_url":\s*"[^"]*'${LINK_TMPLT}'.*"' | \
      sed -E 's/.*"([^"]+)".*/\1/' | \
      while read -r url; do
        ver=$(echo "$url" | grep -oE "${LINK_TMPLT}" | tr _ - | cut -d- -f2)
        echo "$ver $url"
      done | sort -n
    )
    if [ -n "${MAJOR_VERSION}" ]; then
      for entry in "${AVAILABLE[@]}"; do
        ver=${entry%% *}
        url=${entry#* }
        if [[ "$ver" -eq "$MAJOR_VERSION" ]]; then
          ASSET_URL=$url
          break
        fi
      done
    fi
    if ! [ -n "${ASSET_URL}" ]; then
      last="${AVAILABLE[-1]}"
      ASSET_URL=${last#* }
    fi
    FILENAME=$(basename "$ASSET_URL")
    curl -fsSL -o "$TMP_DIR/$FILENAME" "$ASSET_URL"
    if [ "${GETPM}" == "apt-get" ]; then
      apt-get install -y "$TMP_DIR/$FILENAME"
    elif [ "${GETPM}" == "pacman" ]; then
      pacman -U --noconfirm "$TMP_DIR/$FILENAME"
    elif [ "${GETPM}" == "dnf" ]; then
      dnf install -y "$TMP_DIR/$FILENAME"
    fi
    rm -rf "$TMP_DIR/$FILENAME"
  fi
}

#Get OS version
if [ "${GETPM}" == "apt-get" ]; then
  source /etc/os-release
  if [ -n "${VERSION_ID}" ]; then
    MAJOR_VERSION="${VERSION_ID%%.*}"
  else #get version number by code name
    CODENAME=$(printf '%s' "$VERSION_CODENAME" | tr '[:upper:]' '[:lower:]')
    CSV_LOCAL="/usr/share/distro-info/debian.csv"
    CSV_URL="https://debian.pages.debian.net/distro-info-data/debian.csv"
    get_csv() {
      if [ -r "$CSV_LOCAL" ]; then
        cat "$CSV_LOCAL"
      else
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL "$CSV_URL"
        elif command -v wget >/dev/null 2>&1; then
          wget -qO- "$CSV_URL"
        else
          echo "Error: neither curl nor wget found, and $CSV_LOCAL is missing." >&2
          echo "Install distro-info-data or one of the downloaders." >&2
          exit 1
        fi
      fi
    }
    # Looking for series (3rd column) == CODENAME
    # Format: version,codename,series,created,release,...
    MAJOR_VERSION=$(get_csv | awk -F, -v name="$CODENAME" '
      NR == 1 { next }
      $3 == name {
        gsub(/^[ \t]+|[ \t]+$/, "", $1) # trim
        print $1
        exit
      }
    ')
  fi
  LINK_TMPLT="debian-[0-9]+"
elif [ "${GETPM}" == "pacman" ]; then
  MAJOR_VERSION=
  LINK_TMPLT="arch-rolling"
elif [ "${GETPM}" == "dnf" ]; then
  if [ -n "${VERSION_ID}" ]; then
    MAJOR_VERSION="${VERSION_ID%%.*}"
  fi
  LINK_TMPLT="almalinux_[0-9]+"
fi

REPO="GauriSpears/gost-engine-package"
PACKAGE="gost-engine"
TMP_DIR=/usr/local/src
getasset
exit 0