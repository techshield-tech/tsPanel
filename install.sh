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
  --tarball PATH    Install from a local tarball instead of downloading. The
                    tarball must sit next to SHA256SUMS and SHA256SUMS.sig
                    (signature is verified), or have a PATH.sha256 file
                    (integrity only), unless --insecure is given
  --insecure        With --tarball: skip all verification (use only for a
                    tarball you have verified yourself)
  --db-url URL      Use an existing PostgreSQL database (skip local install)
  --no-firewall     Do not touch ufw/firewalld
  --skip-db-backup  On upgrade, do not pg_dump the panel database first
  -y                Assume yes / non-interactive
  -h, --help        Show this help

Environment variables TSPANEL_VERSION, TSPANEL_PORT, TSPANEL_REPO,
TSPANEL_TARBALL and TSPANEL_DATABASE_URL are equivalent to the flags above.
TSPANEL_PUBLIC_KEY overrides the embedded ed25519 release signing key (base64).
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
      --insecure)
        INSECURE=1
        shift
        ;;
      --skip-db-backup)
        SKIP_DB_BACKUP=1
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

require_valid_version() {
  local v="$1" source="$2"
  if [ "${#v}" -gt 64 ] || ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+(\.[0-9A-Za-z]+)*)?$ ]]; then
    log_err "invalid version string from $source: '$v'"
    exit 1
  fi
}

require_ed25519_verifier() {
  require_cmd openssl
  require_cmd base64
  if ! openssl genpkey -algorithm ED25519 >/dev/null 2>&1; then
    log_err "this OpenSSL ($(openssl version 2>/dev/null || echo unknown)) cannot verify Ed25519 signatures; OpenSSL 1.1.1 or newer is required"
    log_err "upgrade OpenSSL, or download the release yourself, verify SHA256SUMS.sig, and rerun with --tarball PATH --insecure"
    exit 1
  fi
}

write_public_key_pem() {
  local out="$1" raw="$TMP_DIR/public-key.raw"
  if ! printf '%s' "$PUBLIC_KEY" | base64 -d > "$raw" 2>/dev/null || [ "$(wc -c < "$raw")" -ne 32 ]; then
    log_err "the release signing public key is not a base64-encoded 32-byte ed25519 key"
    exit 1
  fi
  {
    echo "-----BEGIN PUBLIC KEY-----"
    { printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; cat "$raw"; } | base64 -w0 | fold -w64
    echo
    echo "-----END PUBLIC KEY-----"
  } > "$out"
}

verify_signature() {
  local file="$1" sig_file="$2"
  local pem="$TMP_DIR/public-key.pem" msg="$TMP_DIR/signed.msg" sig_raw="$TMP_DIR/signature.raw"
  [ -f "$pem" ] || write_public_key_pem "$pem"
  printf '%s' "$(sha256sum "$file" | awk '{print $1}')" > "$msg"
  if ! tr -d '[:space:]' < "$sig_file" | base64 -d > "$sig_raw" 2>/dev/null || [ "$(wc -c < "$sig_raw")" -ne 64 ]; then
    return 1
  fi
  if openssl pkeyutl -verify -pubin -inkey "$pem" -rawin -in "$msg" -sigfile "$sig_raw" >/dev/null 2>&1; then
    return 0
  fi
  if openssl pkeyutl -verify -pubin -inkey "$pem" -in "$msg" -sigfile "$sig_raw" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

require_valid_signature() {
  local file="$1" sig_file="$2" what="$3"
  if ! verify_signature "$file" "$sig_file"; then
    log_err "signature verification FAILED for $what; refusing to continue"
    exit 1
  fi
  log_ok "signature verified: $what"
}

fetch_signature() {
  local url="$1" out="$2"
  fetch_url "$url" "$out"
  case "$FETCH_STATUS" in
    2??) return 0 ;;
    404)
      log_err "signature not found (HTTP 404): $url"
      log_err "this release is not signed, so it cannot be installed"
      exit 1
      ;;
    *)
      log_err "unexpected HTTP status $FETCH_STATUS fetching $url"
      exit 1
      ;;
  esac
}

sums_entry() {
  local sums_file="$1" name="$2"
  awk -v n="$name" '{ f = $2; sub(/^\*/, "", f); if (f == n) { print $1; exit } }' "$sums_file"
}

