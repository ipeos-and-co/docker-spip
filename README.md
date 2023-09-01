# Docker SPIP

Dockerfile to provide a ready to use SPIP in production.

This docker use [SPIP-cli](https://contrib.spip.net/SPIP-Cli) project to manage an auto install for SPIP. It can be use to manage the SPIP with command line.

## Supported Tags Respective `Dockerfile` Links

- `4.2`, `4.2.5`, `latest` (use PHP 8.1)
- `4.1`, `4.1.12` (use PHP 7.4)

**WARNING: if your backend is broken after upgrade you must remove image and files cache :**
To clear cache remove `tmp/cache` and `local/cache-*` folders

## Installation

Automated builds of the image are available on [Dockerhub](https://hub.docker.com/r/ipeos/spip/) and is the recommanded method of installation.

```bash
docker pull ipeos/spip:latest
```

## Quick Start

```bash
docker run --name some-spip --link some-mysql:mysql -p 8080:80 -d ipeos/spip
```

## Available Environment Vars

- `SPIP_AUTO_INSTALL`: auto install spip database `1` or `0` (default: `1`)
- `SPIP_DB_SERVER`: connexion method to the database `sqlite3` or `mysql` (default: `mysql`)
- `SPIP_DB_PREFIX`: SQL table preffix (default: `spip`)

### For MySQL Database Only

**The MySQL database must exist before installation. It will not be automatically created.**

- `SPIP_DB_HOST`: MySQL server hostname or IP (default: `mysql`)
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

## Contributing

This image was created by [IPEOS](http://www.ipeos.com) for a purpose of web development training courses.

If you find this image useful here's how you can help:

- Send a Pull Request with your awesome enhancements and bug fixes
- Be a part of the community and help resolve Issues

## Team

### IPEOS

- [Laurent Vergerolle](https://github.com/psychoz971/)
- [Olivier Watté](https://github.com/owatte/)

### Contributors / Maintainers

- [Michaël Nival](https://github.com/mnival)
- [Nora Emma "Metal-Mighty" Barlow](https://github.com/Metal-Mighty)
