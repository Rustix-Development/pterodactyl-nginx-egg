#!/bin/ash
# Starts PHP-FPM and nginx for the Nginx Webhost egg.

EGG_REPO="Rustix-Development/pterodactyl-nginx-egg"
EGG_IMAGE="rustix-development/pterodactyl-nginx-egg"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

log_info()    { printf "⏳ %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS] %s${RESET}\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING] %s${RESET}\n" "$1"; }
log_error()   { printf "${RED}[ERROR] %s${RESET}\n" "$1"; }
log_update()  { printf "${CYAN}[UPDATE] %s${RESET}\n" "$1"; }

is_true() { [ "$1" = "1" ] || [ "$1" = "true" ]; }

# ISO 8601 UTC time -> unix seconds (busybox date, then GNU date)
to_epoch() {
    date -u -D '%Y-%m-%dT%H:%M:%SZ' -d "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null
}

# nginx workers = CPUs the panel lets this server use (its CPU limit), between 1 and 4
nginx_workers() {
    quota=""
    period=""
    if [ -r /sys/fs/cgroup/cpu.max ]; then
        read -r quota period < /sys/fs/cgroup/cpu.max
    elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then
        quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
        period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
    fi
    if [ "${quota}" -gt 0 ] 2>/dev/null && [ "${period}" -gt 0 ] 2>/dev/null; then
        workers=$(( (quota + period - 1) / period ))
    else
        workers=$(nproc 2>/dev/null || echo 1)
    fi
    [ "${workers}" -lt 1 ] 2>/dev/null && workers=1
    [ "${workers}" -gt 4 ] 2>/dev/null && workers=4
    echo "${workers}"
}

# Compare the EGG_VERSION this server was installed with against the latest released egg
check_egg_update() {
    if ! egg_json=$(curl -fsL --max-time 10 "https://github.com/${EGG_REPO}/releases/latest/download/egg-nginx-webhost.json"); then
        log_warning "Update check: couldn't get the latest egg from GitHub, skipping."
        return
    fi
    latest=$(printf '%s' "${egg_json}" | grep -o 'EGG_VERSION=\\"[^\\]*' | head -n 1 | sed 's/.*\\"//')
    installed=$(cat /home/container/.egg-version 2>/dev/null)
    [ -z "${latest}" ] && return

    if [ "${installed}" = "${latest}" ]; then
        log_success "Egg is up to date (v${installed})."
    else
        log_update "Egg update available: ${installed:+v${installed} -> }v${latest}"
        log_update "  1. Download egg-nginx-webhost-${latest}.json from https://github.com/${EGG_REPO}/releases/latest"
        log_update "     and upload it in the panel: Admin -> Nests -> (nest) -> Nginx Webhost -> Update Egg"
        log_update "  2. This server: Settings -> Reinstall Server. webroot is kept; nginx/, php-fpm/ and start.sh are replaced, so back up any edits to them first."
    fi

    if [ -n "${PHP_IMAGE_VERSION}" ] && ! printf '%s' "${egg_json}" | grep -q "pterodactyl-nginx-egg:php${PHP_IMAGE_VERSION}\""; then
        log_warning "PHP ${PHP_IMAGE_VERSION} is no longer offered by the egg. Admin -> Servers -> this server -> Startup -> Docker Image: pick one of the egg's images."
    fi
}

