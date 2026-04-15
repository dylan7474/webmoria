#!/usr/bin/env bash

set -euo pipefail

PORT_ARG=${1:-8080}
TLS_HOST=${2:-localhost}
PROJECT_NAME="Web Moria"
IMAGE_NAME="webmoria"
CONTAINER_NAME="webmoria"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! [[ "$PORT_ARG" =~ ^[0-9]+$ ]] || (( PORT_ARG < 1 || PORT_ARG > 65535 )); then
  echo "Error: PORT must be an integer between 1 and 65535."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required but was not found in PATH."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required but was not found in PATH."
  exit 1
fi

if [ ! -f "${SCRIPT_DIR}/moria.html" ]; then
  echo "Error: moria.html was not found in ${SCRIPT_DIR}."
  exit 1
fi

echo "=== Deploying ${PROJECT_NAME} on https://${TLS_HOST}:${PORT_ARG} ==="

BUILD_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

cp "${SCRIPT_DIR}/moria.html" "${BUILD_DIR}/moria.html"
cp "${SCRIPT_DIR}/moria.html" "${BUILD_DIR}/index.html"

mkdir -p "${BUILD_DIR}/certs"
openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
  -keyout "${BUILD_DIR}/certs/tls.key" \
  -out "${BUILD_DIR}/certs/tls.crt" \
  -days 365 \
  -subj "/CN=${TLS_HOST}" \
  -addext "subjectAltName=DNS:${TLS_HOST},DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1

cat > "${BUILD_DIR}/nginx.conf" <<NGINX_EOF
server {
  listen ${PORT_ARG} ssl;
  server_name _;

  ssl_certificate     /etc/nginx/certs/tls.crt;
  ssl_certificate_key /etc/nginx/certs/tls.key;

  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
NGINX_EOF

cat > "${BUILD_DIR}/Dockerfile" <<'DOCKER_EOF'
FROM nginx:1.29-alpine
COPY moria.html /usr/share/nginx/html/moria.html
COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY certs /etc/nginx/certs
DOCKER_EOF

echo "Building Docker image..."
docker build -t "${IMAGE_NAME}" "${BUILD_DIR}"

echo "Stopping existing container (if any)..."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

echo "Starting container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${PORT_ARG}:${PORT_ARG}" \
  --restart unless-stopped \
  "${IMAGE_NAME}" >/dev/null

echo "========================================="
echo "Deployed ${PROJECT_NAME}."
echo "URL: https://${TLS_HOST}:${PORT_ARG}/"
echo "Game file: https://${TLS_HOST}:${PORT_ARG}/moria.html"
echo "Note: Browser will warn about the self-signed certificate."
echo "========================================="
