#!/usr/bin/env bash
set -euo pipefail

log_info() { printf '%s[info]%s %s\n' "$C_BLUE" "$C_RESET" "$1"; }
log_ok() { printf '%s[ ok ]%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
log_warn() { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2; }
log_err() { printf '%s[fail]%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; }

setup_colors() {
  if [ -t 1 ]; then
    C_RED="$(printf '\033[31m')"
    C_GREEN="$(printf '\033[32m')"
    C_YELLOW="$(printf '\033[33m')"
    C_BLUE="$(printf '\033[34m')"
    C_RESET="$(printf '\033[0m')"
  else
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_RESET=""
  fi
}

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  --version X       Install a specific version (default: latest release)
  --port N          Listen port (default: 8888)
  --repo owner/name Release repo (default: techshield-tech/tsPanel)
  --tarball PATH    Install from a local tarball instead of downloading
  --db-url URL      Use an existing PostgreSQL database (skip local install)
  --no-firewall     Do not touch ufw/firewalld
  -y                Assume yes / non-interactive
  -h, --help        Show this help

Environment variables TSPANEL_VERSION, TSPANEL_PORT, TSPANEL_REPO,
TSPANEL_TARBALL and TSPANEL_DATABASE_URL are equivalent to the flags above.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
        [ "$#" -ge 2 ] || { log_err "option $1 requires a value"; exit 1; }
        VERSION_OPT="$2"
        shift 2
        ;;
      --port)
        [ "$#" -ge 2 ] || { log_err "option $1 requires a value"; exit 1; }
        PORT="$2"
        shift 2
        ;;
      --repo)
        [ "$#" -ge 2 ] || { log_err "option $1 requires a value"; exit 1; }
        REPO="$2"
        shift 2
        ;;
      --tarball)
        [ "$#" -ge 2 ] || { log_err "option $1 requires a value"; exit 1; }
        TARBALL_OPT="$2"
        shift 2
        ;;
      --db-url)
        [ "$#" -ge 2 ] || { log_err "option $1 requires a value"; exit 1; }
        DB_URL_OPT="$2"
        shift 2
        ;;
      --no-firewall)
        NO_FIREWALL=1
        shift
        ;;
      -y)
        ASSUME_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_err "unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

cleanup() {
  rm -rf "$TMP_DIR"
}

confirm_or_exit() {
  if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then
    return 0
  fi
  local reply
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *)
      log_err "aborted"
      exit 1
      ;;
  esac
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "required command not found: $1"
    exit 1
  fi
}

preflight_checks() {
  if [ "$(id -u)" -ne 0 ]; then
    log_err "this script must be run as root"
    exit 1
  fi

  if [ "$(uname -s)" != "Linux" ]; then
    log_err "this script only supports Linux"
    exit 1
  fi

  if ! command -v systemctl >/dev/null 2>&1 && [ ! -d /run/systemd/system ]; then
    log_err "systemd is required but was not found"
    exit 1
  fi

  case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)
      log_err "unsupported architecture: $(uname -m) (need x86_64 or aarch64)"
      exit 1
      ;;
  esac

  CURL_BIN=""
  WGET_BIN=""
  if command -v curl >/dev/null 2>&1; then
    CURL_BIN="curl"
  elif command -v wget >/dev/null 2>&1; then
    WGET_BIN="wget"
  else
    log_err "either curl or wget is required"
    exit 1
  fi

  require_cmd tar
  require_cmd sha256sum

  log_info "detected architecture: $ARCH"
}

fetch_url() {
  local url="$1"
  local out="$2"
  FETCH_STATUS="000"

  if [ -n "$CURL_BIN" ]; then
    if ! FETCH_STATUS="$(curl -sS -L -o "$out" -w '%{http_code}' "$url")"; then
      FETCH_STATUS="000"
    fi
  else
    local log_file="$TMP_DIR/wget.log"
    if "$WGET_BIN" -q --server-response -O "$out" "$url" 2>"$log_file"; then
      FETCH_STATUS="$(awk '/^  HTTP\// {code=$2} END {print code}' "$log_file")"
      [ -z "$FETCH_STATUS" ] && FETCH_STATUS="200"
    else
      FETCH_STATUS="$(awk '/^  HTTP\// {code=$2} END {print code}' "$log_file")"
      [ -z "$FETCH_STATUS" ] && FETCH_STATUS="000"
    fi
  fi
}