# Compare this Docker image's build time against the latest build on ghcr.io
check_image_update() {
    if [ -z "${IMAGE_BUILD}" ]; then
        log_warning "This server isn't using a Nginx Webhost Docker image. Admin -> Servers -> this server -> Startup -> Docker Image: pick one of the egg's images."
        return
    fi
    [ "${IMAGE_BUILD}" = "dev" ] && return

    token=$(curl -fs --max-time 10 "https://ghcr.io/token?scope=repository:${EGG_IMAGE}:pull" \
        | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if ! index=$(curl -fs --max-time 10 -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json" \
        "https://ghcr.io/v2/${EGG_IMAGE}/manifests/php${PHP_IMAGE_VERSION}"); then
        log_warning "Update check: couldn't get the latest Docker image info from ghcr.io, skipping."
        return
    fi
    latest=$(printf '%s' "${index}" | grep -o '"org.opencontainers.image.created"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
    [ -z "${latest}" ] && return

    # ISO 8601 timestamps sort as text
    newest=$(printf '%s\n%s\n' "${latest}" "${IMAGE_BUILD}" | sort | tail -n 1)
    if [ "${newest}" = "${IMAGE_BUILD}" ]; then
        log_success "Docker image is up to date (PHP ${PHP_IMAGE_VERSION}, built ${IMAGE_BUILD%%T*})."
    else
        log_update "Docker image update available: built ${latest%%T*}, this server runs ${IMAGE_BUILD%%T*}."
        if [ -z "${IMAGE_NAME}" ]; then
            # Only images from before the move to rustix-development lack IMAGE_NAME. Their old
            # address (ghcr.io/mkkbeydoun) is never rebuilt, so restarting can't update them.
            log_update "  This server's Docker image comes from the old address ghcr.io/mkkbeydoun/pterodactyl-nginx-egg, which no longer gets updates."
            log_update "  Change it to ghcr.io/${EGG_IMAGE}:php${PHP_IMAGE_VERSION} in the server's Startup tab -> Docker Image"
            log_update "  (or Admin -> Servers -> this server -> Startup -> Docker Image), then restart the server."
        else
            log_update "  Restart the server to download it (the panel pulls the latest image on every start)."
            log_update "  If this keeps showing, the node's image pull is failing and it keeps the old image: run 'docker pull ghcr.io/${EGG_IMAGE}:php${PHP_IMAGE_VERSION}' on the node to see why."
        fi
    fi

    # The weekly rebuild stops if GitHub disables the scheduled workflow (60 days without repo activity)
    latest_ts=$(to_epoch "${latest}")
    now_ts=$(date -u +%s)
    if [ -n "${latest_ts}" ] && [ $(( (now_ts - latest_ts) / 86400 )) -gt 21 ]; then
        log_warning "The egg's Docker images haven't been rebuilt for $(( (now_ts - latest_ts) / 86400 )) days, so they may be missing nginx/PHP security updates. See https://github.com/${EGG_REPO}"
    fi
}

cd /home/container || exit 1
mkdir -p tmp logs webroot sessions

log_info "Cleaning up temporary files..."
rm -rf /home/container/tmp/*

# Keep logs from filling the disk: a log over 10 MB is copied to *.log.1 and emptied.
# nginx and PHP-FPM append to their logs, so emptying them in place is safe while running.
rotate_logs() {
    for log in /home/container/logs/*.log; do
        if [ -f "${log}" ] && [ "$(wc -c < "${log}")" -gt 10485760 ]; then
            cp -f "${log}" "${log}.1" && : > "${log}"
        fi
    done
}
rotate_logs

# Load php-fpm/php.ini on top of the image's stock PHP config (leading ":" keeps the stock dir)
export PHP_INI_SCAN_DIR=":/home/container/php-fpm"

# Never wait for a git username/password on the console, just fail
export GIT_TERMINAL_PROMPT=0

# Pull the latest website files from git
if is_true "${AUTO_UPDATE}"; then
    if [ -d webroot/.git ]; then
        log_info "Auto Update: pulling latest website files..."
        if git -c safe.directory=/home/container/webroot -C webroot pull --ff-only; then
            log_success "Website files updated."
        else
            log_warning "git pull failed, starting with the files already on the server."
        fi
    else
        log_warning "Auto Update is on but webroot is not a git repository, skipping."
    fi
fi

# Composer packages from the "Composer modules" variable (space separated). Packages already
# in composer.json aren't required again, so their versions never change on a restart.
if [ -n "${COMPOSER_MODULES}" ]; then
    missing=""
    for module in ${COMPOSER_MODULES}; do
        name=${module%%:*}
        if [ -f webroot/composer.json ] && grep -qiF "\"${name}\"" webroot/composer.json; then
            continue
        fi
        missing="${missing} ${module}"
    done
    if [ -n "${missing}" ]; then
        log_info "Installing Composer packages:${missing}"
        # shellcheck disable=SC2086 # split the list into separate packages
        if composer require --no-interaction --working-dir=/home/container/webroot ${missing}; then
            log_success "Composer packages installed."
        else
            log_warning "Composer failed, continuing without the new packages."
        fi
    else
        log_info "Checking Composer packages..."
        if ! composer install --no-interaction --working-dir=/home/container/webroot; then
            log_warning "composer install failed, continuing with the packages already installed."
        fi
    fi
fi

log_info "Starting PHP-FPM..."
PHP_FPM=$(command -v php-fpm || ls /usr/sbin/php-fpm* 2>/dev/null | head -n 1)
if [ -z "${PHP_FPM}" ]; then
    log_error "php-fpm not found in this Docker image."
    exit 1
fi
if "${PHP_FPM}" --fpm-config /home/container/php-fpm/php-fpm.conf --daemonize; then
    log_success "PHP-FPM started."
else
    log_error "Failed to start PHP-FPM, check logs/php-fpm.log"
    exit 1
fi

# nginx's root, from the Root Folder variable (default.conf includes the file written here).
# Blank: webroot. A folder in webroot (a name or a path like dev/main): that folder is the
# site at /, the other folders in webroot are still served at /<folder>/, and
# /<root folder>/... redirects to /...
write_root_conf() {
    conf=/home/container/tmp/nginx-root.conf
    folder=$(printf '%s' "${ROOT_FOLDER}" | sed 's#//*#/#g; s#^/##; s#/$##')

    # Every part of the path starts with a letter or digit, so no "..", dotfiles or spaces
    if [ -n "${folder}" ] && ! printf '%s' "${folder}" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$'; then
        log_warning "Root Folder \"${ROOT_FOLDER}\" isn't a folder path in webroot, serving webroot as is."
        folder=""
    elif [ -n "${folder}" ] && [ ! -d "webroot/${folder}" ]; then
        log_warning "Root Folder: webroot/${folder} doesn't exist, serving webroot as is."
        folder=""
    fi

    if [ -z "${folder}" ]; then
        echo "root /home/container/webroot;" > "${conf}"
        return
    fi

    escaped=$(printf '%s' "${folder}" | sed 's/\./\\./g')
    cat > "${conf}" <<EOF
# Written by start.sh from the Root Folder variable, edits are lost on restart.

# Send redirects as /path so they keep the address and port the visitor used
absolute_redirect off;

# Old links to /${folder}/... go to the same page at /...
if (\$request_uri ~ "^/${escaped}(?:/|(?=\\?)|\$)(.*)\$") {
    return 301 /\$1;
}

# A folder in webroot is served at /<folder>/, everything else comes from webroot/${folder}
set \$site_folder "/${folder}";
set \$first_folder "";
if (\$uri ~ "^/([^/]+)") {
    set \$first_folder "/home/container/webroot/\$1";
}
if (-d \$first_folder) {
    set \$site_folder "";
}
root /home/container/webroot\$site_folder;
EOF
    log_info "Serving webroot/${folder} at /, the other folders in webroot at /<folder>/."
    if ! grep -qs 'tmp/nginx-root.conf' nginx/conf.d/default.conf; then
        log_warning "Root Folder is set, but nginx/conf.d/default.conf is from an older egg and ignores it. Reinstall the server (Settings -> Reinstall Server) to get the new config."
    fi
}
write_root_conf

# What missing pages get (default.conf includes the file written here). Blank: index.php, like
# before, so WordPress and other apps that route through it keep working. A path: that page,
# with a 404 status. It's looked up like any other page, so with a Root Folder set it's in there.
write_errors_conf() {
    conf=/home/container/tmp/nginx-errors.conf
    page=$(printf '%s' "${ERROR_404_PAGE}" | sed 's#//*#/#g; s#^/##')

    # Same rules as Root Folder: every part starts with a letter or digit, so no "..", dotfiles or spaces
    if [ -n "${page}" ] && ! printf '%s' "${page}" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$'; then
        log_warning "404 Page \"${ERROR_404_PAGE}\" isn't a file path in your site, using the default 404."
        page=""
    fi

    if [ -z "${page}" ]; then
        cat > "${conf}" <<'EOF'
# Written by start.sh, edits are lost on restart. 404 Page is blank: missing pages go to index.php.
location @missing {
    rewrite ^ /index.php last;
}
EOF
        return
    fi

    cat > "${conf}" <<EOF
# Written by start.sh from the 404 Page variable, edits are lost on restart.
error_page 404 /${page};
location @missing {
    return 404;
}
EOF
    log_info "Missing pages show /${page}."
    if [ ! -f "webroot${folder:+/${folder}}/${page}" ]; then
        log_warning "404 Page: webroot${folder:+/${folder}}/${page} doesn't exist, visitors get nginx's plain 404 until it does."
    fi
    if ! grep -qs 'tmp/nginx-errors.conf' nginx/conf.d/default.conf; then
        log_warning "404 Page is set, but nginx/conf.d/default.conf is from an older egg and ignores it. Reinstall the server (Settings -> Reinstall Server) to get the new config."
    fi
}
write_errors_conf

log_info "Starting nginx..."
set -- -e stderr -c /home/container/nginx/nginx.conf -p /home/container/
if ! grep -qE '^[[:space:]]*worker_processes' /home/container/nginx/nginx.conf; then
    set -- "$@" -g "worker_processes $(nginx_workers);"
fi
if ! nginx -t -q "$@"; then
    log_error "nginx config test failed, see the error above."
    exit 1
fi
log_success "Web server is running. All services started successfully."

# Background jobs (double fork, so they never delay startup and end with the container)
if is_true "${UPDATE_CHECK:-1}" && command -v curl >/dev/null 2>&1; then
    ( (check_egg_update; check_image_update) & )
fi
( (while sleep 600; do rotate_logs; done) & )

exec nginx "$@"
