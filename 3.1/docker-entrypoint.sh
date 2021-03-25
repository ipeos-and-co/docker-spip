#!/bin/bash
set -e

run_as() {
	if [ "$(id -u)" = 0 ]; then
		su -p www-data -s /bin/sh -c "$1"
	else
		sh -c "$1"
	fi
}

# version_greater A B returns whether A > B
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 | head -n 1)" != "$1" ]
}

installed_version="0.0.0"
image_version="0.0.1"

if [ -f "/var/www/html/ecrire/inc_version.php" ]; then
	installed_version=$(php -r 'require "/var/www/html/ecrire/inc_version.php"; echo $spip_version_affichee;')
	image_version=$(php -r 'require "/usr/src/spip/ecrire/inc_version.php"; echo $spip_version_affichee;')
fi

echo $installed_version
echo $image_version

if version_greater "$installed_version" "$image_version"; then
	echo "Can't start SPIP because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
	exit 1
fi

# Reconfigure php.ini
# set PHP.ini settings for SPIP
( \
echo 'display_errors=Off'; \
echo 'error_log=/var/log/apache2/php.log'; \
echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
echo 'post_max_size=${PHP_POST_MAX_SIZE}'; \
echo 'upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}'; \
echo 'date.timezone=${PHP_TIMEZONE}'; \
) > /usr/local/etc/php/conf.d/spip.ini


if version_greater "$image_version" "$installed_version"; then
	echo >&2 "SPIP upgrade in $PWD - copying now..."
	if [ "$(ls -A)" ]; then
		echo >&2 "WARNING: $PWD is not empty - press Ctrl+C now if this is an error!"
		( set -x; ls -A; sleep 10 )
	fi
	tar cf - --one-file-system -C /usr/src/spip . | tar xf -
	echo >&2 "Complete! SPIP has been successfully copied to $PWD"

	echo >&2 "Create plugins, libraries and template directories"
	mkdir -p plugins/auto
	mkdir -p lib
	mkdir -p squelettes
	mkdir -p tmp/{dump,log,upload}
	chown -R www-data:www-data plugins lib squelettes tmp

	if [ ! -e .htaccess ]; then
		cp -p htaccess.txt .htaccess
		chown www-data:www-data .htaccess
	fi

	# Upgrade SPIP
	if [ -f config/connect.php ]; then
		spip core:maj:bdd
		spip plugins:maj:bdd
	fi

	# Install SPIP
	if [ ! -e config/connect.php ]; then
		# Wait for mysql before install
		# cf. https://docs.docker.com/compose/startup-order/
		max_retries=10
		try=0
		until run_as "spip install \
			--db-server ${SPIP_DB_SERVER} \
			--db-host ${SPIP_DB_HOST} \
			--db-login ${SPIP_DB_LOGIN} \
			--db-pass ${SPIP_DB_PASS} \
			--db-database ${SPIP_DB_NAME} \
			--db-prefix ${SPIP_DB_PREFIX} \
			--admin-nom ${SPIP_ADMIN_NAME} \
			--admin-login ${SPIP_ADMIN_LOGIN} \
			--admin-email ${SPIP_ADMIN_EMAIL} \
			--admin-pass ${SPIP_ADMIN_PASS}" || [ "$try" -gt "$max_retries" ]; do
				echo "retrying install..."
				try=$((try+1))
				sleep 10s
		done
		if [ "$try" -gt "$max_retries" ]; then
			echo "installing of spip failed!"
			exit 1
		fi
	fi
fi

exec "$@"
