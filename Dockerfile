FROM php:7.2-fpm

LABEL vendor="Mautic"
LABEL maintainer="Luiz Eduardo Oliveira Fonseca <luiz@powertic.com>"

# set version label
ARG BUILD_DATE
ARG VERSION
ARG EXT_VERSION
LABEL build_version="gustavo8000br version:- ${VERSION} Build-date:- ${BUILD_DATE}"

# Install PHP extensions
RUN apt-get update && apt-get install --no-install-recommends -y \
    cron \
    git \
    wget \
    sudo \
    libc-client-dev \
    libicu-dev \
    libkrb5-dev \
    libmcrypt-dev \
    libssl-dev \
    libz-dev \
    unzip \
    zip \
    jq \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/cron.daily/*

RUN set -x && pecl install mcrypt > /dev/null \
    && docker-php-ext-enable mcrypt.so > /dev/null \
    && docker-php-ext-configure imap --with-imap --with-imap-ssl --with-kerberos > /dev/null \
    && docker-php-ext-configure opcache --enable-opcache > /dev/null \
    && docker-php-ext-install imap intl mbstring mysqli pdo_mysql zip opcache bcmath > /dev/null \
    && docker-php-ext-enable imap intl mbstring mysqli pdo_mysql zip opcache bcmath > /dev/null

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Define Mautic volume to persist data
VOLUME /var/www/html

# By default enable cron jobs
ENV MAUTIC_RUN_CRON_JOBS true

# Setting an root user for test
ENV MAUTIC_DB_USER root
ENV MAUTIC_DB_NAME mautic

# Setting PHP properties
ENV PHP_INI_DATE_TIMEZONE='UTC' \
	PHP_MEMORY_LIMIT=512M \
	PHP_MAX_UPLOAD=128M \
	PHP_MAX_EXECUTION_TIME=300

# Download package and extract to web volume
RUN echo "**** install mautic ****" && \
    if [ -z ${EXT_VERSION+x} ]; then \
	EXT_VERSION=$(curl -sX GET "https://api.github.com/repos/mautic/mautic/releases" \
	| jq -r 'first(.[] | select(.prerelease == true)) | .tag_name'); \
    fi && \
    curl -o mautic.zip -SL https://github.com/mautic/mautic/releases/download/${EXT_VERSION}/${EXT_VERSION}.zip \
	&& mkdir /usr/src/mautic \
	&& unzip -q mautic.zip -d /usr/src/mautic \
	&& chown -R www-data:www-data /usr/src/mautic \
    && echo "**** clean up ****" \
	&& rm mautic.zip 

# Copy init scripts and custom .htaccess
COPY docker-entrypoint.sh /entrypoint.sh
COPY makeconfig.php /makeconfig.php
COPY makedb.php /makedb.php
COPY mautic.crontab /etc/cron.d/mautic
RUN chmod 644 /etc/cron.d/mautic

# Apply necessary permissions
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

CMD ["php-fpm"]
