#!/usr/bin/env bash

set -euo pipefail

PORT_ARG=3016
HOST_ARG=localhost
MEDIA_DIR_ARG=${1:-media}
PROJECT_NAME="simplemedia"
IMAGE_NAME="simplemedia"
CONTAINER_NAME="simplemedia"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR_ABS=""

TMP_DOCKERFILE="${SCRIPT_DIR}/.Dockerfile.deploy"
TMP_SERVER="${SCRIPT_DIR}/.server.deploy.js"
TMP_ENTRYPOINT="${SCRIPT_DIR}/.entrypoint.deploy.sh"

cleanup() {
  rm -f "$TMP_DOCKERFILE" "$TMP_SERVER" "$TMP_ENTRYPOINT"
}
trap cleanup EXIT

if [[ "$MEDIA_DIR_ARG" != /* ]]; then
  MEDIA_DIR_ABS="${SCRIPT_DIR}/${MEDIA_DIR_ARG}"
else
  MEDIA_DIR_ABS="${MEDIA_DIR_ARG}"
fi

if [[ $# -gt 1 ]]; then
  echo "Usage: ./deploy.sh [MEDIA_DIR]"
  echo "Example: ./deploy.sh /path/to/media"
  exit 1
fi

mkdir -p "$MEDIA_DIR_ABS"

echo "=== Deploying ${PROJECT_NAME} on port ${PORT_ARG} (host: ${HOST_ARG}) ==="
echo "=== Host media directory mounted at: ${MEDIA_DIR_ABS} -> /media-root ==="
cd "$SCRIPT_DIR"

echo "Generating temporary static server..."
cat > "$TMP_SERVER" <<'SERVER_EOF'
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 3014);
const ROOT = process.env.STATIC_ROOT || '/app';
const ENABLE_HTTPS = process.env.ENABLE_HTTPS === '1';
const TLS_CERT_PATH = process.env.TLS_CERT_PATH || '/app/tls/cert.pem';
const TLS_KEY_PATH = process.env.TLS_KEY_PATH || '/app/tls/key.pem';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
};

function sendFile(filePath, res) {
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
      'Content-Length': stat.size,
      'Cache-Control': 'no-cache',
    });

    fs.createReadStream(filePath).pipe(res);
  });
}

function sendDirectoryListing(dirPath, reqPath, res) {
  fs.readdir(dirPath, { withFileTypes: true }, (err, entries) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Could not read directory');
      return;
    }

    const normalizedReqPath = reqPath.endsWith('/') ? reqPath : `${reqPath}/`;
    const title = `Index of ${normalizedReqPath}`;
    const sortedEntries = entries
      .filter((entry) => entry.name !== '.')
      .sort((a, b) => {
        if (a.isDirectory() && !b.isDirectory()) return -1;
        if (!a.isDirectory() && b.isDirectory()) return 1;
        return a.name.localeCompare(b.name, undefined, { sensitivity: 'base' });
      });

    const parentLink = normalizedReqPath === '/' ? '' : '<li><a href="../">../</a></li>';
    const listItems = sortedEntries
      .map((entry) => {
        const suffix = entry.isDirectory() ? '/' : '';
        const encodedName = encodeURIComponent(entry.name) + suffix;
        const displayName = `${entry.name}${suffix}`;
        return `<li><a href="${encodedName}">${displayName}</a></li>`;
      })
      .join('\n');

    const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
</head>
<body>
  <h1>${title}</h1>
  <ul>
    ${parentLink}
    ${listItems}
  </ul>
</body>
</html>`;

    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache',
    });
    res.end(html);
  });
}

const requestHandler = (req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  const requestedPath = urlPath === '/' ? '/index.html' : urlPath;
  const safePath = path
    .normalize(requestedPath)
    .replace(/^([.][./\\])+/, '')
    .replace(/^[/\\]+/, '');
  const filePath = path.join(ROOT, safePath);

  fs.stat(filePath, (err, stat) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }

    if (stat.isDirectory()) {
      sendDirectoryListing(filePath, requestedPath, res);
      return;
    }

    sendFile(filePath, res);
  });
};

if (ENABLE_HTTPS) {
  const tlsOptions = {
    cert: fs.readFileSync(TLS_CERT_PATH),
    key: fs.readFileSync(TLS_KEY_PATH),
  };
  https.createServer(tlsOptions, requestHandler).listen(PORT, () => {
    console.log(`simplemedia static server listening with HTTPS on ${PORT}`);
  });
} else {
  http.createServer(requestHandler).listen(PORT, () => {
    console.log(`simplemedia static server listening with HTTP on ${PORT}`);
  });
}
SERVER_EOF

echo "Generating temporary entrypoint..."
cat > "$TMP_ENTRYPOINT" <<'ENTRYPOINT_EOF'
#!/usr/bin/env sh
set -eu

if [ "${ENABLE_HTTPS:-1}" = "1" ]; then
  mkdir -p /app/tls
  if [ ! -s "${TLS_CERT_PATH:-/app/tls/cert.pem}" ] || [ ! -s "${TLS_KEY_PATH:-/app/tls/key.pem}" ]; then
    echo "Generating self-signed TLS certificate for host: ${TLS_HOST:-localhost}"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "${TLS_KEY_PATH:-/app/tls/key.pem}" \
      -out "${TLS_CERT_PATH:-/app/tls/cert.pem}" \
      -sha256 -days 365 \
      -subj "/CN=${TLS_HOST:-localhost}" \
      -addext "subjectAltName=DNS:${TLS_HOST:-localhost},IP:127.0.0.1"
  fi
fi

if [ -d /media-root ]; then
  echo "Linking media subfolders from /media-root into /app..."
  find /media-root -mindepth 1 -maxdepth 1 -type d | while IFS= read -r media_dir; do
    folder_name="$(basename "$media_dir")"
    target_path="/app/${folder_name}"
    if [ -e "$target_path" ]; then
      echo "Skipping ${target_path}; path already exists."
      continue
    fi
    ln -s "$media_dir" "$target_path"
  done
fi

exec node /app/server.js
ENTRYPOINT_EOF

echo "Generating temporary Dockerfile..."
cat > "$TMP_DOCKERFILE" <<DOCKER_EOF
FROM node:20-alpine
RUN apk add --no-cache openssl
WORKDIR /app
COPY . /app
COPY .server.deploy.js /app/server.js
COPY .entrypoint.deploy.sh /app/entrypoint.sh
EXPOSE ${PORT_ARG}
ENV PORT=${PORT_ARG}
ENV STATIC_ROOT=/app
ENV ENABLE_HTTPS=1
ENV TLS_HOST=${HOST_ARG}
ENV TLS_CERT_PATH=/app/tls/cert.pem
ENV TLS_KEY_PATH=/app/tls/key.pem
RUN chmod +x /app/entrypoint.sh
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
  -v "${MEDIA_DIR_ABS}:/media-root" \
  --restart unless-stopped \
  "$IMAGE_NAME"

IP_ADDR=$(python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('8.8.8.8', 80)); print(s.getsockname()[0]); s.close()" 2>/dev/null || echo "localhost")

echo "========================================="
echo "Deployed ${PROJECT_NAME} at https://${IP_ADDR}:${PORT_ARG}"
echo "Media folder on host: ${MEDIA_DIR_ABS}"
echo "Copy files there in subfolders and access them directly..."
echo "Examples: Music => /Music, AudioBooks => /AudioBooks"
echo "Note: first load uses a self-signed certificate; trust/accept it in your browser."
echo "========================================="
