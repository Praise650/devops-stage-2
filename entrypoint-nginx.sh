#!/bin/sh
set -e

# Generate full config dynamically
cat > /etc/nginx/nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    upstream backend {
$(case "\$ACTIVE_POOL" in
    "blue")
        cat <<EOL
        server app_blue:3000 max_fails=1 fail_timeout=5s;
        server app_green:3000 backup;
EOL
        ;;
    "green")
        cat <<EOL
        server app_green:3000 max_fails=1 fail_timeout=5s;
        server app_blue:3000 backup;
EOL
        ;;
    *)
        cat <<EOL
        server app_blue:3000 max_fails=1 fail_timeout=5s;
        server app_green:3000 backup;
EOL
        ;;
esac)
        keepalive 32;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
            proxy_next_upstream_timeout 5s;
            proxy_next_upstream_tries 1;

            proxy_connect_timeout 5s;
            proxy_send_timeout 5s;
            proxy_read_timeout 5s;

            # Forward headers unchanged
            proxy_pass_header X-App-Pool;
            proxy_pass_header X-Release-Id;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# Validate config
if ! nginx -t; then
    echo "Config error! Generated conf:"
    cat /etc/nginx/nginx.conf
    exit 1
fi

# Start nginx (supports hot reload: docker compose exec nginx nginx -s reload)
exec nginx -g 'daemon off;'