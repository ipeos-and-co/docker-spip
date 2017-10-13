# Docker SPIP

Dockerfile permettant de mettre en production un SPIP.

Ce docker utilise le projet [SPIP-cli](https://contrib.spip.net/SPIP-Cli)
permettant de gérer l'auto-installation du SPIP et qui peut être utilisé pour
administrer le SPIP en ligne de commande à l'intérieur du docker.

## Tags supportés par les différents `Dockerfile`

- `3.2`, `latest`
- `3.1`
- `3.0`
- `2.1`

## Installation

Un image automatiquement construite est accessible sur
[Dockerhub](https://hub.docker.com/r/ipeos/spip/) et est recommendé pour vos
installation.

```bash
docker pull ipeos/spip:latest
```

## Démarrage rapide

```bash
docker run --name some-spip --link some-mysql:mysql -p 8080:80 -d ipeos/spip
```

## Variables d'environnement disponibles

**L'auto-installation n'est disponible que pour les version 3.X de SPIP**

- `SPIP_DB_SERVER`: mode de connexion à la base de donnée `sqlite3` ou `mysql` (par défaut : `mysql`)
- `SPIP_DB_PREFIX`: prefixe des tables SQL (par défaut: `spip`)

### Pour une installation avec une base de donnée MySQL

**La base de donnée MySQL doit exister avant l'installation.
Elle ne sera automatiquement pas créée.**

- `SPIP_DB_HOST`: nom de domaine ou IP du server MySQL (par défaut : `mysql`)
- `SPIP_DB_LOGIN`: identifiant de l'utilisateur MySQL (par défaut : `spip`)
- `SPIP_DB_PASS`: mot de passe de l'utilisateur MySQL (par défaut : `spip`)
- `SPIP_DB_NAME`: nom de la base de donnée (par défault `spip`)

### Création du compte administrateur

- `SPIP_ADMIN_NAME`: nom du compte (par défaut : `Admin`)
- `SPIP_ADMIN_LOGIN`: identifiant du compte (par défaut : `admin`)
- `SPIP_ADMIN_EMAIL`: email du compte (par défaut : `admin@spip`)
- `SPIP_ADMIN_PASS`: mot de passe du compte (par défaut : `adminadmin`)

### Variables PHP

Vous pouvez changer des varibles PHP pour optimiser votre installation.

- `PHP_MAX_EXECUTION_TIME` (par défaut : `60`)
- `PHP_MEMORY_LIMIT` (par défaut : `256M`)
- `PHP_POST_MAX_SIZE` (par défaut : `40M`)
- `PHP_UPLOAD_MAX_FILESIZE` (par défaut : `32M`)
- `PHP_TIMEZONE` (par défaut : `America/Guadeloupe`)

## Volume disponible

- `/var/www/html` : répertoire d'installation du SPIP

### Démarrer SPIP en externalisant vos données

```bash
docker run --name some-spip -p 8080:80 -d \
  -e SPIP_DB_SERVER=sqlite3 \
  -v /tmp/spip/config:/var/www/html/config \
  -v /tmp/spip/IMG:/var/www/html/IMG \
  -v /tmp/spip/lib:/var/www/html/lib \
  -v /tmp/spip/plugins:/var/www/html/plugins \
  -v /tmp/spip/squelettes:/var/www/html/squelettes \
  -v /tmp/spip/tmp/dump:/var/www/html/tmp/dump \
  -v /tmp/spip/tmp/log:/var/www/html/tmp/log \
  -v /tmp/spip/tmp/log/apache2:/var/log/apache2 \
  -v /tmp/spip/tmp/upload:/var/www/html/tmp/upload \
   ipeos/spip:latest
```

## Contribuer

Cette image a été développé par [IPEOS](http://www.ipeos.com) pour le déploiement en production.

Si vous appréciez cette image utile, vous pouvez :

* Soumettre un Pull Request, pour que nous intégrions vos améliorations ou corrections de bug
* Rejoindre la communauté SPIP et nous aider à répondre les demandes.

## Équipe

### IPEOS

* [Laurent Vergerolle](https://github.com/psychoz971/)
* [Olivier Watté](https://github.com/owatte/)