check_fetch_status() {
  local url="$1"
  case "$FETCH_STATUS" in
    2??)
      return 0
      ;;
    404)
      log_err "version not found (HTTP 404): $url"
      log_err "check available releases at https://github.com/$REPO/releases"
      exit 1
      ;;
    *)
      log_err "unexpected HTTP status $FETCH_STATUS fetching $url"
      exit 1
      ;;
  esac
}

read_and_validate_sha256() {
  local sha_file="$1"
  local hash
  hash="$(awk 'NR==1{print $1; exit}' "$sha_file")"
  if ! [[ "$hash" =~ ^[0-9a-fA-F]{64}$ ]]; then
    log_err "invalid or missing sha256 hash in $sha_file"
    exit 1
  fi
  printf '%s' "$hash"
}

resolve_source() {
  RAW_TAG=""
  VER=""
  SRC_TARBALL=""

  if [ -n "$TARBALL_OPT" ]; then
    if [ ! -f "$TARBALL_OPT" ]; then
      log_err "tarball not found: $TARBALL_OPT"
      exit 1
    fi
    SRC_TARBALL="$TARBALL_OPT"
    if [ -f "${TARBALL_OPT}.sha256" ]; then
      log_info "verifying checksum against ${TARBALL_OPT}.sha256"
      local expected actual
      expected="$(read_and_validate_sha256 "${TARBALL_OPT}.sha256")"
      actual="$(sha256sum "$TARBALL_OPT" | awk '{print $1}')"
      if [ "$expected" != "$actual" ]; then
        log_err "checksum mismatch for $TARBALL_OPT"
        exit 1
      fi
      log_ok "checksum verified"
    else
      log_warn "no ${TARBALL_OPT}.sha256 found; skipping checksum verification"
    fi
    return 0
  fi

  if [ -n "$VERSION_OPT" ]; then
    VER="${VERSION_OPT#v}"
    RAW_TAG="v${VER}"
  else
    local latest_url="https://raw.githubusercontent.com/$REPO/main/latest.json"
    log_info "resolving latest version from $latest_url"
    local latest_json="$TMP_DIR/latest.json"
    fetch_url "$latest_url" "$latest_json"
    check_fetch_status "$latest_url"
    VER="$(grep -om1 '"latest"[[:space:]]*:[[:space:]]*"[^"]*"' "$latest_json" | sed -E 's/.*:"([^"]*)"/\1/')"
    if [ -z "$VER" ]; then
      log_err "could not determine latest version from $latest_url"
      exit 1
    fi
    RAW_TAG="v${VER}"
  fi

  log_info "installing tsPanel $VER ($RAW_TAG) for $ARCH"

  local tarball_name="tspanel-${VER}-linux-${ARCH}.tar.gz"
  local download_base="https://github.com/$REPO/releases/download/$RAW_TAG"

  local tarball_path="$TMP_DIR/$tarball_name"
  fetch_url "$download_base/$tarball_name" "$tarball_path"
  check_fetch_status "$download_base/$tarball_name"

  local sha_path="$TMP_DIR/$tarball_name.sha256"
  fetch_url "$download_base/$tarball_name.sha256" "$sha_path"
  check_fetch_status "$download_base/$tarball_name.sha256"

  local expected actual
  expected="$(read_and_validate_sha256 "$sha_path")"
  actual="$(sha256sum "$tarball_path" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    log_err "checksum mismatch for downloaded $tarball_name"
    exit 1
  fi
  log_ok "checksum verified"
  SRC_TARBALL="$tarball_path"
}

extract_tarball() {
  EXTRACT_DIR="$TMP_DIR/extract"
  mkdir -p "$EXTRACT_DIR"
  tar -xzf "$SRC_TARBALL" -C "$EXTRACT_DIR"
  if [ ! -x "$EXTRACT_DIR/tspanel/tspanel" ]; then
    log_err "extracted tarball does not contain tspanel/tspanel"
    exit 1
  fi
  NEW_VERSION="$(cat "$EXTRACT_DIR/tspanel/VERSION" 2>/dev/null || echo "$VER")"
}

determine_mode() {
  IS_UPGRADE=0
  if [ -f "$CONFIG_PATH" ]; then
    IS_UPGRADE=1
  fi
}

create_directories() {
  mkdir -p /www/server /www/wwwroot /www/wwwlogs /www/backup/database /www/backup/path
  mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/data"
}

generate_password() {
  local s
  s="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')"
  printf '%s' "${s:0:32}"
}

run_as_postgres() {
  if command -v runuser >/dev/null 2>&1; then
    (cd / && runuser -u postgres -- "$@")
  else
    local cmd
    printf -v cmd '%q ' "$@"
    (cd / && su - postgres -c "$cmd")
  fi
}

