FROM php:7.2-apache
LABEL maintainer "Laurent Vergerolle <docker@ipeos.com>"

RUN apt-get update

# Install ghostscript
RUN apt-get install --no-install-recommends -y \
  ghostscript

# Install mcrypt
RUN apt-get install --no-install-recommends -y \
    libmcrypt-dev \
    mcrypt

# Install gd
RUN apt-get install --no-install-recommends -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
  ; \
  docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/; \
  docker-php-ext-install -j$(nproc) gd exif bcmath

# Install mysql
RUN apt-get install --no-install-recommends -y \
    default-mysql-client \
  ; \
  docker-php-ext-install mysqli

# Install Imagick
RUN apt-get install --no-install-recommends -y \
    libjpeg-dev \
    libmagickwand-dev \
    libpng-dev \
    libzip-dev \
  ; \
  pecl install imagick; \
  docker-php-ext-enable imagick

# Active over php extension
RUN docker-php-ext-install zip opcache

# Install utils
RUN apt-get install --no-install-recommends -y \
    unzip \
    gettext-base \
    libsvn1 \
    subversion

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

# Install SPIP-Cli
RUN cd /opt; \
  curl --silent --show-error https://getcomposer.org/installer | php

RUN svn checkout svn://zone.spip.org/spip-zone/_outils_/spip-cli/trunk /opt/spip-cli; \
  rm -rf /opt/spip-cli/.svn; \
  ln -s /opt/spip-cli/bin/spip /usr/local/bin/spip; \
  ln -s /opt/spip-cli/bin/spipmu /usr/local/bin/spipmu;

RUN cd /opt/spip-cli && /opt/composer.phar install

VOLUME ["/var/www/html"]

ENV SPIP_VERSION 3.2
ENV SPIP_PACKAGE 3.2.7

# Install SPIP
RUN set -ex; \
  curl -o spip.zip -fSL "files.spip.net/spip/archives/SPIP-v${SPIP_PACKAGE}.zip"; \
  unzip spip.zip -d /usr/src/; \
  rm spip.zip; \
  chown -R www-data:www-data /usr/src/spip

# Remove SVN and apt cache
RUN apt-get purge -y \
    libsvn1 \
    subversion \
  ; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/*; \
  rm /var/log/dpkg.log

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
