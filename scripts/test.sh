#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/node-src"
NODE_BIN="${NODE_BIN:-$SRC_DIR/out/Release/node}"

if [[ ! -x "$NODE_BIN" ]]; then
  echo "Node binary not found: $NODE_BIN" >&2
  exit 1
fi

echo "==> Binary: $NODE_BIN"
"$NODE_BIN" -v
"$NODE_BIN" -p "JSON.stringify(process.versions, null, 2)"

if command -v ldd >/dev/null; then
  ldd "$NODE_BIN" | tee /tmp/node-ldd.txt
  grep -E 'libssl\.so|libcrypto\.so' /tmp/node-ldd.txt
  if grep -E 'not found' /tmp/node-ldd.txt; then
    echo "ERROR: unresolved shared libraries" >&2
    exit 1
  fi
fi

"$NODE_BIN" -e "
const v = process.config?.variables || {};
const shared = v.node_shared_openssl;
console.log('node_shared_openssl=', shared);
if (shared === false || shared === 'false' || shared === 0) {
  console.error('Expected shared OpenSSL build');
  process.exit(1);
}
"

"$NODE_BIN" -e '
const crypto = require("crypto");
let hashes = crypto.getHashes();
if (!hashes.includes("sha256")) throw new Error("sha256 missing");
hashes = hashes.filter(x => /gost|streebog|magma|kuznyechik/i.test(x));
console.log("Added hashes:");
console.log(hashes);
if (!hashes.length) throw new Error("No hashing algorithms added");
if (!hashes.includes("md_gost12_256")) throw new Error("md_gost12_256 missing");
const ciphers = crypto.getCiphers().filter(x => /gost|streebog|magma|kuznyechik/i.test(x));
console.log("Added ciphers:");
console.log(ciphers);
if (!ciphers.length) throw new Error("No ciphers added");
//const tls = require("tls");
//console.log(tls.getCiphers());
//TLS ciphers from providers do not work for now.
let h = crypto.createHash("sha256").update("this is test string").digest("hex");
if (h.length !== 64) throw new Error("sha256 failed");
h = crypto.createHash("md_gost12_256").update("this is test string").digest("hex");
if (h.length !== 64) throw new Error("md_gost12_256 failed");
'

echo "==> All tests passed"