verify_file_against_sums() {
  local sums_file="$1" file="$2"
  local name expected actual
  name="$(basename "$file")"
  expected="$(sums_entry "$sums_file" "$name")"
  if ! [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
    log_err "SHA256SUMS has no valid entry for $name"
    exit 1
  fi
  actual="$(sha256sum "$file" | awk '{print $1}')"
  if [ "${expected,,}" != "${actual,,}" ]; then
    log_err "checksum mismatch for $name"
    exit 1
  fi
  log_ok "checksum verified: $name"
}

verify_local_tarball() {
  local tarball="$1"
  local dir
  dir="$(dirname "$tarball")"

  if [ "$INSECURE" = "1" ]; then
    log_warn "--insecure: installing $tarball WITHOUT signature or checksum verification"
    return 0
  fi

  if [ -f "$dir/SHA256SUMS" ] && [ -f "$dir/SHA256SUMS.sig" ]; then
    require_ed25519_verifier
    require_valid_signature "$dir/SHA256SUMS" "$dir/SHA256SUMS.sig" "$dir/SHA256SUMS"
    verify_file_against_sums "$dir/SHA256SUMS" "$tarball"
    return 0
  fi

  if [ -f "${tarball}.sha256" ]; then
    log_warn "verifying ${tarball}.sha256 (integrity only; no signature available)"
    local expected actual
    expected="$(read_and_validate_sha256 "${tarball}.sha256")"
    actual="$(sha256sum "$tarball" | awk '{print $1}')"
    if [ "${expected,,}" != "${actual,,}" ]; then
      log_err "checksum mismatch for $tarball"
      exit 1
    fi
    log_ok "checksum verified"
    return 0
  fi

  log_err "cannot verify $tarball: place SHA256SUMS and SHA256SUMS.sig next to it, provide ${tarball}.sha256, or pass --insecure"
  exit 1
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
    verify_local_tarball "$TARBALL_OPT"
    SRC_TARBALL="$TARBALL_OPT"
    return 0
  fi

  require_ed25519_verifier

  if [ -n "$VERSION_OPT" ]; then
    VER="${VERSION_OPT#v}"
    require_valid_version "$VER" "--version"
    RAW_TAG="v${VER}"
  else
    local latest_url="https://raw.githubusercontent.com/$REPO/main/latest.json"
    log_info "resolving latest version from $latest_url"
    local latest_json="$TMP_DIR/latest.json" latest_sig="$TMP_DIR/latest.json.sig"
    fetch_url "$latest_url" "$latest_json"
    check_fetch_status "$latest_url"
    fetch_signature "${latest_url}.sig" "$latest_sig"
    require_valid_signature "$latest_json" "$latest_sig" "latest.json"
    VER="$(grep -om1 '"latest"[[:space:]]*:[[:space:]]*"[^"]*"' "$latest_json" | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
    if [ -z "$VER" ]; then
      log_err "could not determine latest version from $latest_url"
      exit 1
    fi
    require_valid_version "$VER" "$latest_url"
    RAW_TAG="v${VER}"
  fi

  log_info "installing tsPanel $VER ($RAW_TAG) for $ARCH"

  local tarball_name="tspanel-${VER}-linux-${ARCH}.tar.gz"
  local download_base="https://github.com/$REPO/releases/download/$RAW_TAG"

  local sums_path="$TMP_DIR/SHA256SUMS" sums_sig_path="$TMP_DIR/SHA256SUMS.sig"
  fetch_url "$download_base/SHA256SUMS" "$sums_path"
  check_fetch_status "$download_base/SHA256SUMS"
  fetch_signature "$download_base/SHA256SUMS.sig" "$sums_sig_path"
  require_valid_signature "$sums_path" "$sums_sig_path" "SHA256SUMS ($RAW_TAG)"

  local tarball_path="$TMP_DIR/$tarball_name"
  fetch_url "$download_base/$tarball_name" "$tarball_path"
  check_fetch_status "$download_base/$tarball_name"

  verify_file_against_sums "$sums_path" "$tarball_path"
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
  if [ -f "$COMPLETE_MARKER" ]; then
    IS_UPGRADE=1
  elif [ -f "$CONFIG_PATH" ] && [ ! -f "$INCOMPLETE_MARKER" ]; then
    IS_UPGRADE=1
  fi
}

mark_install_started() {
  mkdir -p "$INSTALL_DIR"
  rm -f "$COMPLETE_MARKER"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$INCOMPLETE_MARKER"
}

mark_install_complete() {
  date -u +%Y-%m-%dT%H:%M:%SZ > "$COMPLETE_MARKER"
  rm -f "$INCOMPLETE_MARKER"
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
  if [ -f "$EXTRACT_DIR/tspanel/uninstall.sh" ]; then
    cp "$EXTRACT_DIR/tspanel/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
    chmod 0755 "$INSTALL_DIR/uninstall.sh"
  fi
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
    uninstall)
      shift
      exec bash "${INSTALL_DIR}/uninstall.sh" "\$@"
      ;;
    serve|migrate|reset-password|entrance|domain)
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
    if curl -sk -o /dev/null --max-time 2 "https://${host}:${port}/" ||
      curl -s -o /dev/null --max-time 2 "http://${host}:${port}/"; then
      return 0
    fi
    return 1
  fi
  if [ -n "$WGET_BIN" ]; then
    local rc=0
    wget -q --no-check-certificate -O /dev/null --timeout=2 --tries=1 "https://${host}:${port}/" 2>/dev/null || rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 8 ]; then
      return 0
    fi
    rc=0
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
  local port="$1"
  if [ "$NO_FIREWALL" = "1" ]; then
    return 0
  fi
  local agent_port=8889
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi '^Status: active'; then
    ufw allow "${port}/tcp" || true
    ufw allow "${agent_port}/tcp" || true
  fi
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-port="${port}/tcp"
    firewall-cmd --permanent --add-port="${agent_port}/tcp"
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

  local entrance entrance_path entrance_line
  entrance="$("$WRAPPER_PATH" entrance show 2>&1 || true)"
  entrance_path="$(printf '%s\n' "$entrance" | sed -n 's/^entrance path: //p' | head -1)"

  local public_ip local_ip
  public_ip="$(curl -s4 --max-time 3 https://ifconfig.me 2>/dev/null || true)"
  local_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

  local panel_domain
  panel_domain="$("$WRAPPER_PATH" domain show 2>/dev/null | sed -n 's/^panel domain: //p' | head -1 || true)"

  entrance_line=""
  if [ -n "$entrance_path" ]; then
    if [ -n "$panel_domain" ]; then
      entrance_line="https://${panel_domain}:${PORT}${entrance_path}"
    elif [ -n "$public_ip" ]; then
      entrance_line="https://${public_ip}:${PORT}${entrance_path}"
    elif [ -n "$local_ip" ]; then
      entrance_line="https://${local_ip}:${PORT}${entrance_path}"
    else
      entrance_line="$entrance_path"
    fi
  fi

  printf '\n%s=== tsPanel installed ===%s\n' "$C_GREEN" "$C_RESET"
  if [ -n "$public_ip" ]; then
    printf 'Panel URL:    https://%s:%s/\n' "$public_ip" "$PORT"
  fi
  if [ -n "$local_ip" ] && [ "$local_ip" != "$public_ip" ]; then
    printf 'Panel URL:    https://%s:%s/\n' "$local_ip" "$PORT"
  fi
  printf 'Username:     admin\n'
  printf 'Password:     %s\n' "$admin_password"
  if [ -n "$entrance_line" ]; then
    printf 'Entrance:     %s   (the only URL that opens the panel; save it)\n' "$entrance_line"
  fi
  printf '\nHandy commands:\n'
  printf '  systemctl status %s\n' "$SERVICE_NAME"
  printf '  journalctl -u %s -f\n' "$SERVICE_NAME"
  printf '  ts reset-password admin\n'
}

