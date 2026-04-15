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
RUN cat > /app/server.js <<'SERVER_EOF'\nconst http = require('http');\nconst https = require('https');\nconst fs = require('fs');\n\nconst PORT = Number(process.env.PORT || 8080);\nconst ENABLE_HTTPS = process.env.ENABLE_HTTPS !== '0';\nconst TLS_CERT_PATH = process.env.TLS_CERT_PATH || '/app/tls/cert.pem';\nconst TLS_KEY_PATH = process.env.TLS_KEY_PATH || '/app/tls/key.pem';\n\nconst html = fs.readFileSync('/app/moria.html');\n\nconst requestHandler = (req, res) => {\n  const pathname = (req.url || '/').split('?')[0];\n  if (pathname === '/' || pathname === '/index.html' || pathname === '/moria.html') {\n    res.writeHead(200, {\n      'Content-Type': 'text/html; charset=utf-8',\n      'Content-Length': html.length,\n      'Cache-Control': 'no-cache',\n    });\n    res.end(html);\n    return;\n  }\n\n  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });\n  res.end('Not found');\n};\n\nif (ENABLE_HTTPS) {\n  const tlsOptions = {\n    cert: fs.readFileSync(TLS_CERT_PATH),\n    key: fs.readFileSync(TLS_KEY_PATH),\n  };\n  https.createServer(tlsOptions, requestHandler).listen(PORT, () => {\n    console.log(\`webmoria server listening with HTTPS on \${PORT}\`);\n  });\n} else {\n  http.createServer(requestHandler).listen(PORT, () => {\n    console.log(\`webmoria server listening with HTTP on \${PORT}\`);\n  });\n}\nSERVER_EOF
RUN cat > /app/entrypoint.sh <<'ENTRYPOINT_EOF'\n#!/usr/bin/env sh\nset -eu\n\nif [ "${ENABLE_HTTPS:-1}" = "1" ]; then\n  mkdir -p /app/tls\n  if [ ! -s "${TLS_CERT_PATH:-/app/tls/cert.pem}" ] || [ ! -s "${TLS_KEY_PATH:-/app/tls/key.pem}" ]; then\n    echo "Generating self-signed TLS certificate for host: ${HOST_ARG}"\n    openssl req -x509 -newkey rsa:2048 -nodes \\\n      -keyout "${TLS_KEY_PATH:-/app/tls/key.pem}" \\\n      -out "${TLS_CERT_PATH:-/app/tls/cert.pem}" \\\n      -sha256 -days 365 \\\n      -subj "/CN=${HOST_ARG}" \\\n      -addext "subjectAltName=DNS:${HOST_ARG},IP:127.0.0.1"\n  fi\nfi\n\nexec node /app/server.js\nENTRYPOINT_EOF
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
