#!/usr/bin/env sh
set -eu

WP_ROOT="${WP_ROOT:-/var/www/vhosts/localhost/html}"
WP_CONFIG="${WP_ROOT}/wp-config.php"
WP_CONFIG_SAMPLE="${WP_ROOT}/wp-config-sample.php"
DB_INIT_FLAG="${WP_ROOT}/.ols-wp-db-initialized"
OLS_WP_TEST_MODE="${OLS_WP_TEST_MODE:-0}"

# default values
DEFAULT_DB_PORT="3306"
DEFAULT_DB_CHARSET="utf8mb4"
DEFAULT_TABLE_PREFIX="wp_"
DEFAULT_INIT_SQL_FILE="/docker-entrypoint-initdb.d/init.sql"

log() {
  printf '[ols-wp] %s\n' "$*"
}

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    printf '[ols-wp] ERROR: required environment variable is missing: %s\n' "$name" >&2
    exit 1
  fi
}

escape_php_single_quoted() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&/]/\\&/g'
}

set_config_value() {
  key="$1"
  value="$(escape_php_single_quoted "$2")"
  escaped_value="$(escape_sed_replacement "$value")"

  if grep -q "define( *['\"]${key}['\"]" "$WP_CONFIG"; then
    sed -i "s/define( *['\"]${key}['\"].*/define( '${key}', '${escaped_value}' );/" "$WP_CONFIG"
  else
    sed -i "/\/\* That's all, stop editing!/i define( '${key}', '${escaped_value}' );" "$WP_CONFIG"
  fi
}

set_config_raw() {
  key="$1"
  value="$2"

  if grep -q "define( *['\"]${key}['\"]" "$WP_CONFIG"; then
    sed -i "s/define( *['\"]${key}['\"].*/define( '${key}', ${value} );/" "$WP_CONFIG"
  else
    sed -i "/\/\* That's all, stop editing!/i define( '${key}', ${value} );" "$WP_CONFIG"
  fi
}

insert_before_stop_marker() {
  content="$1"
  tmp_file="${WP_CONFIG}.tmp"
  awk -v content="$content" '
    /That.s all, stop editing!/ {
      print "";
      print content;
      print "";
    }
    { print }
  ' "$WP_CONFIG" > "$tmp_file"
  mv "$tmp_file" "$WP_CONFIG"
}

remove_managed_wp_config_entries() {
  sed -i \
    -e "/\/\* ols-wp managed config:start \*\//,/\/\* ols-wp managed config:end \*\//d" \
    -e "/\/\* ols-wp salts \*\//d" \
    -e "/\/\* ols-wp reverse proxy HTTPS detection \*\//,/^}/d" \
    -e "/define( *['\"]AUTH_KEY['\"] */d" \
    -e "/define( *['\"]SECURE_AUTH_KEY['\"] */d" \
    -e "/define( *['\"]LOGGED_IN_KEY['\"] */d" \
    -e "/define( *['\"]NONCE_KEY['\"] */d" \
    -e "/define( *['\"]AUTH_SALT['\"] */d" \
    -e "/define( *['\"]SECURE_AUTH_SALT['\"] */d" \
    -e "/define( *['\"]LOGGED_IN_SALT['\"] */d" \
    -e "/define( *['\"]NONCE_SALT['\"] */d" \
    -e "/define( *['\"]DISALLOW_FILE_EDIT['\"] */d" \
    -e "/define( *['\"]FORCE_SSL_ADMIN['\"] */d" \
    -e "/define( *['\"]WP_HOME['\"] */d" \
    -e "/define( *['\"]WP_SITEURL['\"] */d" \
    "$WP_CONFIG"
}

render_php_define_string() {
  key="$1"
  value="$(escape_php_single_quoted "$2")"
  printf "define( '%s', '%s' );\n" "$key" "$value"
}

render_php_define_raw() {
  key="$1"
  value="$2"
  printf "define( '%s', %s );\n" "$key" "$value"
}

build_managed_wp_config_block() {
  salts="$(generate_salts)"

  printf '%s\n' '/* ols-wp managed config:start */'
  printf '%s\n' "$salts"
  render_php_define_raw DISALLOW_FILE_EDIT "${WORDPRESS_DISALLOW_FILE_EDIT:-true}"
  render_php_define_raw FORCE_SSL_ADMIN "${WORDPRESS_FORCE_SSL_ADMIN:-false}"

  if [ -n "${WORDPRESS_HOME:-}" ]; then
    render_php_define_string WP_HOME "$WORDPRESS_HOME"
  fi

  if [ -n "${WORDPRESS_SITEURL:-}" ]; then
    render_php_define_string WP_SITEURL "$WORDPRESS_SITEURL"
  fi

  if [ -n "${WORDPRESS_BEHIND_PROXY:-1}" ]; then
    cat <<'PHP'
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
    $_SERVER['HTTPS'] = 'on';
}
PHP
  fi

  if [ -n "${WORDPRESS_CONFIG_EXTRA:-}" ]; then
    printf '%s\n' "$WORDPRESS_CONFIG_EXTRA"
  fi

  printf '%s\n' '/* ols-wp managed config:end */'
}

