#!/usr/bin/env bash
#
# dufs - 文件服务器安装脚本（中文界面版 dufs-zh）
# 从 GitHub Release 下载对应架构的静态二进制安装为 systemd 服务。
# 可重复执行，升级等同于重新安装（覆盖二进制并重启服务）。
#
# Usage:
#   交互式安装（将提示端口与数据目录）:
#     bash scripts/install.sh
#   参数静默安装（-p 端口 / -d 数据目录 / -v 版本 / -b 二进制源）:
#     bash scripts/install.sh -p 5000 -d /var/lib/dufs -v 1.0.0
#     bash scripts/install.sh -y

set -euo pipefail

# ================== terminal colors ==================
list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

sep_line() {
  printf '%s' "$gl_bufan"
  printf '—%.0s' {1..32}
  printf '%s\n' "$reset"
}

section() {
  printf "  %s %s\n" "${gl_zi}▶${reset}" "$1"
}

ok() {
  printf "  %s %s\n" "${gl_lv}>>>${reset}" "$1"
}

skip() {
  printf "  %s %s\n" "${gl_hui}--${reset}" "$1"
}

__warn_box_width() {
    local s=$1 i c cp width=0
    local len=${#s}
    for ((i = 0; i < len; i++)); do
        c=${s:i:1}
        printf -v cp '%d' "'$c" 2>/dev/null || cp=63
        if (( (cp>=0x1100 && cp<=0x115F) || (cp>=0x2E80 && cp<=0x303E) || \
              (cp>=0x3041 && cp<=0x33FF) || (cp>=0x3400 && cp<=0x4DBF) || \
              (cp>=0x4E00 && cp<=0x9FFF) || (cp>=0xA000 && cp<=0xA4CF) || \
              (cp>=0xAC00 && cp<=0xD7A3) || (cp>=0xF900 && cp<=0xFAFF) || \
              (cp>=0xFE30 && cp<=0xFE6F) || (cp>=0xFF00 && cp<=0xFF60) || \
              (cp>=0xFFE0 && cp<=0xFFE6) || (cp>=0x1F300 && cp<=0x1F64F) )); then
                width=$((width + 2))
            else
                width=$((width + 1))
            fi
    done
    printf '%d' "$width"
}

warn_box() {
    local gl_bai=$'\033[38;5;15m'
    local gl_zi=$'\033[38;5;13m'
    local reset=$'\033[0m'

    local pad=1
    if [[ $1 =~ ^[0-9]+$ ]]; then
        pad=$1
        shift
    fi
    local lines=("$@")
    local max=0 l w
    for l in "${lines[@]}"; do
        w=$(__warn_box_width "$l")
        (( w > max )) && max=$w
    done
    local W=$max
    (( W < 1 )) && W=1
    local bar
    printf -v bar '%*s' "$W" ''
    bar=${bar// /─}
    printf '%s╭%s╮%s\n' "$gl_zi" "$bar" "$reset"
    for ((i = 0; i < pad; i++)); do
        printf '%s│%*s│%s\n' "$gl_zi" "$W" "" "$reset"
    done
    for l in "${lines[@]}"; do
        w=$(__warn_box_width "$l")
        printf '%s│%s%s%s%*s%s│%s\n' \
            "$gl_zi" "$gl_bai" "$l" "$reset" \
            $((W - w)) "" "$gl_zi" "$reset"
    done
    for ((i = 0; i < pad; i++)); do
        printf '%s│%*s│%s\n' "$gl_zi" "$W" "" "$reset"
    done
    printf '%s╰%s╯%s\n' "$gl_zi" "$bar" "$reset"
}

error() { printf "  %s %s\n" "${gl_hong}[错误]${reset}" "$1" >&2; exit 1; }

# ================== customize me ==================
APP_NAME="dufs"
DEFAULT_PORT=5000
DEFAULT_DATA_DIR="/var/lib/${APP_NAME}"
BIN_PATH="/usr/local/bin/${APP_NAME}"
RECORD_FILE="/etc/${APP_NAME}.conf"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
REPO="meimolihan/dufs-zh"
DEFAULT_BIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)/../target/release/${APP_NAME}"
# ==================================================

PORT=""
DATA_DIR=""
VERSION=""
TARGET=""
BIN_SRC=""
BIN_SRC_EXPLICIT=0
INSTALL_YES=0

# ---- bootstrap: support `bash -c "$(curl ...)" -p ... -d ...` ----
case "$0" in
  -*) set -- "$0" "$@" ;;
