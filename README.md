# Nginx Webhost Egg

[![Latest release](https://img.shields.io/github/v/release/Rustix-Development/pterodactyl-nginx-egg?label=egg)](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest)
[![Build images](https://github.com/Rustix-Development/pterodactyl-nginx-egg/actions/workflows/build-images.yml/badge.svg)](https://github.com/Rustix-Development/pterodactyl-nginx-egg/actions/workflows/build-images.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Pterodactyl](https://pterodactyl.io) eggs for hosting PHP and static websites with
**nginx 1.30** and **PHP 8.3 / 8.4 / 8.5** on PHP-FPM. There are two, pick one per server:

| Egg | File | For |
|-----|------|-----|
| **Nginx Webhost** | `egg-nginx-webhost-<version>.json` | You upload the site yourself (SFTP or the file manager), or install WordPress |
| **Nginx Webhost (Git)** | `egg-nginx-webhost-git-<version>.json` | The site is cloned from a Git repo (public or private), optionally pulled on every start |

Both use the same image, config files and startup script.

- **WordPress** (Nginx Webhost): turn on *Setup · WordPress* when creating the server and it's downloaded for you
- **Composer**: list packages in *Setup · Composer Modules* and they're installed into `webroot/`
- **Site variables**: site name and URL, Google Analytics, SMTP / mail, Cloudflare Turnstile,
  Discord and Google OAuth and a database connection string are passed to PHP, so your code
  reads them with `getenv()` instead of hardcoding them
- **Update check**: the console says when the egg or the Docker image has an update
- **Maintained images**: Debian based with PHP from packages.sury.org, `amd64` and `arm64`, rebuilt weekly for nginx and PHP
  security fixes

## Requirements

- Pterodactyl Panel 1.x with Wings (the egg is in the `PTDL_v2` format)
- An `amd64` or `arm64` node
- Internet access from the node during install: the installer downloads this egg's config
  files from GitHub, and WordPress or your Git repo if you use them

## Install

1. Download `egg-nginx-webhost-<version>.json`, `egg-nginx-webhost-git-<version>.json` or
   both from the [latest release](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest).
2. In the panel: **Admin → Nests → Import Egg**, upload each one into the nest you want.
3. Create a server with the egg and pick a PHP version under **Docker Image**.
4. Once it has installed, start it and visit `http://<node-ip>:<port>`. You should see the
   "Web server is running" page (or your site, with the Git egg); with Nginx Webhost, replace
   it by uploading your site into `webroot/`.

The server listens on its primary allocation. To serve a domain over HTTPS, put a reverse
proxy (nginx, Caddy, Cloudflare, ...) in front of that port.

## Variables

All variables can be changed later under the server's **Startup** tab. Each name starts
with its section (*Site*, *Git*, *Setup*, *Mail*, *Login*, *Security*, *Analytics*,
*Database*, *Egg*) so they stay grouped in the panel. The site variables only reach your PHP code;
the egg itself doesn't use them, so leave the ones you don't need blank.

### Site and setup

| Variable | Default | What it does |
|----------|---------|--------------|
| Site · Root Folder (`ROOT_FOLDER`) | | Folder in `webroot/` to serve at your domain's root, see [below](#serving-a-folder-at-the-root). Blank serves `webroot/` as is |
| Site · 404 Page (`ERROR_404_PAGE`) | | Page to show for missing pages, see [below](#custom-404-page). Blank keeps sending them to `index.php` |
| Setup · WordPress (`WORDPRESS`) | `0` | Nginx Webhost only. Install WordPress into an empty `webroot/`. Finish setup at `/wp-admin` |
| Setup · Composer Modules (`COMPOSER_MODULES`) | | Space separated packages, e.g. `phpmailer/phpmailer vlucas/phpdotenv`. Pin a version with `vendor/package:^6.0` |

### Egg

| Variable | Default | What it does |
|----------|---------|--------------|
| Egg · Update Check (`UPDATE_CHECK`) | `1` | Say in the console when the egg or the Docker image has an update |
| Egg · Startup Command (`STARTUP_CMD`) | `./start.sh` | Leave as is unless you know you need to change it |

Each Composer package is added once and then kept at that version. On every start
`composer install` keeps `vendor/` in line with `composer.lock`.

### Serving a folder at the root

Keep your main site in its own folder (any name) and other sites next to it:

```
webroot/
├── <folder>/  -> example.com/
├── blog/      -> example.com/blog/
└── shop/      -> example.com/shop/
```

Set **Root Folder** to `<folder>` (the folder's name, e.g. `site`, or a path to a nested
folder, e.g. `dev/main` for `webroot/dev/main`) in the server's **Startup** tab and restart
the server. `webroot/<folder>` is then served at `/`, every other
folder in `webroot/` is still served at its own path (`webroot/blog` at `/blog/`), and old
links to `/<folder>/...` redirect to the same page at `/...`. PHP and the dotfile blocking
work the same in all of them.

- Each part of the path can use letters, numbers, `.`, `_` and `-`, and starts with a letter
  or number (no spaces, no `..`).
- With a nested path like `dev/main`, the other folders in `webroot/dev` are still served at
  `/dev/<other>/`.
- If the main site and `webroot/` both have a folder with the same name (e.g.
  `<folder>/shop` and `shop/`), `webroot/shop` wins.
- Files at the top of `webroot/` (not in a folder) aren't served.
- Composer still installs into `webroot/`, so from the main site load it with
  `require __DIR__ . '/../vendor/autoload.php';`.
- If the folder doesn't exist the server serves `webroot/` as is and says so in the console.
- Servers installed before the egg had this option need a **Reinstall** first (see
  [Updates](#updates)) to get the new `nginx/conf.d/default.conf`.

### Custom 404 page

Set **404 Page** to the path of a page in your site, e.g. `404.html` or `errors/404.php`, and
every page that doesn't exist shows it with a `404` status. HTML and PHP pages both work. The
path is from your site's root: `webroot/`, or the **Root Folder** if you set one.

- Blank (default) does what the egg always did: missing pages go to `index.php`, which is
  what WordPress and other apps that route through `index.php` need. Leave it blank for those,
  they show their own 404 page.
- Links in the page should start with `/` (e.g. `/style.css`), it's shown at whatever address
  was missing.
- If the page doesn't exist, visitors get nginx's plain 404 and the console says so.
- Needs a **Reinstall** first on servers installed before the egg had this option.

### Git (Nginx Webhost (Git) only)

| Variable | Default | What it does |
|----------|---------|--------------|
| Git · Repo Address (`GIT_ADDRESS`) | | Repo to clone your site from, e.g. `https://github.com/you/your-site` |
| Git · Branch (`BRANCH`) | | Branch to clone; blank uses the repo's default branch |
| Git · Username (`USERNAME`) | | For private repos |
| Git · Access Token (`ACCESS_TOKEN`) | | For private repos; use a personal access token, not your password |
| Git · Auto Update (`AUTO_UPDATE`) | `0` | `git pull` on every start |

The repo is only cloned into an empty `webroot/`. If `webroot/` is already a clone of the
same repo, a reinstall pulls it; any other files are left alone.

### Site variables (read with `getenv()`)

| Section | Variables | Default | Typical use |
|---------|-----------|---------|-------------|
| Site | `SITE_NAME`, `SITE_URL` | `Website`, | Your site's name and public URL (no trailing slash) |
| Mail | `SMTP_HOST`, `SMTP_PORT` | `smtp.resend.com`, `465` | Mail server. For Gmail / Google Workspace use `smtp.gmail.com` and `587` |
| Mail | `SMTP_USERNAME`, `SMTP_PASSWORD` | `resend`, | Mail login. For Resend, the password is your API key; for Gmail, an App Password |
| Mail | `MAIL_FROM_EMAIL`, `MAIL_FROM_NAME` | | Sender address and name |
| Mail | `MAIL_TO_EMAIL` | | Where contact form mail goes |
| Login | `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET` | | Discord OAuth2 login |
| Login | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | | Google OAuth2 login |
| Security | `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY` | | Cloudflare Turnstile bot check on forms |
| Analytics | `GA_MEASUREMENT_ID` | | Google Analytics 4 Measurement ID, e.g. `G-XXXXXXXXXX` |
| Database | `DB_CONNECTION_STRING` | | Database URL, e.g. `mysql://user:pass@host:3306/db` |

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

- **the egg has an update**: download `egg-nginx-webhost-<version>.json` (or
  `egg-nginx-webhost-git-<version>.json` for the Git egg) from the
  [latest release](https://github.com/Rustix-Development/pterodactyl-nginx-egg/releases/latest), then
  **Admin → Nests → (nest) → the egg → Update Egg** with it (not *Import Egg*, that
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

Turn it off per server with the *Egg · Update Check* variable.

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
