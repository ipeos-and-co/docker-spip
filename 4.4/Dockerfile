FROM php:8.4-apache-trixie@sha256:4af38a0245996e700e20ec211b9f1c44fb789ad8cc7d24c7ea81ff382b641052
LABEL maintainer="docker@ipeos.com"
LABEL authors="Laurent Vergerolle <docker@ipeos.com>, Michael Nival <docker@mn-home.fr>"
LABEL org.opencontainers.image.title="SPIP"
LABEL org.opencontainers.image.description="SPIP 4.4 CMS on PHP 8.4 / Apache"
LABEL org.opencontainers.image.source="https://github.com/ipeos-and-co/docker-spip"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.version="4.4.28"

# ghostscript : vignettes des PDF/EPS via imagick, restreint par la politique
# ImageMagick posee plus bas. netcat n'est pas installe, l'attente de la base
# utilise /dev/tcp de bash (cf. docker-entrypoint.sh).
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	ghostscript \
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
	libavif-dev \
	libfreetype6-dev \
	libjpeg-dev \
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
	libwebp-dev; \
	\
	docker-php-ext-configure gd --with-avif --with-freetype --with-jpeg --with-webp; \
	\
	docker-php-ext-install -j$(nproc) \
	gd \
	xml \
	exif \
	bcmath \
	mysqli \
	pdo \
	pdo_sqlite \
	sodium \
	zip \
	opcache; \
	\
	docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
	docker-php-ext-install ldap; \
	\
	# pecl.php.net ne sert plus les archives (504) : imagick et apcu sont construits avec
	# phpize depuis l'archive de leur tag GitHub. Les *_arginfo.h sont rafraichis pour que
	# make ne les regenere pas : la regeneration telecharge PHP-Parser sans verification.
	curl -fL -o imagick.tar.gz 'https://github.com/Imagick/imagick/archive/refs/tags/3.8.1.tar.gz'; \
	echo 'b0e9279ddf6e75a8c6b4068e16daec0475427dbca7ce2e144e30a51a88aa5ddc *imagick.tar.gz' | sha256sum -c -; \
	mkdir imagick; \
	tar -xzf imagick.tar.gz -C imagick --strip-components=1; \
	# substitution que pecl applique d'apres package.xml
	sed -i 's/@PACKAGE_VERSION@/3.8.1/' imagick/php_imagick.h; \
	( cd imagick && touch *_arginfo.h && phpize && ./configure --with-imagick && make -j"$(nproc)" && make install ); \
	rm -rf imagick imagick.tar.gz; \
	docker-php-ext-enable imagick; \
	test "$(php -r 'echo phpversion("imagick");')" = '3.8.1'; \
	\
	curl -fL -o apcu.tar.gz 'https://github.com/krakjoe/apcu/archive/refs/tags/v5.1.28.tar.gz'; \
	echo '0e60ba9d0fa4021c57a70c071f3d8f71de236275d084e560d5959fec4edd8c32 *apcu.tar.gz' | sha256sum -c -; \
	mkdir apcu; \
	tar -xzf apcu.tar.gz -C apcu --strip-components=1; \
	( cd apcu && touch *_arginfo.h && phpize && ./configure --enable-apcu && make -j"$(nproc)" && make install ); \
	rm -rf apcu apcu.tar.gz; \
	docker-php-ext-enable apcu; \
	test "$(php -r 'echo phpversion("apcu");')" = '5.1.28'; \
	out="$(php -r 'exit(0);')"; \
	[ -z "$out" ]; \
	err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]; \
	\
	extDir="$(php -r 'echo ini_get("extension_dir");')"; \
	[ -d "$extDir" ]; \
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual netpbm imagemagick $savedAptMark; \
	ldd "$extDir"/*.so \
	| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
	| sort -u \
	| xargs -r dpkg-query --search \
	| cut -d: -f1 \
	| sort -u \
	| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	! { ldd "$extDir"/*.so | grep 'not found'; }; \
	# check for output like "PHP Warning:  PHP Startup: Unable to load dynamic library 'foo' (tried: ...)
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]

# Compte non privilegie proprietaire des fichiers que le serveur web ne doit pas ecrire.
# L'uid 1000 est celui du premier compte sur la plupart des hotes : les fichiers montes
# depuis l'hote gardent ainsi un proprietaire exploitable en dehors du conteneur.
RUN set -eux; \
	groupadd -g 1000 spip; \
	useradd -u 1000 -g 1000 -M -s /usr/sbin/nologin spip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
	echo 'opcache.enable_cli=1'; \
	echo 'opcache.memory_consumption=128'; \
	echo 'opcache.interned_strings_buffer=8'; \
	echo 'opcache.max_accelerated_files=10000'; \
	echo 'opcache.revalidate_freq=2'; \
	echo 'opcache.validate_timestamps=1'; \
	echo 'opcache.dups_fix=0'; \
	echo 'opcache.fast_shutdown=1'; \
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

# Restreint la politique ImageMagick aux formats utiles au web. Les coders PostScript,
# EPS et PDF passent par ghostscript, que SPIP n'a pas besoin d'atteindre.
RUN set -eux; \
	IM_POLICY="$(find /etc -name policy.xml -path '*ImageMagick*' | head -n 1)"; \
	[ -n "$IM_POLICY" ]; \
	sed -i 's!</policymap>!  <policy domain="coder" rights="none" pattern="{PS,PS2,PS3,EPS,PDF,XPS,MSL,MVG,TEXT,SHOW,WIN,PLT}" />\n  <policy domain="delegate" rights="none" pattern="gs" />\n</policymap>!' "$IM_POLICY"; \
	grep -q 'pattern="{PS,PS2' "$IM_POLICY"

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

# Coupe le moteur PHP dans IMG/ et local/ (cf. spip-hardening.conf).
COPY ./spip-hardening.conf /etc/apache2/conf-available/spip-hardening.conf
RUN set -eux; \
	a2enconf spip-hardening; \
	apache2ctl -t

ENV SPIP_VERSION=4.4
ENV SPIP_PACKAGE=4.4.28

# Install SPIP-Cli
RUN set -eux; \
	cd /opt; \
	EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"; \
	curl -fsSL -o composer-setup.php https://getcomposer.org/installer; \
	echo "$EXPECTED_CHECKSUM *composer-setup.php" | sha384sum -c -; \
	php composer-setup.php --install-dir=/opt; \
	rm composer-setup.php; \
	fetchDeps=" \
	git \
	unzip \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	\
	git clone --depth 1 --branch 2.0.1 https://git.spip.net/spip-contrib-outils/spip-cli.git /opt/spip-cli; \
	# un tag git est deplaçable : on verifie le commit obtenu
	test "$(git -C /opt/spip-cli rev-parse HEAD)" = '40f2a8ac52875270f681a0ef159c8bb300e5fd4c'; \
	rm -rf /opt/spip-cli/.git; \
	rm -rf /opt/spip-cli/.gitattributes; \
	rm -rf /opt/spip-cli/.gitignore; \
	ln -s /opt/spip-cli/bin/spip /usr/local/bin/spip; \
	ln -s /opt/spip-cli/bin/spipmu /usr/local/bin/spipmu; \
	cd /opt/spip-cli && /opt/composer.phar install --no-dev --prefer-dist --no-interaction; \
	rm /opt/composer.phar; \
	\
	curl -o spip.zip -fSL "https://files.spip.net/spip/archives/spip-v${SPIP_PACKAGE}.zip"; \
	echo "15016e75d097f322e307ec3aa718fc14a5aa2c2e8c7fcc8c4184aeaef84e6706 *spip.zip" | sha256sum -c -; \
	unzip -q spip.zip -d /usr/src/spip; \
	rm spip.zip; \
	chown -R www-data:www-data /usr/src/spip; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /tmp/*; \
	rm -rf /var/lib/apt/lists/*

# Retire la chaine de compilation heritee de l'image de base : elle n'a plus d'usage
# une fois les extensions PHP construites.
RUN set -eux; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	gcc g++ make autoconf dpkg-dev libc6-dev re2c pkg-config \
	|| true; \
	rm -rf /var/lib/apt/lists/*; \
	# les extensions doivent toujours se charger
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]

VOLUME /var/www/html

# SPIP
ENV SPIP_AUTO_INSTALL=1
ENV SPIP_DB_SERVER=mysql
ENV SPIP_DB_HOST=mysql
ENV SPIP_DB_PORT=3306
ENV SPIP_DB_LOGIN=spip
ENV SPIP_DB_NAME=spip
ENV SPIP_DB_PREFIX=spip
ENV SPIP_ADMIN_NAME=Admin
ENV SPIP_ADMIN_LOGIN=admin
ENV SPIP_ADMIN_EMAIL=admin@spip
ENV SPIP_SITE_ADDRESS=http://localhost
# SPIP_DB_PASS et SPIP_ADMIN_PASS ne sont pas declares ici, pour ne pas figurer dans les
# metadonnees de l'image. Leurs valeurs de repli (`spip` / `adminadmin`) sont appliquees
# par docker-entrypoint.sh, qui les retire de l'environnement avant de lancer Apache.
# Variantes fichier : SPIP_DB_PASS_FILE, SPIP_ADMIN_PASS_FILE (secrets Docker).

# PHP
ENV PHP_MAX_EXECUTION_TIME=60
ENV PHP_MEMORY_LIMIT=256M
ENV PHP_POST_MAX_SIZE=40M
ENV PHP_UPLOAD_MAX_FILESIZE=32M
ENV PHP_TIMEZONE=America/Guadeloupe

EXPOSE 80

COPY --chmod=0755 ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apache2-foreground"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=7 \
	CMD curl -fsS http://localhost/ || exit 1