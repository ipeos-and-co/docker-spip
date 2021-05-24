FROM php:%%PHP_VERSION%%-apache
LABEL maintainer="docker@ipeos.com"
LABEL authors="Laurent Vergerolle <docker@ipeos.com>, Michael Nival <docker@mn-home.fr>"

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ghostscript \
		default-mysql-client \
	; \
	rm -rf /var/lib/apt/lists/*;

RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
		apt-get update; \
		apt-get install -y --no-install-recommends \
			libmcrypt-dev \
			libfreetype6-dev \
			libjpeg62-turbo-dev \
			libjpeg-dev \
			libmagickwand-dev \
			libpng-dev \
			libzip-dev \
		; \
		debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
		docker-php-ext-configure gd --with-freetype --with-jpeg; \
		docker-php-ext-install -j$(nproc) \
			gd \
			exif \
			bcmath \
			%%MYSQL_PACKAGE%% \
			zip \
			opcache \
		; \
		\
		pecl install imagick; \
		docker-php-ext-enable imagick; \
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=0'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Active apache rewrite mode
RUN a2enmod rewrite

ENV SPIP_VERSION %%SPIP_VERSION%%
ENV SPIP_PACKAGE %%SPIP_PACKAGE%%

# Install SPIP-Cli
RUN set -ex; \
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
	rm -rf /var/lib/apt/lists/*

VOLUME ["/var/www/html"]

# SPIP
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
