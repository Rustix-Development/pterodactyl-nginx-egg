# Runtime image for the Nginx Webhost egg: nginx + PHP-FPM + Composer on Debian.
# Build with: docker build --build-arg PHP_VERSION=8.5 docker/
#
# PHP comes from packages.sury.org (Ondřej Surý's PHP builds), which ships PHP security
# releases the same day. Alpine's own PHP packages lagged behind php.net's 21 Oct 2026
# release (CVE-2026-109618/109619), which is why the image moved off Alpine.

ARG DEBIAN_VERSION=trixie

FROM composer:2 AS composer

FROM debian:${DEBIAN_VERSION}-slim

# 8.3, 8.4 or 8.5 (must be packaged by packages.sury.org for the Debian version above).
# OPcache is built into PHP 8.5+; older versions ship it as a package.
ARG PHP_VERSION=8.5

LABEL org.opencontainers.image.source="https://github.com/Rustix-Development/pterodactyl-nginx-egg" \
      org.opencontainers.image.description="nginx + PHP-FPM for the Pterodactyl Nginx Webhost egg" \
      org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    curl -fsSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb; \
    dpkg -i /tmp/debsuryorg-archive-keyring.deb; \
    rm /tmp/debsuryorg-archive-keyring.deb; \
    . /etc/os-release; \
    echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/php.list; \
    p="php${PHP_VERSION}"; \
    apt-get update; \
    # common has ctype, exif, fileinfo, gettext, iconv, pdo, phar, posix, sockets, sodium,
    # tokenizer; mysql has mysqli, mysqlnd, pdo_mysql; xml has dom, simplexml, xmlreader/writer
    apt-get install -y --no-install-recommends \
        git tini tzdata unzip \
        nginx \
        # php-fpm depends on systemd | systemd-tmpfiles, this keeps all of systemd out
        systemd-standalone-tmpfiles \
        "$p-cli" "$p-fpm" "$p-common" \
        "$p-bcmath" "$p-curl" "$p-gd" "$p-gmp" "$p-intl" "$p-mbstring" "$p-mysql" \
        "$p-pgsql" "$p-soap" "$p-sqlite3" "$p-xml" "$p-zip" \
        "$p-apcu" "$p-imagick" "$p-redis"; \
    case "${PHP_VERSION}" in 8.3|8.4) apt-get install -y --no-install-recommends "$p-opcache" ;; esac; \
    rm -rf /var/lib/apt/lists/*; \
    ln -sf "/usr/bin/$p" /usr/local/bin/php; \
    ln -sf "/usr/sbin/php-fpm${PHP_VERSION}" /usr/local/bin/php-fpm; \
    # start.sh and entrypoint.sh (and servers' copies of start.sh) are #!/bin/ash from the Alpine days
    ln -s /bin/dash /bin/ash; \
    ln -s /usr/bin/tini /sbin/tini; \
    # Fail the build if an extension the egg has always shipped is missing
    for ext in apcu bcmath ctype curl dom exif fileinfo gd gettext gmp iconv imagick intl \
        mbstring mysqli mysqlnd openssl pdo pdo_mysql pdo_pgsql pdo_sqlite pgsql phar posix \
        redis session simplexml soap sockets sodium sqlite3 tokenizer xml xmlreader xmlwriter zip; do \
        php -m | grep -qix "$ext" || { echo "missing PHP extension: $ext"; exit 1; }; \
    done; \
    php -m | grep -qix "Zend OPcache"; \
    php -v; php-fpm -v; nginx -v; \
    useradd -m -d /home/container -s /bin/sh container

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
