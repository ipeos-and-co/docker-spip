#!/bin/bash
set -euo pipefail

# Valeurs de repli des secrets, non declarees en ENV pour ne pas figurer dans les
# metadonnees de l'image.
: "${SPIP_DB_PASS:=spip}"
: "${SPIP_ADMIN_PASS:=adminadmin}"
: "${SPIP_HARDEN_PERMS:=1}"
: "${SPIP_OWNER_UID:=1000}"
: "${SPIP_OWNER_GID:=1000}"
: "${SPIP_WRITABLE_EXTRA:=}"

# Variantes *_FILE, pour les secrets Docker / Swarm / Compose.
read_secret_files() {
	local var file
	for var in SPIP_DB_PASS SPIP_ADMIN_PASS; do
		eval "file=\${${var}_FILE:-}"
		if [ -n "$file" ]; then
			if [ ! -r "$file" ]; then
				echo >&2 "ERROR: ${var}_FILE=$file is not readable, aborting."
				exit 1
			fi
			eval "$var=\$(cat \"\$file\")"
			unset "${var}_FILE"
		fi
	done
}
read_secret_files

# Protege une valeur passee au shell par run_as(), pour que les mots de passe
# contenant ; ou $( ) soient traites litteralement.
shquote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run_as() {
	if [ "$(id -u)" = 0 ]; then
		su -p www-data -s /bin/sh -c "$1"
	else
		sh -c "$1"
	fi
}

# Repertoires ou SPIP ecrit, laisses a www-data. `plugins/auto` et non `plugins` :
# c'est la seule partie ou SVP installe.
SPIP_WRITABLE_DIRS="tmp local IMG config plugins/auto lib"

# Recree le .htaccess de refus de tmp/, config/ et vendor/ s'il manque, avec le contenu
# que SPIP y met : SPIP ne peut plus le faire lui-meme une fois l'arborescence a root.
ensure_protection_htaccess() {
	local d
	for d in tmp config vendor; do
		[ -d "/var/www/html/$d" ] || continue
		[ -e "/var/www/html/$d/.htaccess" ] && continue
		cat > "/var/www/html/$d/.htaccess" <<'HTEOF'
# Deny all requests from Apache 2.4+.
<IfModule mod_authz_core.c>
  Require all denied
</IfModule>
# Deny all requests from Apache 2.0-2.2.
<IfModule !mod_authz_core.c>
  Deny from all
</IfModule>
HTEOF
		echo >&2 "  created missing $d/.htaccess"
	done
}

