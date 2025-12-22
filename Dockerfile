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
# WORDPRESS HARDENING
# =========================
RUN a2enmod headers rewrite expires remoteip

RUN { \
    echo "ServerTokens Prod"; \
    echo "ServerSignature Off"; \
} >> /etc/apache2/conf-available/security.conf

RUN a2enconf security

# =========================
# UPLOAD DIRECTORY (VOLUME / EXTERNAL)
# =========================
RUN mkdir -p /var/www/html/wp-content/uploads \
    && chown -R www-data:www-data /var/www/html/wp-content

# =========================
# ENTRYPOINT
# =========================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
