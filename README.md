# Dufs

[![CI](https://github.com/sigoden/dufs/actions/workflows/ci.yaml/badge.svg)](https://github.com/sigoden/dufs/actions/workflows/ci.yaml)
[![Crates](https://img.shields.io/crates/v/dufs.svg)](https://crates.io/crates/dufs)
[![Docker Pulls](https://img.shields.io/docker/pulls/sigoden/dufs)](https://hub.docker.com/r/sigoden/dufs)

Dufs is a ** distinctive utility file server** that supports static serving, uploading, searching, access control, and WebDAV — with a clean, modern web UI.

## Features

- 🖥️  **Modern Web UI** — Glassmorphism header, smooth animations, file-type badges, dark/light mode
- 📁  **Static File Serving** — Serve any directory or single file
- ⬆️  **Upload** — Drag & drop, resumable uploads (20MB+), folder upload
- 📦  **Download as ZIP** — One-click folder download
- ✏️  **Create / Edit** — Full-featured text file editor in browser
- 🔍  **Search** — Instant fuzzy search across file/folder names
- 🔐  **Access Control** — Username/password auth with read/write/read-only roles
- 🌐  **WebDAV** — Mount as a network drive on Windows/macOS/Linux
- 🔒  **HTTPS** — TLS/SSL support out of the box
- 🌈  **CORS Enabled** — Easy to integrate with frontend apps
- 🎨  **Custom UI** — Override assets directory for your own branding

---

## Quick Start

```sh
# macOS / Linux / Windows (from releases)
./dufs

# Docker — serve current directory on port 5000
docker run -v $(pwd):/data -p 5000:5000 --rm sigoden/dufs /data

# Build from source
cargo build --release
./target/release/dufs
```

Then open **http://localhost:5000** in your browser.

---

## Install

### Binary (all platforms)

Download from [GitHub Releases](https://github.com/sigoden/dufs/releases), unzip and add `dufs` to your `$PATH`.

| Platform | Architecture | File |
|----------|-------------|------|
| Linux | x86_64 / aarch64 / armv7 / i386 | `dufs-*-linux-*.tar.gz` |
| macOS  | x86_64 / aarch64 (Apple Silicon) | `dufs-*-macos-*.tar.gz` |
| Windows | x86_64 / i386 | `dufs-*-windows-*.zip` |

### Package managers

```sh
# macOS — Homebrew
brew install dufs

# Linux — npm (via npx)
npx dufs

# Rust — Cargo
cargo install dufs
```

---

## Docker

### Pull pre-built image (recommended)

```sh
docker pull sigoden/dufs
```

Multi-architecture images are available for: `linux/amd64`, `linux/arm64`, `linux/arm/v7`.

### Run — common scenarios

**Serve current working directory (read-only)**

```sh
docker run -v $(pwd):/data -p 5000:5000 --rm sigoden/dufs /data
```

> On Windows PowerShell, use: `docker run -v ${pwd}:/data -p 5000:5000 --rm sigoden/dufs /data`
> On Windows CMD, use: `docker run -v "%cd%":/data -p 5000:5000 --rm sigoden/dufs /data`

**Allow all operations (upload / delete / create / edit)**

```sh
docker run -v /path/to/your/folder:/data -p 5000:5000 --rm sigoden/dufs /data -A
```

**Serve a specific sub-directory with write access**

```sh
docker run -v /mnt/shared:/mnt/shared -p 5000:5000 --rm sigoden/dufs /mnt/shared/media -A
```

**Protect with username and password**

```sh
docker run -v $(pwd):/data -p 5000:5000 --rm sigoden/dufs /data \
  -a admin:your-password@/:rw
```

**HTTPS — with TLS certificates**

```sh
docker run -v $(pwd):/data -v /path/to/certs:/certs \
  -p 443:443 --rm sigoden/dufs /data \
  --tls-cert /certs/server.crt --tls-key /certs/server.key
```

**Bind to a specific IP / custom port**

```sh
docker run -v $(pwd):/data -p 192.168.1.100:8080:8080 --rm sigoden/dufs /data -p 8080
```

**Unix socket (Linux only)**

```sh
docker run -v /run:/run -v $(pwd):/data --rm --network none sigoden/dufs /data \
  -b /run/dufs.sock
```

### Build image from source

#### Build with cargo (cross-compile to Linux musl, multi-arch)

```sh
# Clone the repository
git clone https://github.com/sigoden/dufs.git
cd dufs

# Build the Docker image (produces linux/amd64 + linux/arm64)
docker build -t my-dufs .

# Or with a specific tag
docker build -t my-dufs:v1.0 .
```

#### Build with Alpine (download release binaries)

```sh
# Build from a GitHub release tarball
docker build \
  --build-arg REPO=sigoden/dufs \
  --build-arg VER=0.45.0 \
  -t my-dufs:v0.45.0 \
  -f Dockerfile-release \
  .
```

### Build image with custom UI assets

If you've customized the `assets/` directory and want to bake it into the Docker image:

```dockerfile
# Dockerfile.custom
FROM --platform=linux/amd64 messense/rust-musl-cross:x86_64-musl AS builder
WORKDIR /src
COPY . .
RUN cargo install --path . --root /

FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=builder /bin/dufs /usr/local/bin/dufs
COPY ./assets/ /app/assets/
WORKDIR /app
EXPOSE 5000
CMD ["dufs", "/data", "--assets", "/app/assets/"]
```

Then build and run:

```sh
docker build -f Dockerfile.custom -t my-dufs:custom .
docker run -v $(pwd):/data -p 5000:5000 --rm my-dufs:custom
```

---

## CLI Reference

```
dufs [OPTIONS] [serve-path]

Arguments:
  [serve-path]  Path to serve [default: .]

Options:
  -c, --config <file>      Configuration file (YAML)
  -b, --bind <addrs>        Bind address or unix socket [default: 0.0.0.0:5000]
  -p, --port <port>         Port to listen on [default: 5000]
      --path-prefix <path>  URL path prefix (e.g. /dufs)
      --hidden <value>      Glob patterns to hide, e.g. tmp,*.log
  -a, --auth <rules>         Auth rules (see Access Control)
  -A, --allow-all           Allow upload / delete / search / archive
      --allow-upload        Allow file & folder upload
      --allow-delete        Allow deleting files & folders
      --allow-search        Allow searching files & folders
      --allow-symlink       Allow symlinks outside root
      --allow-archive       Allow folder → ZIP download
      --allow-hash          Allow ?hash query (returns SHA-256)
      --enable-cors         Allow all origins (CORS *)
      --render-index        Serve index.html for directory requests
      --render-try-index    Fall back to listing if no index.html
      --render-spa          Single Page App mode (all 404 → index.html)
      --assets <path>       Custom assets directory (for UI overrides)
      --log-format <fmt>    HTTP access log format
      --log-file <file>     Write logs to file instead of stdout
      --compress <level>    ZIP compression [none | low | medium | high]
      --tls-cert <path>     TLS certificate (.crt / .pem)
      --tls-key <path>      TLS private key (.key)
  -h, --help                Show this help
  -V, --version             Show version
```

---

## Examples

**Read-only file server (default)**

```sh
dufs
```

**Full read-write (upload / delete / create / edit)**

```sh
dufs -A
```

**Upload only**

```sh
dufs --allow-upload
```

**Serve a specific directory**

```sh
dufs ~/Downloads
```

**Serve a single file**

```sh
dufs linux-distro.iso
```

**Serve a Single Page App (React / Vue / Svelte)**

```sh
dufs --render-spa
```

**Serve with index.html fallback**

```sh
dufs --render-index
```

**Username + password protection**

```sh
# admin:123456 has read-write access, anonymous users have read-only
dufs -a 'admin:123456@/:rw' -a '@/'

# Multiple users with different permissions
dufs -a 'admin:secret@/:rw' -a 'viewer:view@/public'
```

**Listen on a specific host**

```sh
dufs -b 127.0.0.1 -p 80          # local-only on port 80
dufs -b 0.0.0.0 -p 8080          # all interfaces, port 8080
```

**HTTPS**

```sh
dufs --tls-cert server.crt --tls-key server.key
```

**Path prefix (reverse proxy / sub-path deployment)**

```sh
dufs --path-prefix /files -A
# → served at http://host/files/
```

**Hide dotfiles and build artifacts**

```sh
dufs --hidden '.*' --hidden '*/node_modules' --hidden '*.lock'
```

**Disable access logging**

```sh
dufs --log-format ''
```

**Detailed access logging with user agent**

```sh
dufs --log-format '$remote_addr "$request" $status $http_user_agent'
```

---

## Access Control

Dufs uses account-based auth with role permissions.

### Syntax

```
dufs -a <account>@<paths>:<role>[,...]

account  := username:password    # plain text
          username:$hashed_pass  # sha-512 hashed (must be quoted)
paths    := path1,path2,...      # comma-separated, root = /
role     := rw | ro             # read-write | read-only (ro is default)
@ alone  := anonymous user
```

### Auth examples

```sh
# admin has full access; guest (and all others) can only read
dufs -a 'admin:password123@/:rw' -a '@/'

# user can write to /projects, read-only everywhere else
dufs -a 'user:pass@/:rw,/public' -a '@/'

# anonymous write to /uploads only
dufs -a '@/uploads:rw' -a '@/'
```

### Hashed passwords

```sh
# Generate a SHA-512 hash
openssl passwd -6 your-password
# $6$rounds=656000$xyz...abc

# Use it (enclose in single quotes — the $ chars must be protected)
dufs -a 'admin:$6$rounds=656000$xyz...abc@/:rw'
```

> ⚠️ Digest auth does **not** work with hashed passwords. Use basic auth in that case.

---

## Environment Variables

All CLI options can be set via `DUFS_`-prefixed environment variables:

```sh
export DUFS_PORT=8080
export DUFS_ALLOW_ALL=true
export DUFS_AUTH="admin:secret@/:rw|@/"
export DUFS_ASSETS=./my-assets/
```

| CLI Option | Environment Variable | Example Value |
|------------|---------------------|---------------|
| `serve-path` | `DUFS_SERVE_PATH` | `.` |
| `-b` `--bind` | `DUFS_BIND` | `0.0.0.0` |
| `-p` `--port` | `DUFS_PORT` | `5000` |
| `--path-prefix` | `DUFS_PATH_PREFIX` | `/dufs` |
| `--hidden` | `DUFS_HIDDEN` | `tmp,*.log` |
| `-a` `--auth` | `DUFS_AUTH` | `admin:pass@/:rw\|@/` |
| `-A` `--allow-all` | `DUFS_ALLOW_ALL` | `true` |
| `--allow-upload` | `DUFS_ALLOW_UPLOAD` | `true` |
| `--allow-delete` | `DUFS_ALLOW_DELETE` | `true` |
| `--allow-search` | `DUFS_ALLOW_SEARCH` | `true` |
| `--allow-symlink` | `DUFS_ALLOW_SYMLINK` | `true` |
| `--allow-archive` | `DUFS_ALLOW_ARCHIVE` | `true` |
| `--allow-hash` | `DUFS_ALLOW_HASH` | `true` |
| `--enable-cors` | `DUFS_ENABLE_CORS` | `true` |
| `--render-index` | `DUFS_RENDER_INDEX` | `true` |
| `--render-try-index` | `DUFS_RENDER_TRY_INDEX` | `true` |
| `--render-spa` | `DUFS_RENDER_SPA` | `true` |
| `--assets` | `DUFS_ASSETS` | `./assets/` |
| `--log-format` | `DUFS_LOG_FORMAT` | `'$remote_addr "$request" $status'` |
| `--log-file` | `DUFS_LOG_FILE` | `./dufs.log` |
| `--compress` | `DUFS_COMPRESS` | `medium` |
| `--tls-cert` | `DUFS_TLS_CERT` | `cert.pem` |
| `--tls-key` | `DUFS_TLS_KEY` | `key.pem` |

---

## Configuration File

All options can be stored in a YAML file:

```yaml
# config.yaml
serve-path: '/mnt/storage'
bind: 0.0.0.0
port: 5000
path-prefix: /files
hidden:
  - '.*'
  - '*/node_modules'
  - '*.lock'
auth:
  - 'admin:admin@/:rw'
  - '@/'
allow-all: false
allow-upload: true
allow-delete: true
allow-search: true
allow-symlink: true
allow-archive: true
allow-hash: true
enable-cors: false
render-index: false
render-spa: false
assets: ./assets/
log-format: '$remote_addr "$request" $status $http_user_agent'
log-file: ./dufs.log
compress: low
# tls-cert: ./cert.pem
# tls-key: ./key.pem
```

```sh
dufs --config config.yaml
```

---

## Custom UI

Dufs serves its web UI from a built-in `assets/` directory. You can override it entirely:

```
dufs --assets ./my-custom-assets/
```

Your assets folder **must** contain `index.html`. Two placeholder variables are available inside it:

| Placeholder | Description |
|------------|-------------|
| `__INDEX_DATA__` | Base64-encoded directory listing data (required) |
| `__ASSETS_PREFIX__` | URL prefix for linking CSS/JS assets |

### Minimal custom index.html

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <link rel="stylesheet" href="__ASSETS_PREFIX__index.css">
</head>
<body>
  <div id="app"></div>
  <template id="index-data">__INDEX_DATA__</template>
  <script src="__ASSETS_PREFIX__index.js"></script>
</body>
</html>
```

The JS bundle (`index.js`) handles all interactions — listing, upload, download, search, auth, and the text editor. It is self-contained and does not depend on any CDN.

---

## API

### Upload a file

```sh
curl -T path-to-file http://127.0.0.1:5000/new-path/path-to-file
```

### Download a file

```sh
curl http://127.0.0.1:5000/path-to-file           # download
curl http://127.0.0.1:5000/path-to-file?hash     # SHA-256 hash
```

### Download a folder as ZIP

```sh
curl -o folder.zip http://127.0.0.1:5000/folder?zip
```

### Delete a file or folder

```sh
curl -X DELETE http://127.0.0.1:5000/path-to-file-or-folder
```

### Create a directory

```sh
curl -X MKCOL http://127.0.0.1:5000/new-folder
```

### Move / rename a file or folder

```sh
curl -X MOVE http://127.0.0.1:5000/path \
  -H "Destination: http://127.0.0.1:5000/new-path"
```

### Search

```sh
curl 'http://127.0.0.1:5000?q=Dockerfile'       # fuzzy name search
curl 'http://127.0.0.1:5000?simple'             # names only, like `ls -1`
curl 'http://127.0.0.1:5000?json'               # JSON output
```

### Resumable download

```sh
curl -C- -o file http://127.0.0.1:5000/file
```

### Resumable upload (20MB+ files)

```sh
offset=$(curl -I -s http://127.0.0.1:5000/file | grep -i content-length | awk '{print $2}')
dd skip=$offset if=file bs=1 | \
  curl -X PATCH -H "X-Update-Range: append" \
       --data-binary @- http://127.0.0.1:5000/file
```

### Health check

```sh
curl http://127.0.0.1:5000/__dufs__/health
```

---

## WebDAV

Dufs exposes a WebDAV endpoint at the root path. You can mount it as a network drive:

| OS | Command |
|----|---------|
| **Windows** (File Explorer) | `\\127.0.0.1@5000\Dufs\` or Map Network Drive → `http://127.0.0.1:5000/` |
| **macOS** (Finder) | Go → Connect to Server → `http://127.0.0.1:5000/` |
| **Linux** (GNOME Files) | Connect to Server → `dav://127.0.0.1:5000/` |
| **Linux** (CLI) | `rclone mount dufs:/ /mnt/dufs --daemon` |

> For write access via WebDAV, start dufs with `-A` or `--allow-upload --allow-delete`.

---

## License

Copyright (c) 2022-2025 dufs-developers.

Dufs is made available under the terms of either the **MIT License** or the **Apache License 2.0**, at your option.

See the [LICENSE-APACHE](LICENSE-APACHE) and [LICENSE-MIT](LICENSE-MIT) files for details.