esac

# ---- parse command-line args (silent install) ----
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--port)
      shift
      [ -n "${1:-}" ] || error "缺少 -p/--port 的值"
      PORT="$1"
      ;;
    -d|--data)
      shift
      [ -n "${1:-}" ] || error "缺少 -d/--data 的值"
      DATA_DIR="$1"
      ;;
    -v|--version)
      shift
      [ -n "${1:-}" ] || error "缺少 -v/--version 的值（形如 1.0.0 或 v1.0.0）"
      VERSION="$1"
      ;;
    -b|--bin)
      shift
      [ -n "${1:-}" ] || error "缺少 -b/--bin 的值"
      BIN_SRC="$1"
      BIN_SRC_EXPLICIT=1
      ;;
    -y|--yes)
      INSTALL_YES=1
      ;;
    -h|--help)
      printf "%s\n" "${gl_lan}dufs${reset} - ${gl_bai}文件服务器（中文界面版） 安装脚本${reset}"
      printf "  %-13s %s\n" "${gl_bai}用法:${reset}" "bash scripts/install.sh [-p PORT] [-d DATA_DIR] [-v VERSION] [-b BIN] [-y]"
      printf "  %-13s %s\n" "${gl_bai}-p, --port${reset}" "监听端口（默认 ${gl_lan}${DEFAULT_PORT}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-d, --data${reset}" "数据目录，即对外提供服务的根目录（默认 ${gl_lan}${DEFAULT_DATA_DIR}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-v, --version${reset}" "发布版本（默认 ${gl_lan}最新 Release${reset}），例如 1.0.0"
      printf "  %-13s %s\n" "${gl_bai}-b, --bin${reset}" "本地二进制源路径（默认 ${gl_lan}${DEFAULT_BIN_SRC}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-y, --yes${reset}" "免交互，未指定项全部使用默认值"
      printf "  %-13s %s\n" "${gl_bai}-h, --help${reset}" "显示本帮助"
      printf "%s\n" "${gl_hui}指定任意参数即进入静默安装；不带参数则为交互式安装。${reset}"
      printf "%s\n" "${gl_hui}未指定 -b 且本地无构建产物时，自动从 GitHub Release 下载对应架构二进制。${reset}"
      exit 0
      ;;
    *)
      error "未知参数: $1（使用 -h 查看帮助）"
      ;;
  esac
  shift
done

# ---- read previous install record to prefill defaults (reinstall/upgrade) ----
read_record() {
  [ -f "${RECORD_FILE}" ] || return 0
  while IFS='=' read -r KEY VALUE; do
    KEY=$(printf '%s' "$KEY" | tr -d ' ')
    VALUE=$(printf '%s' "$VALUE" | tr -d '\r')
    case "$KEY" in
      PORT) [ -n "$VALUE" ] && [ -z "$PORT" ] && PORT="$VALUE" ;;
      DATA_DIR) [ -n "$VALUE" ] && [ -z "$DATA_DIR" ] && DATA_DIR="$VALUE" ;;
      VERSION) [ -n "$VALUE" ] && [ -z "$VERSION" ] && VERSION="$VALUE" ;;
    esac
  done < "${RECORD_FILE}"
  return 0
}

