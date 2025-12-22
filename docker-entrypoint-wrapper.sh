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
    
    # Setup MySQL proxy via Tailscale if DB host is a Tailscale IP (100.x.x.x)
    if [ -n "$WORDPRESS_DB_HOST" ]; then
        # Extract host and port
        DB_HOST_ONLY=$(echo "$WORDPRESS_DB_HOST" | cut -d: -f1)
        DB_PORT=$(echo "$WORDPRESS_DB_HOST" | grep -o ':[0-9]*' | tr -d ':')
        DB_PORT=${DB_PORT:-3306}
        
        # Check if it's a Tailscale IP (100.x.x.x range)
        if echo "$DB_HOST_ONLY" | grep -qE '^100\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "Setting up MySQL proxy for Tailscale IP $DB_HOST_ONLY:$DB_PORT..."
            
            # Start socat to proxy MySQL through Tailscale
            socat TCP-LISTEN:3307,fork,reuseaddr SOCKS4A:localhost:$DB_HOST_ONLY:$DB_PORT,socksport=1055 &
            
            # Override WordPress DB host to use local proxy
            export WORDPRESS_DB_HOST="127.0.0.1:3307"
            echo "MySQL proxy started on 127.0.0.1:3307 -> $DB_HOST_ONLY:$DB_PORT via Tailscale"
        fi
    fi
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
