# Runtime image for the Nginx Webhost egg: nginx + PHP-FPM + Composer on Alpine.
# Build with: docker build --build-arg PHP_VERSION=8.5 docker/

ARG ALPINE_VERSION=3.24

FROM composer:2 AS composer

FROM alpine:${ALPINE_VERSION}

# 8.3, 8.4 or 8.5 (must be packaged by the Alpine version above).
# OPcache is built into PHP 8.5+; older versions ship it as a package.
ARG PHP_VERSION=8.5

LABEL org.opencontainers.image.source="https://github.com/Rustix-Development/pterodactyl-nginx-egg" \
      org.opencontainers.image.description="nginx + PHP-FPM for the Pterodactyl Nginx Webhost egg" \
      org.opencontainers.image.licenses="MIT"

RUN set -eux; \
    p="php$(echo "${PHP_VERSION}" | tr -d .)"; \
    apk add --no-cache \
        ca-certificates curl git tini tzdata unzip \
        nginx \
        "$p" "$p-fpm" \
        "$p-bcmath" "$p-ctype" "$p-curl" "$p-dom" "$p-exif" "$p-fileinfo" "$p-gd" \
        "$p-gettext" "$p-gmp" "$p-iconv" "$p-intl" "$p-mbstring" "$p-mysqli" \
        "$p-mysqlnd" "$p-openssl" "$p-pdo" "$p-pdo_mysql" "$p-pdo_pgsql" \
        "$p-pdo_sqlite" "$p-pgsql" "$p-phar" "$p-posix" "$p-session" \
        "$p-simplexml" "$p-soap" "$p-sockets" "$p-sodium" "$p-sqlite3" \
        "$p-tokenizer" "$p-xml" "$p-xmlreader" "$p-xmlwriter" "$p-zip" \
        "$p-pecl-apcu" "$p-pecl-imagick" "$p-pecl-redis"; \
    case "${PHP_VERSION}" in 8.3|8.4) apk add --no-cache "$p-opcache" ;; esac; \
    ln -sf "/usr/bin/$p" /usr/local/bin/php; \
    ln -sf "/usr/sbin/php-fpm$(echo "${PHP_VERSION}" | tr -d .)" /usr/local/bin/php-fpm; \
    php -v; php-fpm -v; nginx -v; \
    adduser -D -h /home/container container

# Interim mitigation for CVE-2026-109618/109619 (php2shell) until Alpine ships the fixed PHP.
# php.net says these must be set in the system config, ini_set() and .user.ini don't help.
# https://www.php.net/archive/2026.php#2026-10-21-5
RUN set -eux; \
    ini="/etc/php$(echo "${PHP_VERSION}" | tr -d .)/conf.d/00-php2shell-mitigation.ini"; \
    echo "session.upload_progress.enabled = 0" > "$ini"; \
    case "${PHP_VERSION}" in 8.3|8.4) ;; *) echo "fatal_error_backtraces = 0" >> "$ini" ;; esac; \
    php -r 'exit(ini_get("session.upload_progress.enabled") ? 1 : 0);'

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# Used by start.sh's update check; the workflow passes the build time (also set as an index annotation)
# and the image's name, so a server on an image from an old address can be told to switch
ARG IMAGE_BUILD=dev
ARG IMAGE_NAME=""
ENV PHP_IMAGE_VERSION=${PHP_VERSION} IMAGE_BUILD=${IMAGE_BUILD} IMAGE_NAME=${IMAGE_NAME}

STOPSIGNAL SIGINT

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