# ---- firewall: automatically open the listen port ----
FW_OPENED="n"
open_firewall_port() {
  local PORT="$1"
  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    if ! firewall-cmd --query-port="${PORT}/tcp" >/dev/null 2>&1; then
      firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null 2>&1 || true
      firewall-cmd --reload >/dev/null 2>&1 || true
    fi
    ok "已通过 ${gl_bai}firewalld${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
    FW_OPENED="y"
    return 0
  fi

  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    if ! ufw status 2>/dev/null | grep -q "${PORT}/tcp"; then
      ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
    fi
    ok "已通过 ${gl_bai}ufw${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
    FW_OPENED="y"
    return 0
  fi

  if command -v iptables >/dev/null 2>&1; then
    if iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1; then
      ok "端口 ${gl_lan}${PORT}/tcp${reset} 已在 iptables 中放行"
      FW_OPENED="y"
      return 0
    fi
    if iptables -L INPUT -n 2>/dev/null | grep -qE 'policy (DROP|REJECT)|REJECT|DROP'; then
      if iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1; then
        ok "已通过 ${gl_bai}iptables${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
        FW_OPENED="y"
        return 0
      fi
    fi
  fi
  printf "  %s %s\n" "${gl_huang}[提示]${reset}" "未检测到活跃的防火墙（firewalld/ufw/iptables），跳过端口开放。"
}

# ---- map uname -m to release asset target ----
map_target() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64-unknown-linux-musl' ;;
    aarch64|arm64) printf 'aarch64-unknown-linux-musl' ;;
    armv7l|armv7) printf 'armv7-unknown-linux-musleabihf' ;;
    armv6l|arm) printf 'arm-unknown-linux-musleabihf' ;;
    i686|x86|i386) printf 'i686-unknown-linux-musl' ;;
    *) return 1 ;;
  esac
}

# ---- resolve release version (default: latest tag) ----
resolve_latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}

[ "$(id -u)" != "0" ] && error "请以 root 身份运行（例如 sudo bash scripts/install.sh）"

read_record

warn_box 0  '        Dufs 文件服务器 · 安装    '

sep_line
section "安装信息"
printf "  %-14s %s\n" "${gl_lan}系统${reset}" "$(uname -s) $(uname -m)"
printf "  %-14s %s\n" "${gl_lan}程序${reset}" "${gl_bai}${APP_NAME}${reset}"
sep_line

# ---- silent install detection ----
SILENT="n"
if [ -n "${PORT}" ]; then
  case "${PORT}" in
    ''|*[!0-9]*) error "PORT 无效（需为 1‑65535 的数字）: ${PORT}" ;;
    *) [ "${PORT}" -ge 1 ] && [ "${PORT}" -le 65535 ] || error "PORT 超出范围（1‑65535）: ${PORT}" ;;
  esac
  SILENT="y"
fi
[ -n "${DATA_DIR}" ] && SILENT="y"
[ -n "${VERSION}" ] && SILENT="y"

