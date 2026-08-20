# Docker SPIP

Dockerfile to provide a ready to use SPIP in production.

This docker use [SPIP-cli](https://contrib.spip.net/SPIP-Cli) project to manage an auto install for SPIP. It can be use to manage the SPIP with command line.

## Supported Tags Respective `Dockerfile` Links

- `4.4`, `4.4.21`, `latest` (use PHP 8.4)

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
- `SPIP_DB_NAME`: MySQL database name (default: `spip`)

### Admin Account

- `SPIP_ADMIN_NAME`: account name (default: `Admin`)
- `SPIP_ADMIN_LOGIN`: account login (default: `admin`)
- `SPIP_ADMIN_EMAIL`: account email (default: `admin@spip`)
- `SPIP_ADMIN_PASS`: account password (default: `adminadmin`)

### SPIP Configuration

- `SPIP_SITE_ADDRESS`: website address (default: `http://localhost`)

### PHP Vars

Can change PHP vars to optimize your installation.

- `PHP_MAX_EXECUTION_TIME` (default: `60`)
- `PHP_MEMORY_LIMIT` (default: `256M`)
- `PHP_POST_MAX_SIZE` (default: `40M`)
- `PHP_UPLOAD_MAX_FILESIZE` (default `32M`)
- `PHP_TIMEZONE` (default: `America/Guadeloupe`)

## Build & Release

The `4.4/` directory is **generated**: do not edit it directly. Sources are `Dockerfile.tpl` and `docker-entrypoint.sh` at the repository root.

To release a new SPIP version:

1. Bump the package version in `update.sh` (`spipPackages`).
2. Run `./update.sh` — it regenerates `4.4/Dockerfile` (including the sha256 of the SPIP archive) and updates this README.
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
