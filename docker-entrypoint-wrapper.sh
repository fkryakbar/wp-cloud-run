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
    
    # Start tailscaled in userspace networking mode (required for Cloud Run)
    /usr/local/bin/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --state=/var/lib/tailscale/tailscaled.state &
    
    # Wait for tailscaled to be ready
    sleep 2
    
    # Authenticate with Tailscale
    HOSTNAME="${TAILSCALE_HOSTNAME:-wordpress-cloudrun}"
    echo "Connecting to Tailscale as $HOSTNAME..."
    /usr/local/bin/tailscale up --auth-key=${TAILSCALE_AUTHKEY} --hostname=${HOSTNAME}
    
    echo "Tailscale started successfully!"
    /usr/local/bin/tailscale status || true
    
    # Set ALL_PROXY for applications that support it
    export ALL_PROXY=socks5://localhost:1055/
    export HTTP_PROXY=socks5://localhost:1055/
    export HTTPS_PROXY=socks5://localhost:1055/
    
    # For MySQL/PHP which don't support SOCKS proxy natively,
    # we need to use Tailscale's built-in TCP forwarding via tailscale nc
    # This is done by setting up the database host to use MagicDNS name
    echo ""
    echo "=== IMPORTANT ==="
    echo "For MySQL connection via Tailscale, use the MagicDNS hostname instead of IP."
    echo "Example: WORDPRESS_DB_HOST=your-mysql-server (the Tailscale machine name)"
    echo "Or use: WORDPRESS_DB_HOST=your-mysql-server.tailnet-name.ts.net"
    echo "================="
    echo ""
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