read_config_scalar() {
  local cfg="$1" key="$2"
  sed -nE "s/^${key}:[[:space:]]*(\"(([^\"\\\\]|\\\\.)*)\"|'([^']*)'|([^[:space:]#]*)).*/\2\4\5/p" "$cfg" 2>/dev/null | head -1 | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

read_database_url_from_config() {
  local cfg="$1"
  awk '
    /^database:/ { in_db = 1; next }
    in_db && /^[^[:space:]#]/ { in_db = 0 }
    in_db && /^[[:space:]]+url:/ { sub(/^[[:space:]]+url:[[:space:]]*/, ""); print; exit }
  ' "$cfg" 2>/dev/null | sed -E \
    -e "s/^\"(([^\"\\\\]|\\\\.)*)\".*/\1/" \
    -e "s/^'([^']*)'.*/\1/" \
    -e 's/[[:space:]]+#.*$//' \
    -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

pct_decode() {
  printf '%b' "${1//%/\\x}"
}

build_pg_env() {
  local url="$1" rest query hostpath userinfo hostport db user pass host port sslmode
  case "$url" in
    postgres://*|postgresql://*) ;;
    *) return 1 ;;
  esac
  rest="${url#*://}"
  query=""
  case "$rest" in
    *\?*)
      query="${rest#*\?}"
      rest="${rest%%\?*}"
      ;;
  esac
  userinfo=""
  hostpath="$rest"
  case "$rest" in
    *@*)
      userinfo="${rest%@*}"
      hostpath="${rest##*@}"
      ;;
  esac
  hostport="${hostpath%%/*}"
  db=""
  case "$hostpath" in
    */*) db="${hostpath#*/}" ;;
  esac
  user="${userinfo%%:*}"
  pass=""
  case "$userinfo" in
    *:*) pass="${userinfo#*:}" ;;
  esac
  case "$hostport" in
    \[*\]*)
      host="${hostport%%\]*}"
      host="${host#\[}"
      port=""
      case "$hostport" in
        *\]:*) port="${hostport##*\]:}" ;;
      esac
      ;;
    *:*)
      host="${hostport%%:*}"
      port="${hostport##*:}"
      ;;
    *)
      host="$hostport"
      port=""
      ;;
  esac
  sslmode=""
  case "&${query}&" in
    *\&sslmode=*)
      sslmode="${query#*sslmode=}"
      sslmode="${sslmode%%&*}"
      ;;
  esac

  PG_DBNAME="$(pct_decode "$db")"
  if [ -z "$PG_DBNAME" ]; then
    return 1
  fi
  PG_ENV=()
  [ -n "$user" ] && PG_ENV+=("PGUSER=$(pct_decode "$user")")
  [ -n "$pass" ] && PG_ENV+=("PGPASSWORD=$(pct_decode "$pass")")
  [ -n "$host" ] && PG_ENV+=("PGHOST=$(pct_decode "$host")")
  [ -n "$port" ] && PG_ENV+=("PGPORT=$port")
  [ -n "$sslmode" ] && PG_ENV+=("PGSSLMODE=$sslmode")
  PG_ENV+=("PGCONNECT_TIMEOUT=10")
  return 0
}