replace_managed_wp_config_block() {
  remove_managed_wp_config_entries
  managed_block="$(build_managed_wp_config_block)"
  insert_before_stop_marker "$managed_block"
}

generate_salts() {
  if command -v curl >/dev/null 2>&1; then
    salts="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ || true)"
  else
    salts=""
  fi

  if [ -n "$salts" ]; then
    printf '%s\n' "$salts"
  else
    for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
      value="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9!@#%^&*()_+=-' | head -c 64)"
      printf "define( '%s', '%s' );\n" "$key" "$value"
    done
  fi
}

parse_db_host() {
  DB_HOST_ONLY="$WORDPRESS_DB_HOST"
  DB_PORT_ONLY="${WORDPRESS_DB_PORT:-$DEFAULT_DB_PORT}"

  case "$WORDPRESS_DB_HOST" in
    *:*)
      DB_HOST_ONLY="${WORDPRESS_DB_HOST%%:*}"
      DB_PORT_ONLY="${WORDPRESS_DB_HOST##*:}"
      ;;
  esac
}

mariadb_server_cmd() {
  mariadb \
    --protocol=tcp \
    --host="$DB_HOST_ONLY" \
    --port="$DB_PORT_ONLY" \
    --user="$WORDPRESS_DB_USER" \
    --password="$WORDPRESS_DB_PASSWORD" \
    "$@"
}

mariadb_cmd() {
  mariadb \
    --protocol=tcp \
    --host="$DB_HOST_ONLY" \
    --port="$DB_PORT_ONLY" \
    --user="$WORDPRESS_DB_USER" \
    --password="$WORDPRESS_DB_PASSWORD" \
    --database="$WORDPRESS_DB_NAME" \
    "$@"
}

print_mariadb_error_hint() {
  error_message="$1"

  case "$error_message" in
    *"ERROR 2002"*|*"ERROR 2003"*|*"ERROR 2005"*)
      printf '[ols-wp] ERROR DETAIL: database server network/host/port check failed. Check WORDPRESS_DB_HOST, Docker network, database container status, and configured database port %s.\n' "$DB_PORT_ONLY" >&2
      ;;
    *"ERROR 1045"*)
      printf '[ols-wp] ERROR DETAIL: database authentication failed. Check database username, password, and host-based access privileges.\n' >&2
      ;;
    *"ERROR 1049"*)
      printf '[ols-wp] ERROR DETAIL: target database does not exist. Create database `%s` first, or fix WORDPRESS_DB_NAME.\n' "$WORDPRESS_DB_NAME" >&2
      ;;
    *)
      printf '[ols-wp] ERROR DETAIL: database operation failed for an unknown reason. Raw mariadb error follows.\n' >&2
      ;;
  esac

  printf '%s\n' "$error_message" >&2
}

check_database_server_connection() {
  parse_db_host
  log "starting database server connectivity check: ${DB_HOST_ONLY}:${DB_PORT_ONLY}"

  set +e
  db_error="$(mariadb_server_cmd --connect-timeout=5 --execute="SELECT 1" 2>&1 >/dev/null)"
  db_status="$?"
  set -e

  if [ "$db_status" = "0" ]; then
    log "database server connectivity check OK"
    return 0
  fi

  printf '[ols-wp] ERROR: database server connectivity check failed: %s:%s\n' "$DB_HOST_ONLY" "$DB_PORT_ONLY" >&2
  print_mariadb_error_hint "$db_error"
  exit 1
}

ensure_database_exists() {
  escaped_db_name="$(printf '%s' "$WORDPRESS_DB_NAME" | sed 's/`/``/g')"
  charset="${WORDPRESS_DB_CHARSET:-$DEFAULT_DB_CHARSET}"
  collate="${WORDPRESS_DB_COLLATE:-}"

  if [ -n "$collate" ]; then
    create_database_sql="CREATE DATABASE IF NOT EXISTS \`${escaped_db_name}\` DEFAULT CHARACTER SET ${charset} COLLATE ${collate};"
  else
    create_database_sql="CREATE DATABASE IF NOT EXISTS \`${escaped_db_name}\` DEFAULT CHARACTER SET ${charset};"
  fi

  log "ensuring target database exists: ${WORDPRESS_DB_NAME}"

  set +e
  db_error="$(mariadb_server_cmd --execute="$create_database_sql" 2>&1 >/dev/null)"
  db_status="$?"
  set -e

  if [ "$db_status" = "0" ]; then
    log "target database is ready: ${WORDPRESS_DB_NAME}"
    return 0
  fi

  printf '[ols-wp] ERROR: target database creation or access failed: `%s`\n' "$WORDPRESS_DB_NAME" >&2
  print_mariadb_error_hint "$db_error"
  exit 1
}

