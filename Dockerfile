# Build arguments
ARG OLS_VERSION
FROM litespeedtech/openlitespeed:${OLS_VERSION}

ARG WORDPRESS_TEMPLATE
ARG WORDPRESS_TEMPLATE_SQL

# Environment variables
ENV WP_ROOT=/var/www/vhosts/localhost/html \
    OLS_ROOT=/usr/local/lsws

USER root

# Copy build context
COPY template /tmp/build-context/template
COPY sql /tmp/build-context/sql

# Install WordPress and dependencies
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

# Setup database initialization
RUN mkdir -p /docker-entrypoint-initdb.d; \
    test -f "/tmp/build-context/${WORDPRESS_TEMPLATE_SQL}"; \
    cp "/tmp/build-context/${WORDPRESS_TEMPLATE_SQL}" /docker-entrypoint-initdb.d/init.sql; \
    rm -rf /tmp/build-context

# Copy configuration files
COPY scripts/docker-entrypoint.sh /usr/local/bin/ols-wp-entrypoint
COPY conf/ols/wordpress.htaccess ${WP_ROOT}/.htaccess
COPY conf/ols/admin/conf/htpasswd /usr/local/lsws/admin/conf/htpasswd
COPY conf/ols/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY conf/ols/vhosts/vhconf.conf /usr/local/lsws/conf/vhosts/Example/vhconf.conf

# Configure entrypoint and permissions
RUN set -eux; \
    sed -i 's/\r$//' /usr/local/bin/ols-wp-entrypoint /docker-entrypoint-initdb.d/init.sql; \
    chmod +x /usr/local/bin/ols-wp-entrypoint; \
    chown nobody:nogroup ${WP_ROOT}/.htaccess || chown nobody:nobody ${WP_ROOT}/.htaccess; \
    ln -sf /dev/stdout /usr/local/lsws/logs/access.log; \
    ln -sf /dev/stderr /usr/local/lsws/logs/error.log

EXPOSE 80 7080

ENTRYPOINT ["/usr/local/bin/ols-wp-entrypoint"]
CMD ["/usr/local/lsws/bin/openlitespeed", "-n"]