prune_db_backups() {
  local dir="$1" keep=3 f
  ls -1t "$dir"/tspanel-db-*.dump 2>/dev/null | tail -n +$((keep + 1)) | while IFS= read -r f; do
    rm -f -- "$f"
  done
}

backup_database() {
  DB_BACKUP_FILE=""
  local db_url data_dir dump_dir safe_version stamp file
  db_url="$(read_database_url_from_config "$CONFIG_PATH")"
  if [ -z "$db_url" ]; then
    log_err "could not read database.url from $CONFIG_PATH"
    return 1
  fi
  if ! build_pg_env "$db_url"; then
    log_err "database.url is not a postgres:// URL with a database name; cannot back it up"
    return 1
  fi
  if ! command -v pg_dump >/dev/null 2>&1; then
    log_err "pg_dump not found; install the PostgreSQL client tools"
    return 1
  fi

  data_dir="$(read_config_scalar "$CONFIG_PATH" dataDir)"
  [ -n "$data_dir" ] || data_dir="$INSTALL_DIR/data"
  dump_dir="$data_dir/db-backups"
  mkdir -p "$dump_dir"
  chmod 0700 "$dump_dir"

  safe_version="${old_version//[^0-9A-Za-z._-]/_}"
  stamp="$(date +%Y%m%d-%H%M%S)"
  file="$dump_dir/tspanel-db-${stamp}-v${safe_version}.dump"

  log_info "backing up the panel database to $file"
  if ! env "${PG_ENV[@]}" pg_dump --format=custom --no-owner --file="$file.partial" "$PG_DBNAME"; then
    rm -f -- "$file.partial"
    log_err "pg_dump failed"
    return 1
  fi
  chmod 0600 "$file.partial"
  mv -f "$file.partial" "$file"
  prune_db_backups "$dump_dir"
  DB_BACKUP_FILE="$file"
  log_ok "database backup written"
}

