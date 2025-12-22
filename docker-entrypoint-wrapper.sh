#!/bin/bash
set -e

# Cloud Run compatibility: Listen on PORT environment variable
if [ -n "$PORT" ]; then
    # Update Apache to listen on Cloud Run's PORT
    sed -i "s/Listen 80/Listen $PORT/g" /etc/apache2/ports.conf
    sed -i "s/:80/:$PORT/g" /etc/apache2/sites-available/000-default.conf
    echo "Apache configured to listen on port $PORT"
fi

# Start Tailscale if auth key is provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Starting Tailscale daemon in userspace networking mode..."
    
    # Create state directory
    mkdir -p /var/lib/tailscale /var/run/tailscale
    
    # Start tailscaled in userspace networking mode (no TUN device needed)
    tailscaled --state=/var/lib/tailscale/tailscaled.state \
               --socket=/var/run/tailscale/tailscaled.sock \
               --tun=userspace-networking \
               --socks5-server=localhost:1055 \
               --outbound-http-proxy-listen=localhost:1055 &
    
    # Wait for tailscaled to be ready
    sleep 3
    
    # Authenticate with Tailscale
    HOSTNAME="${TAILSCALE_HOSTNAME:-wordpress-$(hostname)}"
    echo "Connecting to Tailscale as $HOSTNAME..."
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$HOSTNAME" --accept-dns=false
    
    echo "Tailscale connected successfully!"
    tailscale status || true
fi

# Generate WordPress salts if not provided
if [ -z "$WORDPRESS_AUTH_KEY" ]; then
    export WORDPRESS_AUTH_KEY=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_SECURE_AUTH_KEY" ]; then
    export WORDPRESS_SECURE_AUTH_KEY=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_LOGGED_IN_KEY" ]; then
    export WORDPRESS_LOGGED_IN_KEY=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_NONCE_KEY" ]; then
    export WORDPRESS_NONCE_KEY=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_AUTH_SALT" ]; then
    export WORDPRESS_AUTH_SALT=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_SECURE_AUTH_SALT" ]; then
    export WORDPRESS_SECURE_AUTH_SALT=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_LOGGED_IN_SALT" ]; then
    export WORDPRESS_LOGGED_IN_SALT=$(openssl rand -base64 48)
fi
if [ -z "$WORDPRESS_NONCE_SALT" ]; then
    export WORDPRESS_NONCE_SALT=$(openssl rand -base64 48)
fi

# Execute the original WordPress entrypoint
exec docker-entrypoint.sh "$@"
