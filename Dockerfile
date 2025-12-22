# WordPress Production-Ready Dockerfile
# Optimized for Cloud Run and containerized environments

FROM wordpress:6.4-php8.2-apache

# Set environment variables
ENV WORDPRESS_DB_HOST=localhost \
    WORDPRESS_DB_USER=wordpress \
    WORDPRESS_DB_PASSWORD=wordpress \
    WORDPRESS_DB_NAME=wordpress \
    WORDPRESS_TABLE_PREFIX=wp_ \
    WORDPRESS_DEBUG=false \
    TAILSCALE_AUTHKEY= \
    TAILSCALE_HOSTNAME=wordpress-cloud-run

# Install additional PHP extensions and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libzip-dev \
    libicu-dev \
    zlib1g-dev \
    unzip \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo_mysql \
    zip \
    intl \
    opcache \
    exif \
    bcmath \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Tailscale and socat (for TCP proxy)
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends tailscale socat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure PHP for production
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=64M'; \
    echo 'memory_limit=256M'; \
    echo 'max_execution_time=300'; \
    echo 'max_input_time=300'; \
    echo 'max_input_vars=3000'; \
    echo 'expose_php=Off'; \
    echo 'display_errors=Off'; \
    echo 'log_errors=On'; \
    echo 'error_log=/dev/stderr'; \
    echo 'session.cookie_httponly=1'; \
    echo 'session.cookie_secure=1'; \
    echo 'session.use_strict_mode=1'; \
    } > /usr/local/etc/php/conf.d/custom-php.ini

# Enable Apache modules for production
RUN a2enmod rewrite expires headers deflate ssl

# Configure Apache for production
RUN { \
    echo '<IfModule mod_expires.c>'; \
    echo '    ExpiresActive On'; \
    echo '    ExpiresByType image/jpg "access plus 1 year"'; \
    echo '    ExpiresByType image/jpeg "access plus 1 year"'; \
    echo '    ExpiresByType image/gif "access plus 1 year"'; \
    echo '    ExpiresByType image/png "access plus 1 year"'; \
    echo '    ExpiresByType image/webp "access plus 1 year"'; \
    echo '    ExpiresByType image/svg+xml "access plus 1 year"'; \
    echo '    ExpiresByType image/x-icon "access plus 1 year"'; \
    echo '    ExpiresByType text/css "access plus 1 month"'; \
    echo '    ExpiresByType application/javascript "access plus 1 month"'; \
    echo '    ExpiresByType application/pdf "access plus 1 month"'; \
    echo '    ExpiresByType application/x-font-ttf "access plus 1 year"'; \
    echo '    ExpiresByType application/x-font-woff "access plus 1 year"'; \
    echo '    ExpiresByType font/woff "access plus 1 year"'; \
    echo '    ExpiresByType font/woff2 "access plus 1 year"'; \
    echo '</IfModule>'; \
    } > /etc/apache2/conf-available/expires.conf \
    && a2enconf expires

RUN { \
    echo '<IfModule mod_deflate.c>'; \
    echo '    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css'; \
    echo '    AddOutputFilterByType DEFLATE application/javascript application/x-javascript application/json'; \
    echo '    AddOutputFilterByType DEFLATE application/xml application/xhtml+xml application/rss+xml'; \
    echo '    AddOutputFilterByType DEFLATE image/svg+xml'; \
    echo '</IfModule>'; \
    } > /etc/apache2/conf-available/deflate.conf \
    && a2enconf deflate

# Security headers configuration
RUN { \
    echo '<IfModule mod_headers.c>'; \
    echo '    Header always set X-Content-Type-Options "nosniff"'; \
    echo '    Header always set X-Frame-Options "SAMEORIGIN"'; \
    echo '    Header always set X-XSS-Protection "1; mode=block"'; \
    echo '    Header always set Referrer-Policy "strict-origin-when-cross-origin"'; \
    echo '    Header unset X-Powered-By'; \
    echo '    Header unset Server'; \
    echo '</IfModule>'; \
    } > /etc/apache2/conf-available/security-headers.conf \
    && a2enconf security-headers

# Hide Apache version
RUN { \
    echo 'ServerTokens Prod'; \
    echo 'ServerSignature Off'; \
    } >> /etc/apache2/apache2.conf

# Set recommended WordPress permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# Create healthcheck script
RUN { \
    echo '#!/bin/bash'; \
    echo 'curl -f http://localhost/wp-admin/install.php || curl -f http://localhost/ || exit 1'; \
    } > /usr/local/bin/healthcheck.sh \
    && chmod +x /usr/local/bin/healthcheck.sh

# Healthcheck for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Set working directory
WORKDIR /var/www/html

# Expose port 80 (Cloud Run uses 8080, but Apache listens on 80 by default)
EXPOSE 80

# Custom entrypoint wrapper for Cloud Run compatibility
COPY docker-entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

ENTRYPOINT ["docker-entrypoint-wrapper.sh"]
CMD ["apache2-foreground"]
