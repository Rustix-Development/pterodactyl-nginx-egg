# Nginx Webhost Egg

[![Latest release](https://img.shields.io/github/v/release/Rustix-Development/pterodactyl-nginx-egg?label=egg)](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest)
[![Build images](https://github.com/Rustix-Development/pterodactyl-nginx-egg/actions/workflows/build-images.yml/badge.svg)](https://github.com/Rustix-Development/pterodactyl-nginx-egg/actions/workflows/build-images.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Pterodactyl](https://pterodactyl.io) egg for hosting PHP and static websites with
**nginx 1.30** and **PHP 8.3 / 8.4 / 8.5** on PHP-FPM.

- **Upload or deploy from Git**: upload files into `webroot/`, or clone a Git repo
  (public or private) and optionally pull it on every start
- **WordPress**: turn on *Wordpress* when creating the server and it's downloaded for you
- **Composer**: list packages in *Composer modules* and they're installed into `webroot/`
- **Site variables**: SMTP / mail, site name and URL, Discord and Google OAuth and a database
  connection string are passed to PHP, so your code reads them with `getenv()` instead of
  hardcoding them
- **Update check**: the console says when the egg or the Docker image has an update
- **Maintained images**: Debian based with PHP from packages.sury.org, `amd64` and `arm64`, rebuilt weekly for nginx and PHP
  security fixes

## Requirements

- Pterodactyl Panel 1.x with Wings (the egg is in the `PTDL_v2` format)
- An `amd64` or `arm64` node
- Internet access from the node during install: the installer downloads this egg's config
  files from GitHub, and WordPress or your Git repo if you use them

## Install

1. Download [`egg-nginx-webhost.json`](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest/download/egg-nginx-webhost.json)
   from the [latest release](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest).
2. In the panel: **Admin → Nests → Import Egg**, upload it into the nest you want.
3. Create a server with the egg and pick a PHP version under **Docker Image**.
4. Once it has installed, start it and visit `http://<node-ip>:<port>`. You should see the
   "Web server is running" page; replace it by uploading your site into `webroot/`.

The server listens on its primary allocation. To serve a domain over HTTPS, put a reverse
proxy (nginx, Caddy, Cloudflare, ...) in front of that port.

## Variables

All variables can be changed later under the server's **Startup** tab. The site variables
only reach your PHP code; the egg itself doesn't use them, so leave the ones you don't need
blank.

### Website

| Variable | Default | What it does |
|----------|---------|--------------|
| Wordpress (`WORDPRESS`) | `0` | Install WordPress into an empty `webroot/`. Finish setup at `/wp-admin` |
| Composer modules (`COMPOSER_MODULES`) | | Space separated packages, e.g. `phpmailer/phpmailer vlucas/phpdotenv`. Pin a version with `vendor/package:^6.0` |
| User Uploaded Files (`USER_UPLOAD`) | `0` | Skip the Git setup, you upload the files yourself |
| Update Check (`UPDATE_CHECK`) | `1` | Say in the console when the egg or the Docker image has an update |
| Startup Command (`STARTUP_CMD`) | `./start.sh` | Leave as is unless you know you need to change it |

Each Composer package is added once and then kept at that version. On every start
`composer install` keeps `vendor/` in line with `composer.lock`.

### Git

| Variable | Default | What it does |
|----------|---------|--------------|
| Git Repo Address (`GIT_ADDRESS`) | | Repo to clone your site from, e.g. `https://github.com/you/your-site` |
| Git Branch (`BRANCH`) | | Branch to clone; blank uses the repo's default branch |
| Auto Update (`AUTO_UPDATE`) | `0` | `git pull` on every start |
| Git Username (`USERNAME`) | | For private repos |
| Git Access Token (`ACCESS_TOKEN`) | | For private repos; use a personal access token, not your password |

The repo is only cloned into an empty `webroot/`. If `webroot/` is already a clone of the
same repo, a reinstall pulls it; any other files are left alone.

### Site variables (read with `getenv()`)

| Variable | Default | Typical use |
|----------|---------|-------------|
| `SMTP_HOST`, `SMTP_PORT` | `smtp.resend.com`, `465` | Mail server. For Gmail / Google Workspace use `smtp.gmail.com` and `587` |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | `resend`, | Mail login. For Resend, the password is your API key; for Gmail, an App Password |
| `MAIL_FROM_EMAIL`, `MAIL_FROM_NAME` | | Sender address and name |
| `MAIL_TO_EMAIL` | | Where contact form mail goes |
| `SITE_NAME`, `SITE_URL` | `Website`, | Your site's name and public URL (no trailing slash) |
| `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET` | | Discord OAuth2 login |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | | Google OAuth2 login |
| `DB_CONNECTION_STRING` | | Database URL, e.g. `mysql://user:pass@host:3306/db` |

```php
<?php
$mail->Host     = getenv('SMTP_HOST');
$mail->Port     = (int) getenv('SMTP_PORT');
$mail->Username = getenv('SMTP_USERNAME');
$mail->Password = getenv('SMTP_PASSWORD');
```

## What's in the image

The images are `ghcr.io/rustix-development/pterodactyl-nginx-egg:php8.3`, `:php8.4` and `:php8.5`,
built from [`docker/Dockerfile`](docker/Dockerfile) on Debian 13 with nginx, PHP-FPM (from packages.sury.org),
Composer 2 and Git.

PHP extensions: apcu, bcmath, ctype, curl, dom, exif, fileinfo, gd, gettext, gmp, iconv,
imagick, intl, mbstring, mysqli, mysqlnd, opcache, openssl, pdo, pdo_mysql, pdo_pgsql,
pdo_sqlite, pgsql, phar, posix, redis, session, simplexml, soap, sockets, sodium, sqlite3,
tokenizer, xml, xmlreader, xmlwriter, zip.

## Files on your server

| Path | What it's for |
|------|---------------|
| `webroot/` | Your website. Upload your files here (`index.html` or `index.php`) |
| `php-fpm/php.ini` | PHP settings: memory limit (256M), upload size (100M), ... Restart to apply |
| `nginx/conf.d/default.conf` | The site's nginx config |
| `logs/` | nginx and PHP logs. Any log over 10 MB is moved to `*.log.1` |
| `start.sh` | Startup script |

Out of the box nginx refuses to serve dotfiles (`.env`, `.git`, ...), `composer.json`,
`composer.lock`, `auth.json` and PHP files under `vendor/`.

**Reinstalling** a server replaces `nginx/`, `php-fpm/` and `start.sh` with fresh copies
(back up your edits to them first), pulls the Git repo if one is set, and installs WordPress
only into an empty `webroot/`. Your other website files are kept.

## Updates

Every time a server starts it checks for updates in the background and says in the console if:

- **the egg has an update**: download `egg-nginx-webhost.json` from the
  [latest release](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest), then
  **Admin → Nests → (nest) → Nginx Webhost → Update Egg** with it (not *Import Egg*, that
  makes a second copy), and **Reinstall** the server.
- **the Docker image has an update**: restart the server, the panel downloads the latest
  image on every start. If it keeps showing, run
  `docker pull ghcr.io/rustix-development/pterodactyl-nginx-egg:php8.x` on the node to see why.
- **the server still uses an image from the old address** `ghcr.io/mkkbeydoun/pterodactyl-nginx-egg`
  (servers created before v1.0.1): those images are no longer updated, and updating the egg
  doesn't change an existing server's image. In the server's **Startup** tab (or
  **Admin → Servers → server → Startup**), set **Docker Image** to
  `ghcr.io/rustix-development/pterodactyl-nginx-egg:php8.x` with the same PHP version, then restart.
- **the server's PHP version is no longer offered**, or the server isn't using one of this
  egg's images: **Admin → Servers → server → Startup → Docker Image**, pick one of the
  egg's images.

Turn it off per server with the *Update Check* variable.

## Troubleshooting

- **nginx or PHP-FPM won't start**: the console shows the error; the full logs are in `logs/`.
  If you edited `nginx/conf.d/default.conf`, the config test error points at the line.
- **Git clone fails**: check the address, branch and, for a private repo, the username and
  access token. The clone only runs into an empty `webroot/`, so empty it and reinstall to
  switch repos.
- **Uploads are rejected**: raise `upload_max_filesize` and `post_max_size` in
  `php-fpm/php.ini` and `client_max_body_size` in `nginx/conf.d/default.conf` together.

Found a bug or want a feature? [Open an issue](https://github.com/Rustix-Development/pterodactyl-nginx-egg/issues).

## License

MIT, see [LICENSE](LICENSE). Based on the WebHost egg by Sigma Productions, originally
[tenten8401/pterodactyl-nginx](https://gitlab.com/tenten8401/pterodactyl-nginx), with Git
install logic from [parkervcp/eggs](https://github.com/parkervcp/eggs); see
[NOTICE.md](NOTICE.md) for credits and their licenses.