setup_postgres() {
  local os_id="" os_like=""
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-}"
    os_like="${ID_LIKE:-}"
  fi

  case "$os_id $os_like" in
    *debian*|*ubuntu*)
      log_info "installing PostgreSQL via apt"
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y </dev/null
      apt-get install -y postgresql postgresql-contrib </dev/null
      ;;
    *rhel*|*fedora*|*rocky*|*centos*|*almalinux*)
      log_info "installing PostgreSQL via dnf/yum"
      if command -v dnf >/dev/null 2>&1; then
        if dnf -y module list postgresql </dev/null 2>/dev/null | grep -q '16 '; then
          dnf -y module enable postgresql:16 </dev/null || true
        elif dnf -y module list postgresql </dev/null 2>/dev/null | grep -q '15 '; then
          dnf -y module enable postgresql:15 </dev/null || true
        fi
        dnf -y install postgresql-server postgresql-contrib </dev/null
      else
        yum -y install postgresql-server postgresql-contrib </dev/null
      fi
      if [ ! -s /var/lib/pgsql/data/PG_VERSION ]; then
        postgresql-setup --initdb </dev/null || postgresql-setup initdb </dev/null || true
      fi
      ;;
    *)
      log_err "unsupported distribution for automatic PostgreSQL setup (os-release: ID=$os_id ID_LIKE=$os_like)"
      log_err "install PostgreSQL 14+ manually and rerun with --db-url"
      exit 1
      ;;
  esac

  systemctl enable --now postgresql

  local server_version_num
  server_version_num="$(run_as_postgres psql -tAc 'show server_version_num' 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$server_version_num" ] || [ "$server_version_num" -lt 140000 ]; then
    log_err "PostgreSQL server version is too old (need 14 or newer)"
    exit 1
  fi

  local hba_file
  hba_file="$(run_as_postgres psql -tAc 'show hba_file' 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$hba_file" ] && [ -f "$hba_file" ]; then
    sed -E -i.bak \
      -e '/127\.0\.0\.1\/32/ s/\bident\b/scram-sha-256/' \
      -e '/::1\/128/ s/\bident\b/scram-sha-256/' \
      "$hba_file"
    systemctl reload postgresql
  else
    log_warn "could not locate pg_hba.conf; leaving authentication settings untouched"
  fi

  DB_PASSWORD="$(generate_password)"

  local role_exists
  role_exists="$(run_as_postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='tspanel'" 2>/dev/null | tr -d '[:space:]')"
  if [ "$role_exists" = "1" ]; then
    run_as_postgres psql -c "ALTER ROLE tspanel WITH PASSWORD '$DB_PASSWORD'"
  else
    run_as_postgres psql -c "CREATE ROLE tspanel WITH LOGIN PASSWORD '$DB_PASSWORD'"
  fi

  local db_exists
  db_exists="$(run_as_postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='tspanel'" 2>/dev/null | tr -d '[:space:]')"
  if [ "$db_exists" != "1" ]; then
    run_as_postgres psql -c "CREATE DATABASE tspanel OWNER tspanel"
  fi

  DATABASE_URL="postgres://tspanel:${DB_PASSWORD}@127.0.0.1:5432/tspanel?sslmode=disable"
}

yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

write_fresh_config() {
  local port="$1" data_dir="$2" update_url="$3" db_url="$4" out="$5"
  local e_data_dir e_update_url e_db_url
  e_data_dir="$(yaml_escape "$data_dir")"
  e_update_url="$(yaml_escape "$update_url")"
  e_db_url="$(yaml_escape "$db_url")"
  cat > "$out" <<EOF
listenAddr: ":${port}"
basePath: "/"
dataDir: "${e_data_dir}"
uiDir: ""
logLevel: "info"
logFormat: "json"
updateCheckURL: "${e_update_url}"

database:
  url: "${e_db_url}"
EOF
}

rewrite_update_check_url_if_stale() {
  local cfg="$1" new_url="$2"
  local line
  line="$(grep -E '^updateCheckURL:' "$cfg" 2>/dev/null | head -1)"
  case "$line" in
    *git.techshield.vn*)
      local e_new tmp
      e_new="$(yaml_escape "$new_url")"
      tmp="$(mktemp)"
      awk -v repl="updateCheckURL: \"${e_new}\"" '
        BEGIN { done = 0 }
        /^updateCheckURL:/ && !done { print repl; done = 1; next }
        { print }
      ' "$cfg" > "$tmp"
      cat "$tmp" > "$cfg"
      rm -f "$tmp"
      log_info "rewrote updateCheckURL in $cfg to $new_url"
      ;;
  esac
}