# Arborescence au compte non privilegie spip (1000:1000), repertoires en 755 et fichiers
# en 644 ; www-data garde les seuls repertoires ou SPIP ecrit. Le X majuscule de
# `u=rwX,go=rX` preserve le bit d'execution la ou il existe deja (vendor/bin/*).
#
# Les fichiers montes depuis l'hote sont traites comme les autres. Un montage en lecture
# seule refuse chown et chmod, meme quand ils ne changeraient rien : l'echec est signale
# mais n'interrompt pas le demarrage.
harden_permissions() {
	local d p extra owner="${SPIP_OWNER_UID}:${SPIP_OWNER_GID}"
	echo >&2 "Applying ownership model (SPIP_HARDEN_PERMS=1, owner ${owner})..."

	if ! chown -R "$owner" /var/www/html; then
		echo >&2 "WARNING: some paths kept their owner (read-only mount?), continuing."
	fi
	if ! chmod -R u=rwX,go=rX /var/www/html; then
		echo >&2 "WARNING: some paths kept their mode (read-only mount?), continuing."
	fi

	for d in ${SPIP_WRITABLE_DIRS}; do
		if [ -d "/var/www/html/$d" ]; then
			chown -R www-data:www-data "/var/www/html/$d" \
				|| echo >&2 "WARNING: $d kept its owner, continuing."
		fi
	done

	# Le .htaccess racine reste modifiable : il porte la reecriture d'URL de SPIP et les
	# regles ajoutees par les plugins. Le repertoire racine, lui, appartient a spip.
	if [ -e /var/www/html/.htaccess ]; then
		chown www-data:www-data /var/www/html/.htaccess \
			|| echo >&2 "WARNING: .htaccess kept its owner, continuing."
	fi

	# Repertoires supplementaires choisis par l'administrateur, relatifs a /var/www/html,
	# separes par des virgules ou des espaces. Ex: SPIP_WRITABLE_EXTRA="squelettes,ecrire"
	extra=$(printf '%s' "${SPIP_WRITABLE_EXTRA}" | tr ',' ' ')
	for p in ${extra}; do
		case "$p" in
			/*|*..*)
				echo >&2 "WARNING: SPIP_WRITABLE_EXTRA entry '$p' is not a safe relative path, ignored."
				continue
				;;
		esac
		if [ -e "/var/www/html/$p" ]; then
			chown -R www-data:www-data "/var/www/html/$p" \
				|| echo >&2 "WARNING: $p kept its owner, continuing."
			echo >&2 "  also writable: $p"
		else
			echo >&2 "WARNING: SPIP_WRITABLE_EXTRA entry '$p' does not exist, ignored."
		fi
	done
	return 0
}

# version_greater A B returns whether A > B
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 | head -n 1)" != "$1" ]
}

# Test de port sans netcat, qui n'est plus installe dans l'image.
db_port_open() {
	timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
}

wait_for_db() {
	local tries=0
	until db_port_open "${SPIP_DB_HOST}" "${SPIP_DB_PORT:-3306}"; do
		tries=$((tries + 1))
		if [ "$tries" -ge 30 ]; then
			echo >&2 "ERROR: database ${SPIP_DB_HOST}:${SPIP_DB_PORT:-3306} still unreachable after ${tries} attempts, aborting."
			exit 1
		fi
		echo "Waiting for database ready (${tries}/30)..."
		sleep 5
	done
}

installed_version="0.0.0"
image_version="0.0.1"

if [ -f "/var/www/html/ecrire/inc_version.php" ]; then
	installed_version=$(grep -i /var/www/html/ecrire/inc_version.php  -e '\$spip_version_branche =' | cut -d '=' -f 2 | cut -d ';' -f 1 | cut -d "'" -f 2 | cut -d '"' -f 2)
	image_version=$(grep -i /usr/src/spip/ecrire/inc_version.php  -e '\$spip_version_branche =' | cut -d '=' -f 2 | cut -d ';' -f 1 | cut -d "'" -f 2 | cut -d '"' -f 2)
fi

echo "SPIP version in volume: ${installed_version} - SPIP version shipped in image: ${image_version}"

if version_greater "$installed_version" "$image_version"; then
	echo "Can't start SPIP because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
	exit 1
fi

# Reconfigure php.ini
# set PHP.ini settings for SPIP
# NB: error logging is configured at build time (error-logging.ini -> /dev/stderr),
# do not override error_log here or PHP errors disappear from `docker logs`
( \
echo "max_execution_time=${PHP_MAX_EXECUTION_TIME}"; \
echo "memory_limit=${PHP_MEMORY_LIMIT}"; \
echo "post_max_size=${PHP_POST_MAX_SIZE}"; \
echo "upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}"; \
echo "date.timezone=${PHP_TIMEZONE}"; \
) > /usr/local/etc/php/conf.d/spip.ini


if version_greater "$image_version" "$installed_version"; then
	echo >&2 "SPIP upgrade in $PWD - copying now..."
	if [ "$(ls -A)" ]; then
		echo >&2 "WARNING: $PWD is not empty"
	fi
	tar cf - --one-file-system -C /usr/src/spip . | tar xf -
	echo >&2 "Complete! SPIP has been successfully copied to $PWD"

	echo >&2 "Create plugins, libraries and template directories"
	mkdir -p plugins/auto
	mkdir -p lib
	mkdir -p squelettes
	mkdir -p tmp/{dump,log,upload}
	chown -R www-data:www-data plugins lib squelettes tmp \
		|| echo >&2 "WARNING: some paths kept their owner, continuing."

	if [ ! -e .htaccess ]; then
		cp -p htaccess.txt .htaccess
		chown www-data:www-data .htaccess || true
	fi

	if [ "${SPIP_DB_SERVER}" = "mysql" ]; then
		wait_for_db
	fi

	# Upgrade SPIP
	if [ -f config/connect.php ]; then
		run_as "spip core:maj:bdd"
		run_as "spip plugins:maj:bdd"
	fi
fi

# Install SPIP
if [ "${SPIP_DB_SERVER}" = "mysql" ]; then
	wait_for_db
fi
if [[ ! -e config/connect.php && "${SPIP_AUTO_INSTALL}" = 1 ]]; then
	if [ "${SPIP_ADMIN_PASS}" = "adminadmin" ]; then
		echo >&2 "**********************************************************************"
		echo >&2 "WARNING: SPIP_ADMIN_PASS is using the default value 'adminadmin'."
		echo >&2 "Set a strong password via SPIP_ADMIN_PASS before exposing this site."
		echo >&2 "**********************************************************************"
	fi
	# Wait for mysql before install
	# cf. https://docs.docker.com/compose/startup-order/
	if ! run_as "spip install \
		--db-server $(shquote "${SPIP_DB_SERVER}") \
		--db-host $(shquote "${SPIP_DB_HOST}") \
		--db-login $(shquote "${SPIP_DB_LOGIN}") \
		--db-pass $(shquote "${SPIP_DB_PASS}") \
		--db-database $(shquote "${SPIP_DB_NAME}") \
		--db-prefix $(shquote "${SPIP_DB_PREFIX}") \
		--adresse-site $(shquote "${SPIP_SITE_ADDRESS}") \
		--admin-nom $(shquote "${SPIP_ADMIN_NAME}") \
		--admin-login $(shquote "${SPIP_ADMIN_LOGIN}") \
		--admin-email $(shquote "${SPIP_ADMIN_EMAIL}") \
		--admin-pass $(shquote "${SPIP_ADMIN_PASS}")"; then
		echo >&2 "WARNING: SPIP auto-install failed - complete the installation via the web interface (/ecrire/)"
	fi
fi

# Default mes_options
if [ ! -e config/mes_options.php ]; then
	/bin/cat << MAINEOF > config/mes_options.php
<?php
if (!defined("_ECRIRE_INC_VERSION")) return;
\$GLOBALS['spip_header_silencieux'] = 1;
?>
MAINEOF
	chown www-data:www-data config/mes_options.php || true
fi

# Mettre SPIP_HARDEN_PERMS=0 pour ne pas appliquer le modele de proprietes, par exemple
# sur un montage lie dont l'hote impose deja un proprietaire.
if [ "$(id -u)" = 0 ]; then
	ensure_protection_htaccess
	if [ "${SPIP_HARDEN_PERMS}" = 1 ]; then
		harden_permissions
	fi
fi

# Les secrets ne servent plus apres l'installation : la configuration vit dans
# config/connect.php. On les retire de l'environnement transmis a Apache.
unset SPIP_DB_PASS SPIP_ADMIN_PASS SPIP_DB_LOGIN SPIP_ADMIN_LOGIN SPIP_ADMIN_EMAIL

exec "$@"
