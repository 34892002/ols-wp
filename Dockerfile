FROM litespeedtech/openlitespeed:1.9.0-lsphp85

ARG WORDPRESS_TEMPLATE=template/latest.tar.gz
ARG WORDPRESS_TEMPLATE_SQL=sql/latest.sql
ENV WP_ROOT=/var/www/vhosts/localhost/html \
    OLS_ROOT=/usr/local/lsws

USER root

COPY template /tmp/build-context/template
COPY sql /tmp/build-context/sql

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl unzip mariadb-client; \
    rm -rf /var/lib/apt/lists/*; \
    test -f "/tmp/build-context/${WORDPRESS_TEMPLATE}"; \
    mkdir -p /tmp/wp-src; \
    tar -xzf "/tmp/build-context/${WORDPRESS_TEMPLATE}" -C /tmp/wp-src --strip-components=1; \
    mkdir -p "$WP_ROOT"; \
    cp -a /tmp/wp-src/. "$WP_ROOT/"; \
    rm -rf /tmp/wp-src; \
    chown -R nobody:nogroup "$WP_ROOT" || chown -R nobody:nobody "$WP_ROOT"

RUN mkdir -p /docker-entrypoint-initdb.d; \
    test -f "/tmp/build-context/${WORDPRESS_TEMPLATE_SQL}"; \
    cp "/tmp/build-context/${WORDPRESS_TEMPLATE_SQL}" /docker-entrypoint-initdb.d/init.sql; \
    rm -rf /tmp/build-context

COPY scripts/docker-entrypoint.sh /usr/local/bin/ols-wp-entrypoint
COPY conf/ols/wordpress.htaccess ${WP_ROOT}/.htaccess
COPY conf/php/wordpress.ini /tmp/wordpress.ini
COPY conf/ols/admin/conf/htpasswd /usr/local/lsws/admin/conf/htpasswd

RUN set -eux; \
    sed -i 's/\r$//' /usr/local/bin/ols-wp-entrypoint /docker-entrypoint-initdb.d/init.sql; \
    chmod +x /usr/local/bin/ols-wp-entrypoint; \
    PHP_INI_SCAN_DIR=""; \
    for dir in \
      /usr/local/lsws/lsphp85/etc/php/8.5/conf.d \
      /usr/local/lsws/lsphp85/etc/php/8.4/conf.d \
      /usr/local/lsws/lsphp85/etc/php/8.3/conf.d \
      /usr/local/lsws/lsphp85/etc/php/8.2/conf.d \
      /usr/local/lsws/lsphp85/etc/php/8.1/conf.d \
      /usr/local/lsws/lsphp85/etc/php/8.0/conf.d; do \
      if [ -d "$dir" ]; then PHP_INI_SCAN_DIR="$dir"; break; fi; \
    done; \
    if [ -n "$PHP_INI_SCAN_DIR" ]; then cp /tmp/wordpress.ini "$PHP_INI_SCAN_DIR/99-wordpress.ini"; fi; \
    rm -f /tmp/wordpress.ini; \
    chown nobody:nogroup ${WP_ROOT}/.htaccess || chown nobody:nobody ${WP_ROOT}/.htaccess

EXPOSE 80 7080

ENTRYPOINT ["/usr/local/bin/ols-wp-entrypoint"]
CMD ["/usr/local/lsws/bin/openlitespeed", "-n"]
