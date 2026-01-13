FROM alpine:3.18

WORKDIR /var/www/html

RUN apk update && apk upgrade

# Credits to : https://github.com/TrafeX/docker-php-nginx/tree/master
# Install packages and remove default server definition
RUN apk add --no-cache \
    curl \
    envsubst \
    nginx \
    mariadb \
    mariadb-client \
    php82 \
    php82-ctype \
    php82-curl \
    php82-dom \
    php82-fileinfo \
    php82-fpm \
    php82-gd \
    php82-iconv \
    php82-intl \
    php82-mbstring \
    php82-mysqli \
    php82-opcache \
    php82-openssl \
    php82-phar \
    php82-session \
    php82-simplexml \
    php82-sodium \
    php82-tokenizer \
    php82-xml \
    php82-xmlreader \
    php82-xmlwriter \
    php82-zip \
    supervisor

# Remove Cache
RUN rm -rf /tmp/*
RUN rm -rf /var/cache/apk/*

# Configure PHP-FPM
ENV PHP_INI_DIR=/etc/php82
COPY config/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY config/php.ini ${PHP_INI_DIR}/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /var/www/html /run /var/lib/nginx /var/log/nginx

# Create symlink for php
RUN ln -s /usr/bin/php82 /usr/bin/php

# Configure maria DB
COPY --chown=nobody config/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf
RUN mysql_install_db --user=nobody --ldata=/var/lib/mysql
RUN mkdir -p /var/lib/mysql
RUN chown -R nobody.nobody /var/lib/mysql
RUN mkdir -p /run/mysqld
RUN chown -R nobody.nobody /run/mysqld
VOLUME /var/lib/mysql

# Configure moodle
ENV MOODLE_HOST=localhost
ENV MOODLE_PORT=9090
RUN wget "https://download.moodle.org/download.php/direct/stable403/moodle-latest-403.tgz" -O /tmp/moodle.tgz
RUN chown nobody.nobody /tmp/moodle.tgz
RUN mkdir /var/www/moodledata
RUN chown -R nobody.nobody /var/www/moodledata
VOLUME /var/www

# Simple Cron
COPY --chown=nobody scripts/simple_cron.sh /usr/nobody/simple_cron.sh
RUN chmod +x /usr/nobody/simple_cron.sh
RUN touch /usr/nobody/simple_cron.log
RUN chown -R nobody.nobody /usr/nobody/simple_cron.log

# Configure nginx - http
COPY  --chown=nobody config/nginx.conf /etc/nginx/nginx.conf
# Configure nginx - default server
COPY  --chown=nobody config/conf.d /etc/nginx/conf.d/
RUN chown -R nobody.nobody /etc/nginx/conf.d/

# INIT SCRIPT
COPY --chown=nobody scripts/init_script.sh /usr/local/bin/init_script.sh
RUN chmod +x /usr/local/bin/init_script.sh

# Switch to use a non-root user from here on
USER nobody

# Expose the port nginx is reachable on
EXPOSE ${MOODLE_PORT}

# Let supervisord start nginx & php-fpm
CMD ["/usr/local/bin/init_script.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail "http://localhost:${MOODLE_PORT}/index.php"