section "配置参数"
# port prompt
if [ -z "${PORT}" ]; then
  if [ "$INSTALL_YES" = "1" ] || [ ! -t 0 ]; then
    PORT="${DEFAULT_PORT}"
  else
    while :; do
      read -r -p "${gl_bai}请输入监听端口${reset} ${gl_hui}[默认: ${DEFAULT_PORT}]${reset}: " PORT
      PORT="${PORT:-$DEFAULT_PORT}"
      case "$PORT" in
        ''|*[!0-9]*) printf "  %s\n" "${gl_huang}端口无效，请重新输入。${reset}" ;;
        *)
          if [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then break; fi
          printf "  %s\n" "${gl_huang}端口超出范围（1‑65535），请重新输入。${reset}"
          ;;
      esac
    done
  fi
else
  printf "  %-14s %s\n" "${gl_lan}监听端口${reset}" "${gl_bai}${PORT}${reset}（参数指定）"
fi
PORT="${PORT:-$DEFAULT_PORT}"

# data dir / serve path prompt
if [ -z "${DATA_DIR}" ]; then
  if [ "$INSTALL_YES" = "1" ] || [ ! -t 0 ]; then
    DATA_DIR="${DEFAULT_DATA_DIR}"
  else
    read -r -p "${gl_bai}请输入数据目录（对外提供服务的根目录）${reset} ${gl_hui}[默认: ${DEFAULT_DATA_DIR}]${reset}: " DATA_DIR
    DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
  fi
else
  printf "  %-14s %s\n" "${gl_lan}数据目录${reset}" "${gl_bai}${DATA_DIR}${reset}（参数指定）"
fi
DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
[[ "${DATA_DIR}" = /* ]] || error "数据目录必须是绝对路径: ${DATA_DIR}"

# ---- binary source / release download ----
BIN_SRC="${BIN_SRC:-$DEFAULT_BIN_SRC}"
if [ ! -f "${BIN_SRC}" ] && [ "${BIN_SRC_EXPLICIT}" != "1" ]; then
  BIN_SRC=""
fi
if [ -z "${BIN_SRC}" ]; then
  TARGET="$(map_target)" || error "不支持的架构: $(uname -m)，请先本地构建（scripts/build-and-push.sh 或 cargo build --release）或使用 -b 指定"
  VERSION="${VERSION:-$(resolve_latest_version)}"
  VERSION="${VERSION#v}"
  [ -n "${VERSION}" ] || error "无法获取最新 Release 版本，请用 -v 显式指定（例如 -v 1.0.0）"
  REL_URL="https://github.com/${REPO}/releases/download/v${VERSION}/dufs-v${VERSION}-${TARGET}.tar.gz"
  ok "准备下载 ${gl_bai}dufs v${VERSION} (${TARGET})${reset}"
  TMP_DIR="$(mktemp -d)"
  if ! curl -fsSL "${REL_URL}" -o "${TMP_DIR}/dufs.tar.gz"; then
    rm -rf "${TMP_DIR}"
    error "下载 Release 二进制失败（${REL_URL}），请用 -v 指定已发布版本"
  fi
  tar -xzf "${TMP_DIR}/dufs.tar.gz" -C "${TMP_DIR}"
  BIN_SRC="${TMP_DIR}/dufs"
  [ -x "${BIN_SRC}" ] || { rm -rf "${TMP_DIR}"; error "压缩包中未找到可执行文件 dufs"; }
  ok "已下载 dufs v${VERSION}（${gl_bai}$(du -h "${BIN_SRC}" | cut -f1)${reset}）"
elif [ "${BIN_SRC_EXPLICIT}" = "1" ]; then
  [ -f "${BIN_SRC}" ] || error "未找到二进制文件 ${BIN_SRC}（-b 显式指定）"
  ok "使用本地二进制 ${gl_bai}${BIN_SRC}${reset}"
fi

if command -v systemctl >/dev/null 2>&1; then
  USE_SYSTEMD="y"
else
  USE_SYSTEMD="n"
  printf "  %s\n" "${gl_huang}[警告]${reset} 未检测到 systemd（容器或受限环境）。"
  printf "  %s\n" "${gl_hui}    已回退为后台运行模式，重启或崩溃后服务不会自动恢复。${reset}"
fi

VERSION="${VERSION:-local}"

sep_line
section "安装程序"
ok "正在安装 ${gl_bai}${APP_NAME}${reset} 二进制 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

cp -f "${BIN_SRC}" "${BIN_PATH}"
chmod +x "${BIN_PATH}"
ok "已安装二进制至 ${gl_bai}${BIN_PATH}${reset}"

ok "正在创建数据目录 ${gl_lan}${DATA_DIR}${reset}"
mkdir -p "${DATA_DIR}"

# ---- write install record ----
mkdir -p "$(dirname "${RECORD_FILE}")"
cat > "${RECORD_FILE}" <<EOF
# ${APP_NAME} 安装记录（由 install.sh 生成，请勿手动修改）
APP_NAME=${APP_NAME}
BIN_PATH=${BIN_PATH}
PORT=${PORT}
DATA_DIR=${DATA_DIR}
VERSION=${VERSION}
TARGET=${TARGET:-local}
EOF
chmod 0644 "${RECORD_FILE}"
ok "已写入安装记录 ${gl_bai}${RECORD_FILE}${reset}"

sep_line
section "启动服务"
if [ "${USE_SYSTEMD}" = "y" ]; then
  cat > "${SERVICE_FILE}" <<UNIT
[Unit]
Description=${APP_NAME} - 文件服务器（中文界面版）
After=network-online.target local-fs.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_PATH} --bind 0.0.0.0 --port ${PORT} ${DATA_DIR}
WorkingDirectory=${DATA_DIR}
Environment=TZ=Asia/Shanghai
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable "${APP_NAME}" >/dev/null 2>&1 || true
  systemctl restart "${APP_NAME}"
  sleep 2
  if systemctl is-active "${APP_NAME}" >/dev/null 2>&1; then
    ok "${gl_bai}${APP_NAME}${reset} 服务已启动。"
    systemctl status "${APP_NAME}" --no-pager || true
  else
    printf "  %s\n" "${gl_hong}[错误]${reset} 服务启动失败，请检查：${gl_bai}journalctl -u ${APP_NAME} -n 50${reset}" >&2
    exit 1
  fi
else
  if command -v pgrep >/dev/null 2>&1 && pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    printf "  %s\n" "${gl_huang}[警告]${reset} 检测到 ${APP_NAME} 进程可能已在运行"
  else
    nohup "${BIN_PATH}" --bind 0.0.0.0 --port "${PORT}" "${DATA_DIR}" >> "${DATA_DIR}/${APP_NAME}.log" 2>&1 &
    ok "${APP_NAME} 已在后台启动，pid: ${gl_bai}$!${reset}"
  fi
fi

# 取第一个IPv4
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "${IP}" ] && IP="<服务器IP>"

open_firewall_port "${PORT}"

if [ "${FW_OPENED}" = "y" ]; then
  FW_STATUS="${gl_lv}已开放 ${PORT}/tcp${reset}"
else
  FW_STATUS="${gl_huang}未检测到活跃防火墙，已跳过${reset}"
fi

sep_line
if [ "${USE_SYSTEMD}" = "y" ]; then
  printf "  %s\n" "${gl_lv}✔ dufs 安装成功！${reset}"
  printf "  %-14s %s\n" "${gl_lan}访问地址${reset}" "${gl_bai}http://${IP}:${PORT}${reset}"
  printf "  %-14s %s\n" "${gl_lan}数据目录${reset}" "${gl_bai}${DATA_DIR}${reset}"
  printf "  %-14s %s\n" "${gl_lan}版本${reset}" "${gl_bai}${VERSION}${reset}"
  printf "  %-14s %s\n" "${gl_lan}防火墙状态${reset}" "$FW_STATUS"
  printf "  %-14s %s\n" "${gl_lan}运行模式${reset}" "${gl_bai}systemd 服务${reset}"
  sep_line
  printf "  %s\n" "${gl_bai}常用命令：${reset}"
  printf "    %-46s %s\n" "${gl_hui}systemctl status dufs${reset}" "${gl_lan}# 查看状态${reset}"
  printf "    %-46s %s\n" "${gl_hui}systemctl restart dufs${reset}" "${gl_lan}# 重启服务${reset}"
  printf "    %-46s %s\n" "${gl_hui}systemctl stop dufs${reset}" "${gl_lan}# 停止服务${reset}"
  printf "    %-46s %s\n" "${gl_hui}journalctl -u dufs -f${reset}" "${gl_lan}# 跟随日志${reset}"
  printf "    %-46s %s\n" "${gl_hui}journalctl -u dufs -n 50${reset}" "${gl_lan}# 最近日志${reset}"
  printf "  %s\n" "${gl_hui}升级: 重新执行本脚本即可覆盖二进制并重启（记录自动复用）${reset}"
  printf "  %s\n" "${gl_hui}卸载: bash scripts/uninstall.sh（或远程脚本目录下的 uninstall 说明）${reset}"
else
  printf "  %s\n" "${gl_lv}✔ dufs 安装成功！${reset} ${gl_huang}（后台运行模式）${reset}"
  printf "  %-14s %s\n" "${gl_lan}访问地址${reset}" "${gl_bai}http://${IP}:${PORT}${reset}"
  printf "  %-14s %s\n" "${gl_lan}数据目录${reset}" "${gl_bai}${DATA_DIR}${reset}"
  printf "  %s\n" "  ${gl_huang}注意：${reset}后台运行模式在系统重启后不会自动恢复。"
fi

sep_line