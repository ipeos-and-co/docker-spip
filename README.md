# Docker SPIP

Dockerfile to provide a ready to use SPIP in production.

This docker use [SPIP-cli](https://contrib.spip.net/SPIP-Cli) project to manage an auto install for SPIP. It can be use to manage the SPIP with command line.

## Supported Tags Respective `Dockerfile` Links

- `4.4`, `4.4.28`, `latest` (use PHP 8.4)

**WARNING: if your backend is broken after upgrade you must remove image and files cache :**
To clear cache remove `tmp/cache` and `local/cache-*` folders

## Installation

Automated builds of the image are available on [Dockerhub](https://hub.docker.com/r/ipeos/spip/) and is the recommanded method of installation.

```bash
docker pull ipeos/spip:latest
```

## Quick Start

```bash
docker network create spip-net

docker run --name some-mysql --network spip-net -d \
    -e MYSQL_ROOT_PASSWORD=aStrongRootPassword \
    -e MYSQL_DATABASE=spip -e MYSQL_USER=spip -e MYSQL_PASSWORD=aStrongDbPassword \
    mariadb:11.8

docker run --name some-spip --network spip-net -p 8080:80 -d \
    -e SPIP_DB_HOST=some-mysql \
    -e SPIP_DB_PASS=aStrongDbPassword \
    -e SPIP_ADMIN_PASS=aStrongAdminPassword \
    ipeos/spip
```

A complete example (with persistent volumes and a database healthcheck) is provided in [`docker-compose.yml`](docker-compose.yml).

> **Security note:** with the default settings (`SPIP_AUTO_INSTALL=1`), the container installs a ready-to-use SPIP with the admin account `admin` / `adminadmin`. **Always set `SPIP_ADMIN_PASS`** (and `SPIP_DB_PASS`) before exposing the site, or disable auto-install with `SPIP_AUTO_INSTALL=0`.

## Security defaults

A few defaults differ from a plain `php:apache` image.

**PHP does not run from `IMG/` and `local/`.** Apache turns the engine off in those two directories
([`spip-hardening.conf`](spip-hardening.conf)). The rule SPIP ships in `htaccess.txt` only covers the
`.php` extension; this covers any extension. `AllowOverride` is left untouched, so `.htaccess` files
keep working everywhere — the root one for clean URLs and the `*.api` route, and the ones plugins
such as Accès Restreint write inside `IMG/<extension>/`.

**The tree belongs to an unprivileged account.** At startup the entrypoint gives it to `spip`
(uid/gid 1000), sets directories to 755 and files to 644, and hands to `www-data` only what SPIP
writes to: `tmp/`, `local/`, `IMG/`, `config/`,
`plugins/auto/`, `lib/`, plus the root `.htaccess` so URL rules stay editable. Uploads, cache, plugin
installation through SVP and `.htaccess` edits all keep working.

Files mounted into the document root get the same treatment as the rest. uid 1000 is the first
account on most hosts, so they stay usable outside the container; use `SPIP_OWNER_UID` and
`SPIP_OWNER_GID` if yours differ. A read-only mount refuses `chown` and `chmod` even when they would
change nothing — this is reported and startup continues.

If a plugin needs to write somewhere else, add the paths to `SPIP_WRITABLE_EXTRA`
(`"squelettes,ecrire"`), or set `SPIP_HARDEN_PERMS=0` to skip this entirely. Note that granting
`ecrire/` also allows SPIP's own code to be modified — prefer the narrowest path that works.

The document root itself stays with `spip`, so `www-data` cannot create any file there — above all
no `.php`. When a plugin generates a file at the root, list it in
`SPIP_WRITABLE_ROOT_FILES` instead of granting the whole root: the entrypoint creates it empty if it
is missing and hands only that file to `www-data`. SPIP's `ecrire_fichier()` cannot write its
temporary file next to it, and falls back to writing into the existing file directly. Files you
place yourself (a `google….html` or SSL validation file, through `docker cp`, a mount or a `pre`
hook) need none of this: they are readable by Apache like the rest of the tree. For
`/.well-known/` validations, which live in a directory, use `SPIP_WRITABLE_EXTRA=".well-known"`
only if SPIP has to write there.

The entrypoint also recreates the `.htaccess` protecting `tmp/`, `config/` and `vendor/` when it is
missing, using the content SPIP itself writes. SPIP can no longer create it once the tree belongs to
`root`, and a site coming from an older image may not have one.

**Passwords are not left in the environment.** `SPIP_DB_PASS` and `SPIP_ADMIN_PASS` are used during
installation, then removed before Apache starts, and are not declared as `ENV` in the Dockerfile.
Both accept a `_FILE` variant (`SPIP_DB_PASS_FILE`, `SPIP_ADMIN_PASS_FILE`) for Docker secrets.

**Smaller image surface.** No `netcat` (the database wait uses bash's `/dev/tcp`), no C toolchain
once the PHP extensions are built, and no Composer dev dependencies. The ImageMagick policy is
limited to the formats SPIP needs, which keeps the PostScript, EPS and PDF coders — and therefore
Ghostscript — out of the picture.

**Pinned sources.** The base image is referenced by digest, spip-cli is checked against the commit
behind its tag, and the SPIP archive, `imagick` and `apcu` against their sha256. `./update.sh`
refreshes all of them.

Deployment-level hardening — dropped capabilities, a read-only root filesystem, egress filtering —
is left to the operator.

## Available Environment Vars

- `SPIP_AUTO_INSTALL`: auto install spip database `1` or `0` (default: `1`)
- `SPIP_DB_SERVER`: connexion method to the database `sqlite3` or `mysql` (default: `mysql`)
- `SPIP_DB_PREFIX`: SQL table prefix (default: `spip`)

### For MySQL Database Only

**The MySQL database must exist before installation. It will not be automatically created.**

- `SPIP_DB_HOST`: MySQL server hostname or IP (default: `mysql`)
- `SPIP_DB_PORT`: MySQL server port (default: `3306`)
- `SPIP_DB_LOGIN`: MySQL user login (default: `spip`)
- `SPIP_DB_PASS`: MySQL user password (default: `spip`)
- `SPIP_DB_PASS_FILE`: read the password from a file instead (Docker secrets)
- `SPIP_DB_NAME`: MySQL database name (default: `spip`)

### Admin Account

- `SPIP_ADMIN_NAME`: account name (default: `Admin`)
- `SPIP_ADMIN_LOGIN`: account login (default: `admin`)
- `SPIP_ADMIN_EMAIL`: account email (default: `admin@spip`)
- `SPIP_ADMIN_PASS`: account password (default: `adminadmin`)
- `SPIP_ADMIN_PASS_FILE`: read the password from a file instead (Docker secrets)

### Hardening

- `SPIP_HARDEN_PERMS`: apply the ownership model at startup — directories 755, files 644, the tree
  owned by `spip` except `tmp/`, `local/`, `IMG/`, `config/`, `plugins/auto/`, `lib/` and the root
  `.htaccess`, which stay with `www-data` — `1` or `0` (default: `1`)
- `SPIP_OWNER_UID`, `SPIP_OWNER_GID`: owner of everything the web server must not write
  (default: `1000`)
- `SPIP_WRITABLE_EXTRA`: extra paths, relative to the document root, to hand to `www-data` on top of
  that set. Separate them with commas or spaces, e.g. `SPIP_WRITABLE_EXTRA="squelettes,ecrire"`.
  Paths that are absolute or contain `..` are refused, missing ones are reported and skipped
  (default: empty)
- `SPIP_WRITABLE_ROOT_FILES`: files at the document root that SPIP must be able to rewrite, created
  empty if missing and handed to `www-data`, e.g. `SPIP_WRITABLE_ROOT_FILES="myfile.txt"`. Plain file
  names only (`A-Z a-z 0-9 . _ -`), with a `.txt`, `.xml`, `.json` or `.html` extension; paths,
  hidden files, symbolic links and other extensions are refused. `robots.txt` and `sitemap.xml` are
  refused too: SPIP computes them only when they are absent from the root, so an empty file would
  hide them. Likewise, a listed `.html` file takes precedence over a SPIP page with the same URL.
  Until the plugin writes it, the file is served empty. Ignored when `SPIP_HARDEN_PERMS=0`
  (default: empty)

### SPIP Configuration

- `SPIP_SITE_ADDRESS`: website address (default: `http://localhost`)

### PHP Vars

Can change PHP vars to optimize your installation.

- `PHP_MAX_EXECUTION_TIME` (default: `60`)
- `PHP_MEMORY_LIMIT` (default: `256M`)
- `PHP_POST_MAX_SIZE` (default: `40M`)
- `PHP_UPLOAD_MAX_FILESIZE` (default `32M`)
- `PHP_TIMEZONE` (default: `America/Guadeloupe`)

## Extending the entrypoint

Derived images can run their own steps at startup without replacing `docker-entrypoint.sh`. Put
`*.sh` files in one of these directories:

- `/docker-entrypoint.d/pre/`: after `php.ini` is written, before SPIP is copied into the volume,
  the database is waited for and the site installed. Use it for files and variables the next
  steps should see — plugins to copy, an Apache configuration, `SPIP_ADMIN_NAME`…
- `/docker-entrypoint.d/post/`: once the database is reachable and SPIP installed, before the
  ownership model is applied and the passwords are removed from the environment. Use it for
  `spip` commands: configuration, plugin updates, accounts…

```dockerfile
FROM ipeos/spip:4.4
COPY ./hooks/pre/ /docker-entrypoint.d/pre/
COPY ./hooks/post/ /docker-entrypoint.d/post/
```

The scripts are **sourced** in alphabetical order, as root, in the entrypoint's shell: variables
they export are seen by the following steps, they can use the `run_as` and `shquote` helpers to run
commands as `www-data`, and an error stops the container (the entrypoint runs with
`set -euo pipefail`). The ownership model applies to the files they create, as to the rest of the
tree. Files that do not end in `.sh` are ignored.

Since they share the entrypoint's shell, scripts should:

- leave with `return 0`, not `exit`, unless they mean to stop the container;
- not change the shell options (`set +e`, `set +u`…), which would weaken the rest of the startup;
- not reuse the entrypoint's internal variables (`installed_version`, `image_version`, `hook`…).

The passwords (`SPIP_DB_PASS`, `SPIP_ADMIN_PASS`) are still in the environment during `post`:
scripts must neither write them into the volume nor print them in the logs.

For instance, plugins shipped in the image (`COPY ./plugins/ /opt/site-plugins/`) are copied into
the volume in `pre`, so that the database upgrade run when the SPIP version changes takes them into
account, and the ownership model applies to them:

```bash
# /docker-entrypoint.d/pre/10-plugins.sh
mkdir -p plugins-dist/site
rm -rf plugins-dist/site/*
cp -r /opt/site-plugins/. plugins-dist/site/
```

Then `post` updates their tables and applies the site configuration:

```bash
# /docker-entrypoint.d/post/50-config.sh
# Nothing to do until SPIP is installed
[ -f config/connect.php ] || return 0
# Two passes: the first one refreshes the list of active plugins, the second one
# installs the plugins that just appeared in plugins-dist/site
run_as "spip plugins:maj:bdd"
run_as "spip plugins:maj:bdd"
run_as "spip config:ecrire -f /my-config.json"
```

- **The `config/connect.php` guard**: `post` also runs when SPIP is not installed
  (`SPIP_AUTO_INSTALL=0`, or a failed auto-install, which only logs a warning). Without the guard,
  `spip plugins:maj:bdd` fails (`Metas inacessibles !`) and stops the container.
- **The two passes**: `spip plugins:maj:bdd` clears the plugin cache, then installs from the list
  it loaded before clearing it. On a site that is already installed, a plugin added to
  `plugins-dist/site` would be active after a single pass, but without its tables until the next
  start.

## Build & Release

The `4.4/` directory is **generated**: do not edit it directly. Sources are `Dockerfile.tpl`, `docker-entrypoint.sh` and `spip-hardening.conf` at the repository root.

To release a new SPIP version:

1. Bump the package version in `update.sh` (`spipPackages`).
2. Run `./update.sh` — it regenerates `4.4/Dockerfile` (resolving the digest of the base image, the commit behind the spip-cli tag, and the sha256 of the SPIP archive), copies the entrypoint and the hardening config, and updates this README.
3. Run `./build.sh 4.4` — it builds and tags `ipeos/spip:4.4`, `ipeos/spip:<package>` and `ipeos/spip:latest`.

## Contributing

This image was created by [IPEOS](http://www.ipeos.com) for a purpose of web development training courses.

If you find this image useful here's how you can help:

- Send a Pull Request with your awesome enhancements and bug fixes
- Be a part of the community and help resolve Issues

## Team

### IPEOS

- [Laurent Vergerolle](https://github.com/psychoz971/)
- [Olivier Watté](https://github.com/owatte/)
- [Morgan Lejuez](https://github.com/Kanaima/)

### Contributors / Maintainers

- [Michaël Nival](https://github.com/mnival)
- [Nora Emma "Metal-Mighty" Barlow](https://github.com/Metal-Mighty)