restore_database() {
  local file="$1" db_url
  db_url="$(read_database_url_from_config "$CONFIG_PATH")"
  if ! build_pg_env "$db_url"; then
    log_err "cannot parse database.url; restore $file manually with pg_restore"
    return 1
  fi
  if ! command -v pg_restore >/dev/null 2>&1 || ! command -v psql >/dev/null 2>&1; then
    log_err "psql/pg_restore not found; restore $file manually"
    return 1
  fi
  log_info "restoring the panel database from $file"
  env "${PG_ENV[@]}" psql --no-psqlrc -q -d "$PG_DBNAME" -c 'DROP OWNED BY CURRENT_USER CASCADE' ||
    log_warn "could not drop existing objects; relying on pg_restore --clean"
  if ! env "${PG_ENV[@]}" pg_restore --clean --if-exists --no-owner --dbname="$PG_DBNAME" "$file"; then
    log_err "pg_restore reported errors; the dump is kept at $file"
    return 1
  fi
  log_ok "database restored"
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
  COMPLETE_MARKER="$INSTALL_DIR/.install-complete"
  INCOMPLETE_MARKER="$INSTALL_DIR/.install-incomplete"
  WRAPPER_PATH="/usr/local/bin/ts"
  SERVICE_NAME="tspanel"
  SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

  REPO="${TSPANEL_REPO:-techshield-tech/tsPanel}"
  PORT="${TSPANEL_PORT:-8888}"
  VERSION_OPT="${TSPANEL_VERSION:-}"
  TARBALL_OPT="${TSPANEL_TARBALL:-}"
  DB_URL_OPT="${TSPANEL_DATABASE_URL:-}"
  PUBLIC_KEY="${TSPANEL_PUBLIC_KEY:-qHG69umeIaHc+ibIirdy2B9TWlEC2os4Ui4sqtObYx0=}"
  NO_FIREWALL=0
  ASSUME_YES=0
  INSECURE=0
  SKIP_DB_BACKUP=0

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
  DB_BACKUP_FILE=""

  if [ "$IS_UPGRADE" = "1" ]; then
    old_version="$(get_old_version)"
    old_port="$(read_listen_port_from_config "$CONFIG_PATH")"

    log_info "stopping $SERVICE_NAME"
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    if [ "$SKIP_DB_BACKUP" = "1" ]; then
      log_warn "--skip-db-backup: the panel database will not be backed up before upgrading"
    elif ! backup_database; then
      log_err "aborting the upgrade before touching the binary; rerun with --skip-db-backup to upgrade without a database backup"
      systemctl start "$SERVICE_NAME" 2>/dev/null || true
      exit 1
    fi

    if [ -f "$INSTALL_DIR/tspanel" ]; then
      cp "$INSTALL_DIR/tspanel" "$INSTALL_DIR/tspanel.bak"
      backup_made=1
    fi

    rewrite_update_check_url_if_stale "$CONFIG_PATH" "https://raw.githubusercontent.com/$REPO/main/latest.json"

    install_binary
  else
    mark_install_started

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
        if [ -n "$DB_BACKUP_FILE" ]; then
          restore_database "$DB_BACKUP_FILE" || log_err "database restore failed; the old binary may not start against the migrated schema"
        fi
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

  setup_firewall "$target_port"

  if [ "$IS_UPGRADE" = "1" ]; then
    mark_install_complete
    print_upgrade_summary "$old_version" "$NEW_VERSION"
    if [ -n "$DB_BACKUP_FILE" ]; then
      printf 'DB backup:   %s\n' "$DB_BACKUP_FILE"
    fi
  else
    finish_fresh_install
    mark_install_complete
  fi
}

main "$@"