check_database_connection() {
  log "starting database connectivity check: ${DB_HOST_ONLY}:${DB_PORT_ONLY}/${WORDPRESS_DB_NAME}"

  set +e
  db_error="$(mariadb_cmd --connect-timeout=5 --execute="SELECT 1" 2>&1 >/dev/null)"
  db_status="$?"
  set -e

  if [ "$db_status" = "0" ]; then
    log "database connectivity check OK"
    return 0
  fi

  printf '[ols-wp] ERROR: database connectivity check failed: %s:%s/%s\n' "$DB_HOST_ONLY" "$DB_PORT_ONLY" "$WORDPRESS_DB_NAME" >&2
  print_mariadb_error_hint "$db_error"
  exit 1
}

initialize_database() {
  init_sql="${WORDPRESS_INIT_SQL_FILE:-$DEFAULT_INIT_SQL_FILE}"

  if [ ! -s "$init_sql" ]; then
    printf '[ols-wp] ERROR: initialization SQL file is missing or empty: %s\n' "$init_sql" >&2
    exit 1
  fi

  log "starting SQL import: ${init_sql}"
  import_error_file="$(mktemp)"
  if mariadb_cmd < "$init_sql" 2>"$import_error_file"; then
    rm -f "$import_error_file"
    log "SQL import completed successfully"
    return 0
  fi

  import_status="$?"
  printf '[ols-wp] ERROR: SQL import failed: %s\n' "$init_sql" >&2
  cat "$import_error_file" >&2
  rm -f "$import_error_file"
  exit "$import_status"
}

require_env WORDPRESS_DB_HOST
require_env WORDPRESS_DB_NAME
require_env WORDPRESS_DB_USER
require_env WORDPRESS_DB_PASSWORD

if [ "$OLS_WP_TEST_MODE" != "1" ]; then
  check_database_server_connection
  ensure_database_exists
  check_database_connection
fi

# 首次启动：从 sample 创建 wp-config.php
if [ ! -f "$WP_CONFIG" ]; then
  log "first-time setup: creating wp-config.php from sample"

  if [ ! -f "$WP_CONFIG_SAMPLE" ]; then
    printf '[ols-wp] ERROR: wp-config-sample.php not found: %s\n' "$WP_CONFIG_SAMPLE" >&2
    exit 1
  fi

  cp "$WP_CONFIG_SAMPLE" "$WP_CONFIG"
  log "wp-config.php created successfully"
else
  log "wp-config.php already exists, updating configuration"
fi

# 每次启动都更新数据库连接配置
log "updating database connection settings"
set_config_value DB_NAME "$WORDPRESS_DB_NAME"
set_config_value DB_USER "$WORDPRESS_DB_USER"
set_config_value DB_PASSWORD "$WORDPRESS_DB_PASSWORD"
set_config_value DB_HOST "$WORDPRESS_DB_HOST"
set_config_value DB_CHARSET "${WORDPRESS_DB_CHARSET:-$DEFAULT_DB_CHARSET}"
set_config_value DB_COLLATE "${WORDPRESS_DB_COLLATE:-}"

table_prefix_value="${WORDPRESS_TABLE_PREFIX:-$DEFAULT_TABLE_PREFIX}"
sed -i "s/^\$table_prefix *=.*/\$table_prefix = '${table_prefix_value}';/" "$WP_CONFIG"

set_config_raw WP_DEBUG "${WORDPRESS_DEBUG:-false}"

# 每次启动都更新受管配置块
log "updating managed configuration block"
replace_managed_wp_config_block

# 只在首次启动时导入数据库
if [ ! -f "$DB_INIT_FLAG" ]; then
  if [ "$OLS_WP_TEST_MODE" != "1" ]; then
    log "first-time database initialization"
    initialize_database
    touch "$DB_INIT_FLAG"
    log "database initialization completed"
  else
    log "test mode: skipping database initialization"
    touch "$DB_INIT_FLAG"
  fi
else
  log "database already initialized, skipping SQL import"
fi

if command -v chown >/dev/null 2>&1; then
  chown -R nobody:nogroup "$WP_ROOT" 2>/dev/null || chown -R nobody:nobody "$WP_ROOT" 2>/dev/null || true
fi

exec "$@"
