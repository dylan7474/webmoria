#!/usr/bin/env bash

set -euo pipefail

PORT_ARG=${1:-8080}
HOST_ARG=${2:-localhost}
PROJECT_NAME="webmoria"
IMAGE_NAME="webmoria"
CONTAINER_NAME="webmoria"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP_DOCKERFILE="${SCRIPT_DIR}/.Dockerfile.deploy"

cleanup() {
  rm -f "$TMP_DOCKERFILE"
}
trap cleanup EXIT

if [[ $# -gt 2 ]]; then
  echo "Usage: ./deploy.sh [PORT] [TLS_HOST]"
  echo "Example: ./deploy.sh 8080 localhost"
  exit 1
fi

if ! [[ "$PORT_ARG" =~ ^[0-9]+$ ]] || (( PORT_ARG < 1 || PORT_ARG > 65535 )); then
  echo "Error: PORT must be an integer between 1 and 65535."
  exit 1
fi

echo "=== Deploying ${PROJECT_NAME} on port ${PORT_ARG} (TLS host: ${HOST_ARG}) ==="
cd "$SCRIPT_DIR"

echo "Generating temporary Dockerfile..."
cat > "$TMP_DOCKERFILE" <<DOCKER_EOF
FROM node:20-alpine
RUN apk add --no-cache openssl
WORKDIR /app
COPY moria.html /app/moria.html
RUN cat > /app/server.js <<'SERVER_EOF'
const http = require('http');
const https = require('https');
const fs = require('fs');

const PORT = Number(process.env.PORT || 8080);
const ENABLE_HTTPS = process.env.ENABLE_HTTPS !== '0';
const TLS_CERT_PATH = process.env.TLS_CERT_PATH || '/app/tls/cert.pem';
const TLS_KEY_PATH = process.env.TLS_KEY_PATH || '/app/tls/key.pem';

const html = fs.readFileSync('/app/moria.html');

const requestHandler = (req, res) => {
  const pathname = (req.url || '/').split('?')[0];
  if (pathname === '/' || pathname === '/index.html' || pathname === '/moria.html') {
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Length': html.length,
      'Cache-Control': 'no-cache',
    });
    res.end(html);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Not found');
};

if (ENABLE_HTTPS) {
  const tlsOptions = {
    cert: fs.readFileSync(TLS_CERT_PATH),
    key: fs.readFileSync(TLS_KEY_PATH),
  };
  https.createServer(tlsOptions, requestHandler).listen(PORT, () => {
    console.log(\`webmoria server listening with HTTPS on \${PORT}\`);
  });
} else {
  http.createServer(requestHandler).listen(PORT, () => {
    console.log(\`webmoria server listening with HTTP on \${PORT}\`);
  });
}
SERVER_EOF
RUN cat > /app/entrypoint.sh <<'ENTRYPOINT_EOF'
#!/usr/bin/env sh
set -eu

if [ "${ENABLE_HTTPS:-1}" = "1" ]; then
  mkdir -p /app/tls
  if [ ! -s "${TLS_CERT_PATH:-/app/tls/cert.pem}" ] || [ ! -s "${TLS_KEY_PATH:-/app/tls/key.pem}" ]; then
    echo "Generating self-signed TLS certificate for host: ${HOST_ARG}"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "${TLS_KEY_PATH:-/app/tls/key.pem}" \
      -out "${TLS_CERT_PATH:-/app/tls/cert.pem}" \
      -sha256 -days 365 \
      -subj "/CN=${HOST_ARG}" \
      -addext "subjectAltName=DNS:${HOST_ARG},IP:127.0.0.1"
  fi
fi

exec node /app/server.js
ENTRYPOINT_EOF
RUN chmod +x /app/entrypoint.sh
EXPOSE ${PORT_ARG}
ENV PORT=${PORT_ARG}
ENV ENABLE_HTTPS=1
ENV TLS_CERT_PATH=/app/tls/cert.pem
ENV TLS_KEY_PATH=/app/tls/key.pem
CMD ["/app/entrypoint.sh"]
DOCKER_EOF

echo "Building Docker image..."
docker build -f "$TMP_DOCKERFILE" -t "$IMAGE_NAME" .

echo "Stopping existing container (if any)..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${PORT_ARG}:${PORT_ARG}" \
  --restart unless-stopped \
  "$IMAGE_NAME"

IP_ADDR=$(python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('8.8.8.8', 80)); print(s.getsockname()[0]); s.close()" 2>/dev/null || echo "localhost")

echo "========================================="
echo "Deployed ${PROJECT_NAME} at https://${IP_ADDR}:${PORT_ARG}"
echo "Also available at: https://${HOST_ARG}:${PORT_ARG}"
echo "Entry points: /, /index.html, /moria.html"
echo "Note: first load uses a self-signed certificate; trust/accept it in your browser."
echo "========================================="
