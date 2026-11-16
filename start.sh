#!/bin/bash
# SuiteCRM start script for Railway.
# First boot: copy SuiteCRM onto the volume, wait for MariaDB, run the official
# CLI installer with a generated admin password. Every boot: point site_url at
# the current domain, start the scheduler loop, then Apache.
set -euo pipefail

export PORT="${PORT:-8080}"
APP=/var/www/html
LEGACY="$APP/public/legacy"
MARKER="$APP/.railway-suitecrm-version"

: "${DB_HOST:?DB_HOST is not set (reference the MariaDB service)}"
: "${DB_USER:?DB_USER is not set}"
: "${DB_PASSWORD:?DB_PASSWORD is not set}"
DB_NAME="${DB_NAME:-suitecrm}"
DB_PORT="${DB_PORT:-3306}"
ADMIN_USER="${SUITECRM_ADMIN_USER:-admin}"
SITE_URL="${SUITECRM_SITE_URL:-http://localhost:${PORT}}"
SITE_URL="${SITE_URL%/}"

as_www() { setpriv --reuid=www-data --regid=www-data --init-groups "$@"; }
log() { echo "[suitecrm-start] $*"; }

# Serve a "being set up" page on PORT while the first boot runs, so the
# health check passes and nobody sees an error or an open installer.
SETUP_PID=""
start_setup_page() {
  php -S "0.0.0.0:${PORT}" -t /opt/setup-page /opt/setup-page/index.php >/dev/null 2>&1 &
  SETUP_PID=$!
}
stop_setup_page() {
  if [ -n "$SETUP_PID" ]; then kill "$SETUP_PID" 2>/dev/null || true; wait "$SETUP_PID" 2>/dev/null || true; SETUP_PID=""; fi
}
trap stop_setup_page EXIT

is_installed() {
  [ -f "$LEGACY/config.php" ] && php -r 'include getenv("LEGACY")."/config.php"; exit(empty($sugar_config["installer_locked"]) ? 1 : 0);'
}
export LEGACY

if [ ! -f "$MARKER" ] || ! is_installed; then
  start_setup_page
fi

# 1. Code onto the volume (first boot only).
if [ ! -f "$MARKER" ]; then
  if [ -f "$APP/bin/console" ]; then
    log "found an existing SuiteCRM tree without a version marker; keeping it"
  else
    log "copying SuiteCRM ${SUITECRM_VERSION} onto the volume"
    cp -a /usr/src/suitecrm/. "$APP/"
  fi
  echo "${SUITECRM_VERSION}" > "$MARKER"
  chown -R www-data:www-data "$APP"
fi
ON_VOLUME="$(cat "$MARKER")"
if [ "$ON_VOLUME" != "$SUITECRM_VERSION" ]; then
  log "WARNING: the volume holds SuiteCRM ${ON_VOLUME}, this image ships ${SUITECRM_VERSION}."
  log "Running ${ON_VOLUME} from the volume. See the template README for upgrading."
fi
chown www-data:www-data "$APP"

# 2. Wait for MariaDB.
log "waiting for MariaDB at ${DB_HOST}:${DB_PORT}"
for i in $(seq 1 90); do
  if php -r 'mysqli_report(MYSQLI_REPORT_OFF); $m=@new mysqli(getenv("DB_HOST"),getenv("DB_USER"),getenv("DB_PASSWORD"),getenv("DB_NAME"),(int)getenv("DB_PORT")); exit($m->connect_errno ? 1 : 0);'; then
    break
  fi
  [ "$i" = 90 ] && { log "MariaDB did not answer"; exit 1; }
  sleep 2
done
export DB_NAME DB_PORT

# 3. Install once.
if ! is_installed; then
  : "${SUITECRM_ADMIN_PASSWORD:?SUITECRM_ADMIN_PASSWORD is not set}"
  log "running the SuiteCRM CLI installer (admin user: ${ADMIN_USER})"
  cd "$APP"
  as_www php bin/console suitecrm:app:install \
    -u "$ADMIN_USER" -p "$SUITECRM_ADMIN_PASSWORD" \
    -U "$DB_USER" -P "$DB_PASSWORD" -H "$DB_HOST" -Z "$DB_PORT" -N "$DB_NAME" \
    -S "$SITE_URL" -d no -W true
  is_installed || { log "the installer did not finish"; exit 1; }
  log "install finished"
fi

# 4. Keep site_url on the current domain (Settings may override other keys).
OVR="$LEGACY/config_override.php"
[ -f "$OVR" ] || printf '<?php\n' > "$OVR"
sed -i -e "s/\$sugar_config\['site_url'\] = '[^']*';//g" -e '/^[[:space:]]*$/d' "$OVR"
printf "\n\$sugar_config['site_url'] = '%s';\n" "$SITE_URL" >> "$OVR"
chown www-data:www-data "$OVR"

# 5. Scheduler (SuiteCRM's cron.php) every minute, as www-data.
(
  while true; do
    sleep 60
    (cd "$LEGACY" && as_www php -f cron.php >/dev/null 2>&1) || true
  done
) &

stop_setup_page
trap - EXIT
# Railway's builder can drop the base image's deleted mods-enabled symlinks,
# which re-enables mpm_event next to mpm_prefork (AH00534). mod_php needs prefork.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
[ -e /etc/apache2/mods-enabled/mpm_prefork.load ] || a2enmod -q mpm_prefork

log "starting Apache on port ${PORT}"
exec apache2-foreground
