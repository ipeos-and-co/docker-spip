FROM php:8.1-apache-bookworm
LABEL maintainer="docker@ipeos.com"
LABEL authors="Laurent Vergerolle <docker@ipeos.com>, Michael Nival <docker@mn-home.fr>"

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	ghostscript \
	netcat-traditional \
	; \
	rm -rf /var/lib/apt/lists/*;

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
	libxml2-dev \
	libssl-dev \
	libfreetype6-dev \
	libjpeg62-turbo-dev \
	libpng-dev \
	libzip-dev \
	sqlite3 \
	libsqlite3-dev \
	zlib1g-dev \
	libsodium-dev \
	netpbm \
	imagemagick \
	libldap2-dev \
	libicu-dev \
	libmagickwand-dev \
	libwebp-dev \
	; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
	docker-php-ext-install -j$(nproc) \
	gd \
	xml \
	exif \
	bcmath \
	mysqli \
	pdo pdo_sqlite \
	sodium \
	zip \
	phar \
	opcache \
	; \
	\
	docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; \
	docker-php-ext-install ldap; \
	pecl install imagick; \
	docker-php-ext-enable imagick; \
	pecl install apcu; \
	docker-php-ext-enable apcu; \
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual netpbm imagemagick $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
	| awk '/=>/ { print $3 }' \
	| sort -u \
	| xargs -r dpkg-query -S \
	| cut -d: -f1 \
	| sort -u \
	| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /tmp/*; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
	echo 'opcache.enable_cli=1'; \
	echo 'opcache.memory_consumption=256'; \
	echo 'opcache.interned_strings_buffer=8'; \
	echo 'opcache.max_accelerated_files=20000'; \
	echo 'opcache.revalidate_freq=2'; \
	echo 'opcache.validate_timestamps=1'; \
	echo 'opcache.dups_fix=0'; \
	echo 'opcache.validate_root=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
	# https://www.php.net/manual/en/errorfunc.constants.php
	echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
	echo 'display_errors = Off'; \
	echo 'display_startup_errors = Off'; \
	echo 'log_errors = On'; \
	echo 'error_log = /dev/stderr'; \
	echo 'log_errors_max_len = 1024'; \
	echo 'ignore_repeated_errors = On'; \
	echo 'ignore_repeated_source = Off'; \
	echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini

RUN set -eux; \
	a2enmod rewrite expires headers; \
	{ \
	echo 'ServerSignature Off'; \
	echo 'ServerTokens Prod'; \
	echo 'Header unset Composed-By'; \
	echo 'Header unset X-Powered-By'; \
	} > /etc/apache2/conf-enabled/spip_headers.conf; \
	# https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
	a2enmod remoteip; \
	{ \
	echo 'RemoteIPHeader X-Forwarded-For'; \
	# these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
	echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
	echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
	echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
	echo 'RemoteIPInternalProxy 169.254.0.0/16'; \
	echo 'RemoteIPInternalProxy 127.0.0.0/8'; \
	} > /etc/apache2/conf-available/remoteip.conf; \
	a2enconf remoteip; \
	# (replace all instances of "%h" with "%a" in LogFormat)
	find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

ENV SPIP_VERSION 4.1
ENV SPIP_PACKAGE 4.1.17

# Install SPIP-Cli
RUN set -eux; \
	cd /opt; \
	curl --silent --show-error https://getcomposer.org/installer | php; \
	fetchDeps=" \
	git \
	unzip \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	\
	git clone https://git.spip.net/spip-contrib-outils/spip-cli.git /opt/spip-cli; \
	rm -rf /opt/spip-cli/.git; \
	rm -rf /opt/spip-cli/.gitattributes; \
	rm -rf /opt/spip-cli/.gitignore; \
	ln -s /opt/spip-cli/bin/spip /usr/local/bin/spip; \
	ln -s /opt/spip-cli/bin/spipmu /usr/local/bin/spipmu; \
	cd /opt/spip-cli && /opt/composer.phar install; \
	\
	curl -o spip.zip -fSL "files.spip.net/spip/archives/spip-v${SPIP_PACKAGE}.zip"; \
	unzip spip.zip -d /usr/src/spip; \
	rm spip.zip; \
	chown -R www-data:www-data /usr/src/spip; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /tmp/*; \
	rm -rf /var/lib/apt/lists/*

VOLUME /var/www/html

# SPIP
ENV SPIP_AUTO_INSTALL 1
ENV SPIP_DB_SERVER mysql
ENV SPIP_DB_HOST mysql
ENV SPIP_DB_LOGIN spip
ENV SPIP_DB_PASS spip
ENV SPIP_DB_NAME spip
ENV SPIP_DB_PREFIX spip
ENV SPIP_ADMIN_NAME Admin
ENV SPIP_ADMIN_LOGIN admin
ENV SPIP_ADMIN_EMAIL admin@spip
ENV SPIP_ADMIN_PASS adminadmin
ENV SPIP_SITE_ADDRESS http://localhost

# PHP
ENV PHP_MAX_EXECUTION_TIME 60
ENV PHP_MEMORY_LIMIT 256M
ENV PHP_POST_MAX_SIZE 40M
ENV PHP_UPLOAD_MAX_FILESIZE 32M
ENV PHP_TIMEZONE America/Guadeloupe

EXPOSE 80

COPY ./docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apache2-foreground"]
