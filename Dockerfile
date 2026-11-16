# SuiteCRM for Railway: the official PHP + Apache image plus the official
# SuiteCRM release package. SuiteCRM publishes no Docker image of its own.
FROM php:8.3.36-apache-bookworm@sha256:a14446c32a3c8aeb9b4dac7fb73b03dfd8006e670d9b43ea7947e4030d3cbae6

ARG SUITECRM_VERSION=8.10.2
# sha256 of SuiteCRM-${SUITECRM_VERSION}.zip, as listed on the GitHub release
ARG SUITECRM_SHA256=ac4693d10ea2d6cd20b3256098781d134599d88878fb24e8dc127038d624f5a8

ENV SUITECRM_VERSION=${SUITECRM_VERSION}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        unzip libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
        libicu-dev libldap2-dev libc-client-dev libkrb5-dev libxml2-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu; \
    docker-php-ext-install -j"$(nproc)" gd intl zip mysqli pdo_mysql soap ldap imap bcmath opcache; \
    apt-get purge -y --auto-remove libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
        libicu-dev libldap2-dev libc-client-dev libkrb5-dev libxml2-dev; \
    apt-get install -y --no-install-recommends libzip4 libpng16-16 libjpeg62-turbo libfreetype6 \
        libicu72 libldap-2.5-0 libc-client2007e libxml2; \
    rm -rf /var/lib/apt/lists/*; \
    php -m | grep -qi imap; php -m | grep -qi intl; php -m | grep -qi gd

RUN set -eux; \
    curl -fsSL -o /tmp/suitecrm.zip \
      "https://github.com/SuiteCRM/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip"; \
    echo "${SUITECRM_SHA256}  /tmp/suitecrm.zip" | sha256sum -c -; \
    mkdir -p /usr/src/suitecrm; \
    unzip -q /tmp/suitecrm.zip -d /usr/src/suitecrm; \
    rm /tmp/suitecrm.zip; \
    test -f /usr/src/suitecrm/bin/console; \
    chown -R www-data:www-data /usr/src/suitecrm

RUN a2enmod rewrite headers remoteip
COPY php.ini /usr/local/etc/php/conf.d/zz-suitecrm.ini
COPY apache-suitecrm.conf /etc/apache2/sites-available/000-default.conf
COPY setup-page/ /opt/setup-page/
COPY start.sh /usr/local/bin/suitecrm-start
RUN chmod +x /usr/local/bin/suitecrm-start

# The whole app directory (code, config, uploads, custom/) lives on a volume.
WORKDIR /var/www/html
ENV PORT=8080
CMD ["/usr/local/bin/suitecrm-start"]
