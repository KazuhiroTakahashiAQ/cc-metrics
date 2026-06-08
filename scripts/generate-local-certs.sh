#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_DIR="${ROOT_DIR}/certs"

if ! command -v mkcert >/dev/null 2>&1; then
  echo "mkcert is required. Install it first: https://github.com/FiloSottile/mkcert" >&2
  exit 1
fi

mkdir -p "${CERT_DIR}"

mkcert -install
mkcert \
  -cert-file "${CERT_DIR}/localhost.pem" \
  -key-file "${CERT_DIR}/localhost-key.pem" \
  localhost 127.0.0.1 ::1

chmod 600 "${CERT_DIR}/localhost-key.pem"

cat <<EOF
Certificates generated:
  ${CERT_DIR}/localhost.pem
  ${CERT_DIR}/localhost-key.pem
EOF
