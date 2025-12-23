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

    # Configure database tunneling
    if [ -n "$WORDPRESS_DB_HOST" ]; then
        # Default port to 3306 if not specified
        DB_HOST=${WORDPRESS_DB_HOST%:*}
        DB_PORT=${WORDPRESS_DB_HOST#*:}
        if [ "$DB_HOST" = "$DB_PORT" ]; then
            DB_PORT=3306
        fi

        echo "Setting up Tailscale tunnel for database: $DB_HOST:$DB_PORT"
        
        # Start socat for database forwarding via SOCKS5
        # Maps localhost:$DB_PORT -> socat -> SOCKS5(localhost:1055) -> Remote DB
        # We use a background process
        socat TCP4-LISTEN:$DB_PORT,fork,bind=127.0.0.1 SOCKS5:127.0.0.1:$DB_HOST:$DB_PORT,socksport=1055 &
        SOCAT_PID=$!
        
        # Give socat a moment to start
        sleep 1
        
        if kill -0 $SOCAT_PID >/dev/null 2>&1; then
            echo "Database tunnel started successfully on 127.0.0.1:$DB_PORT"
            # Point WordPress to use the local tunnel
            export WORDPRESS_DB_HOST="127.0.0.1:$DB_PORT"
        else
            echo "WARNING: Failed to start database tunnel via socat"
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
