# Moodle 5.2 exige PHP >= 8.3.0 et PostgreSQL >= 16.
# Source de vérité : engines/moodle/public/admin/environment.xml, bloc MOODLE 5.2.
FROM php:8.3-fpm-bookworm

# Dépendances système des extensions à compiler.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev libicu-dev libzip-dev libxml2-dev \
        libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
        libonig-dev libsodium-dev \
        git unzip ghostscript graphviz \
    && rm -rf /var/lib/apt/lists/*

# Extensions absentes de l'image officielle. Celles déjà compilées dedans
# (ctype, curl, dom, fileinfo, filter, hash, iconv, json, mbstring, openssl,
#  pcre, simplexml, sodium, spl, xml, xmlreader, zlib) ne sont pas réinstallées :
# la vérification ci-dessous garantit qu'elles sont bien là.
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        gd intl zip soap exif opcache pgsql pdo_pgsql \
    && docker-php-ext-enable opcache

# phpredis : indispensable dès qu'on utilise Redis/Valkey pour les sessions.
# public/lib/classes/session/redis.php refuse de démarrer sans lui
# (extension_loaded('redis')). Valkey étant compatible au niveau protocole,
# la même extension sert pour les deux.
RUN pecl install redis \
    && docker-php-ext-enable redis

# Contrôle bloquant : si une extension exigée par Moodle 5.2 manque, la
# construction échoue ici, avec un message clair, plutôt que de produire une
# image qui tombera en panne à l'installation.
RUN set -eu ; \
    requises="ctype curl dom exif fileinfo filter gd hash iconv intl json \
              mbstring openssl pcre pgsql simplexml sodium spl xml xmlreader \
              zip zlib opcache redis" ; \
    absentes="" ; \
    for ext in $requises ; do \
        php -m | tr 'A-Z' 'a-z' | grep -qx "$ext" || absentes="$absentes $ext" ; \
    done ; \
    if [ -n "$absentes" ] ; then \
        echo "ERREUR : extensions PHP requises par Moodle 5.2 absentes :$absentes" >&2 ; \
        echo "Extensions présentes :" >&2 ; php -m >&2 ; \
        exit 1 ; \
    fi ; \
    echo "Toutes les extensions requises par Moodle 5.2 sont présentes." ; \
    php -v

# Réglages PHP adaptés au volume de fichiers de Moodle.
COPY infra/docker/moodle/php-moodle.ini /usr/local/etc/php/conf.d/zz-moodle.ini

# Le code Moodle arrive par volume depuis engines/moodle (sous-module).
# Racine web = public/ depuis Moodle 5.0 ; config.php reste à la racine.
WORKDIR /var/www/html

# moodledata doit rester hors de la racine web et inscriptible.
RUN mkdir -p /var/www/moodledata && chown -R www-data:www-data /var/www/moodledata

USER www-data
