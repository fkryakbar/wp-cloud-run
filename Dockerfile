FROM wordpress:php8.2-apache

# =========================
# ENV DEFAULTS
# =========================
ENV TAILSCALE_STATE_DIR=/var/lib/tailscale \
    TAILSCALE_SOCKET=/var/run/tailscale/tailscaled.sock

# =========================
# INSTALL DEPENDENCIES
# =========================
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# =========================
# INSTALL TAILSCALE
# =========================
RUN curl -fsSL https://tailscale.com/install.sh | sh

# =========================
# APACHE MODULES
# =========================
RUN a2enmod headers rewrite expires remoteip

# =========================
# APACHE HARDENING
# =========================
RUN { \
    echo "ServerTokens Prod"; \
    echo "ServerSignature Off"; \
} >> /etc/apache2/conf-available/security.conf

RUN a2enconf security

# =========================
# APACHE DIRECTORY PERMISSION (WAJIB CLOUD RUN)
# =========================
RUN echo '<Directory /var/www/html>' \
    '\n  AllowOverride All' \
    '\n  Require all granted' \
    '\n</Directory>' \
    > /etc/apache2/conf-available/wordpress.conf

RUN a2enconf wordpress

# =========================
# WORDPRESS PERMISSION FIX
# =========================
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# =========================
# UPLOAD DIRECTORY (EXTERNAL READY)
# =========================
RUN mkdir -p /var/www/html/wp-content/uploads \
    && chown -R www-data:www-data /var/www/html/wp-content

# =========================
# ENTRYPOINT
# =========================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