read_listen_port_from_config() {
  local cfg="$1"
  local raw port
  raw="$(sed -nE 's/^listenAddr:[[:space:]]*"?([^"[:space:]]*)"?.*/\1/p' "$cfg" 2>/dev/null | head -1)"
  port="${raw##*:}"
  if [[ "$port" =~ ^[0-9]+$ ]]; then
    printf '%s' "$port"
  else
    printf '%s' "$PORT"
  fi
}

install_binary() {
  cp "$EXTRACT_DIR/tspanel/tspanel" "$INSTALL_DIR/tspanel.new"
  chmod 0755 "$INSTALL_DIR/tspanel.new"
  mv -f "$INSTALL_DIR/tspanel.new" "$INSTALL_DIR/tspanel"
}

get_old_version() {
  if [ -x "$INSTALL_DIR/tspanel" ]; then
    "$INSTALL_DIR/tspanel" version 2>/dev/null || echo unknown
  else
    echo unknown
  fi
}

is_our_wrapper() {
  local path="$1"
  [ -f "$path" ] && [ ! -L "$path" ] && grep -qF "BIN=\"${INSTALL_DIR}/tspanel\"" "$path" 2>/dev/null
}

warn_if_foreign_wrapper_target() {
  if [ -e "$WRAPPER_PATH" ] && ! is_our_wrapper "$WRAPPER_PATH"; then
    log_warn "existing file at $WRAPPER_PATH is not the tspanel wrapper; it will be overwritten"
  fi
}

write_wrapper() {
  cat > "$WRAPPER_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail
BIN="${INSTALL_DIR}/tspanel"
CFG="${CONFIG_PATH}"
if [ "\$#" -ge 1 ]; then
  case "\$1" in
    serve|migrate|reset-password|entrance)
      exec "\$BIN" "\$@" --config "\$CFG"
      ;;
  esac
fi
exec "\$BIN" "\$@"
EOF
  chmod 0755 "$WRAPPER_PATH"
}

write_service_unit() {
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=tsPanel server
After=network-online.target postgresql.service
Wants=network-online.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/tspanel serve --config ${CONFIG_PATH}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

http_probe() {
  local host="$1" port="$2"
  if [ -n "$CURL_BIN" ]; then
    if curl -s -o /dev/null --max-time 2 "http://${host}:${port}/"; then
      return 0
    fi
    return 1
  fi
  if [ -n "$WGET_BIN" ]; then
    local rc=0
    wget -q -O /dev/null --timeout=2 --tries=1 "http://${host}:${port}/" 2>/dev/null || rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 8 ]; then
      return 0
    fi
    return 1
  fi
  return 1
}

wait_ready() {
  local port="$1"
  local timeout="${2:-60}"
  local baseline current i
  baseline="$(systemctl show -p NRestarts --value "$SERVICE_NAME" 2>/dev/null || echo 0)"
  for ((i = 0; i < timeout; i++)); do
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
      return 1
    fi
    current="$(systemctl show -p NRestarts --value "$SERVICE_NAME" 2>/dev/null || echo 0)"
    if [ "$current" != "$baseline" ]; then
      return 1
    fi
    if http_probe "127.0.0.1" "$port"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

setup_firewall() {
  if [ "$NO_FIREWALL" = "1" ]; then
    return 0
  fi
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi '^Status: active'; then
    ufw allow "${PORT}/tcp" || true
  fi
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-port="${PORT}/tcp"
    firewall-cmd --reload
  fi
}

finish_fresh_install() {
  local admin_password="" i output
  for ((i = 0; i < 60; i++)); do
    if output="$("$WRAPPER_PATH" reset-password admin 2>&1)"; then
      admin_password="$(printf '%s\n' "$output" | sed -n 's/^new password for admin: //p' | tail -1)"
      if [ -n "$admin_password" ]; then
        break
      fi
    fi
    sleep 1
  done

  if [ -z "$admin_password" ]; then
    log_err "could not reset the admin password after 60s; check: systemctl status $SERVICE_NAME"
    exit 1
  fi

  local entrance
  entrance="$("$WRAPPER_PATH" entrance show 2>&1 || true)"

  local public_ip local_ip
  public_ip="$(curl -s4 --max-time 3 https://ifconfig.me 2>/dev/null || true)"
  local_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

  printf '\n%s=== tsPanel installed ===%s\n' "$C_GREEN" "$C_RESET"
  if [ -n "$public_ip" ]; then
    printf 'Panel URL:    http://%s:%s/\n' "$public_ip" "$PORT"
  fi
  if [ -n "$local_ip" ]; then
    printf 'Panel URL:    http://%s:%s/\n' "$local_ip" "$PORT"
  fi
  printf 'Username:     admin\n'
  printf 'Password:     %s\n' "$admin_password"
  printf 'Entrance:     %s\n' "$entrance"
  printf '\nHandy commands:\n'
  printf '  systemctl status %s\n' "$SERVICE_NAME"
  printf '  journalctl -u %s -f\n' "$SERVICE_NAME"
  printf '  ts reset-password admin\n'
}

print_upgrade_summary() {
  local old="$1" new="$2"
  printf '\n%s=== tsPanel upgraded ===%s\n' "$C_GREEN" "$C_RESET"
  printf 'Old version: %s\n' "$old"
  printf 'New version: %s\n' "$new"
}

main() {
  INSTALL_DIR="/www/server/tspanel"
  CONFIG_PATH="$INSTALL_DIR/config.yaml"
  WRAPPER_PATH="/usr/local/bin/ts"
  SERVICE_NAME="tspanel"
  SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

  REPO="${TSPANEL_REPO:-techshield-tech/tsPanel}"
  PORT="${TSPANEL_PORT:-8888}"
  VERSION_OPT="${TSPANEL_VERSION:-}"
  TARBALL_OPT="${TSPANEL_TARBALL:-}"
  DB_URL_OPT="${TSPANEL_DATABASE_URL:-}"
  NO_FIREWALL=0
  ASSUME_YES=0

  setup_colors
  parse_args "$@"

  TMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  preflight_checks
  resolve_source
  extract_tarball
  determine_mode

  if [ "$IS_UPGRADE" = "1" ]; then
    log_info "existing installation detected at $INSTALL_DIR; performing an upgrade"
  else
    log_info "no existing installation found; performing a fresh install"
  fi

  confirm_or_exit
  create_directories

  local backup_made=0
  local old_port="$PORT"
  local old_version="unknown"

  if [ "$IS_UPGRADE" = "1" ]; then
    old_version="$(get_old_version)"
    old_port="$(read_listen_port_from_config "$CONFIG_PATH")"

    log_info "stopping $SERVICE_NAME"
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    if [ -f "$INSTALL_DIR/tspanel" ]; then
      cp "$INSTALL_DIR/tspanel" "$INSTALL_DIR/tspanel.bak"
      backup_made=1
    fi

    rewrite_update_check_url_if_stale "$CONFIG_PATH" "https://raw.githubusercontent.com/$REPO/main/latest.json"

    install_binary
  else
    if [ -n "$DB_URL_OPT" ]; then
      DATABASE_URL="$DB_URL_OPT"
    else
      setup_postgres
    fi

    UPDATE_CHECK_URL="https://raw.githubusercontent.com/$REPO/main/latest.json"
    write_fresh_config "$PORT" "$INSTALL_DIR/data" "$UPDATE_CHECK_URL" "$DATABASE_URL" "$CONFIG_PATH"
    chmod 0600 "$CONFIG_PATH"
    cp "$EXTRACT_DIR/tspanel/config.example.yaml" "$INSTALL_DIR/config.example.yaml"

    install_binary
  fi

  warn_if_foreign_wrapper_target
  write_wrapper
  write_service_unit
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"

  local target_port="$PORT"
  if [ "$IS_UPGRADE" = "1" ]; then
    target_port="$old_port"
  fi

  if ! wait_ready "$target_port" 60; then
    if [ "$IS_UPGRADE" = "1" ]; then
      log_err "new version failed to become healthy within 60s"
      if [ "$backup_made" = "1" ]; then
        log_err "rolling back to previous binary"
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        cp "$INSTALL_DIR/tspanel.bak" "$INSTALL_DIR/tspanel"
        chmod 0755 "$INSTALL_DIR/tspanel"
        systemctl restart "$SERVICE_NAME" || true
      else
        log_err "no previous binary backup was available; new binary left in place"
      fi
      log_err "upgrade to $NEW_VERSION failed"
      exit 1
    else
      log_err "service failed to become healthy within 60s; check: systemctl status $SERVICE_NAME"
      exit 1
    fi
  fi

  setup_firewall

  if [ "$IS_UPGRADE" = "1" ]; then
    print_upgrade_summary "$old_version" "$NEW_VERSION"
  else
    finish_fresh_install
  fi
}

main "$@"
