#!/bin/bash
set -e

echo "=== Cleaning up broken configs from previous deploys ==="
sudo rm -f /etc/nginx/conf.d/lyria.conf
sudo rm -f /etc/nginx/conf.d/lyria-ratelimit.conf

# Ensure nginx.conf has sites-enabled include (a previous deploy may have removed it)
if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf 2>/dev/null; then
  echo "Fixing nginx.conf: adding sites-enabled include..."
  sudo sed -i '/include.*conf\.d/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# Install certbot if needed
if ! command -v certbot &>/dev/null; then
  echo "Installing certbot..."
  sudo apt-get update
  sudo apt-get install -y certbot python3-certbot-nginx
fi

sudo mkdir -p /var/www/certbot
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

echo "=== Writing rate limit zones ==="
sudo tee /etc/nginx/conf.d/lyria-ratelimit.conf > /dev/null << 'RATELIMIT'
limit_req_zone $binary_remote_addr zone=lyria_api:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=lyria_auth:10m rate=5r/m;
RATELIMIT

echo "=== Searching for valid SSL certificate ==="
CERT_PATH=""
for dir in /etc/letsencrypt/live/lyria-sites \
           /etc/letsencrypt/live/lyria.risadev.com \
           /etc/letsencrypt/live/lyria.risadev.com-0001 \
           /etc/letsencrypt/live/lyria.risadev.com-0002 \
           /etc/letsencrypt/live/lyria.risadev.com-0003; do
  if [ -f "$dir/fullchain.pem" ]; then
    if openssl x509 -in "$dir/fullchain.pem" -noout -text 2>/dev/null | grep -q "admin.lyria.risadev.com"; then
      CERT_PATH="$dir"
      echo "Found valid cert covering both domains: $dir"
      break
    else
      echo "Cert at $dir exists but does not cover admin.lyria.risadev.com"
    fi
  fi
done

# If no valid cert found, request a new one via certbot webroot
if [ -z "$CERT_PATH" ]; then
  echo "=== Requesting new SSL certificate ==="

  # Write temporary HTTP-only config so ACME challenge can be served
  sudo tee /etc/nginx/sites-available/lyria > /dev/null << 'HTTPCFG'
server {
    listen 80;
    server_name lyria.risadev.com admin.lyria.risadev.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
HTTPCFG

  sudo ln -sf /etc/nginx/sites-available/lyria /etc/nginx/sites-enabled/lyria
  sudo nginx -t && sudo systemctl reload nginx

  sudo certbot certonly --webroot -w /var/www/certbot \
    --cert-name lyria-sites \
    -d lyria.risadev.com \
    -d admin.lyria.risadev.com \
    --non-interactive --agree-tos \
    --email contato@risadev.com \
    --force-renewal 2>&1 || true

  if [ -f "/etc/letsencrypt/live/lyria-sites/fullchain.pem" ]; then
    CERT_PATH="/etc/letsencrypt/live/lyria-sites"
    echo "Certificate obtained at: $CERT_PATH"
  fi
fi

# Fallback: accept any lyria cert even if it doesn't cover admin subdomain
if [ -z "$CERT_PATH" ]; then
  echo "WARNING: certbot failed or cert still missing. Falling back to any available lyria cert..."
  for dir in /etc/letsencrypt/live/lyria-sites \
             /etc/letsencrypt/live/lyria.risadev.com \
             /etc/letsencrypt/live/lyria.risadev.com-0001 \
             /etc/letsencrypt/live/lyria.risadev.com-0002 \
             /etc/letsencrypt/live/lyria.risadev.com-0003; do
    if [ -f "$dir/fullchain.pem" ]; then
      CERT_PATH="$dir"
      echo "Using fallback cert: $dir"
      break
    fi
  done
fi

if [ -z "$CERT_PATH" ] || [ ! -f "$CERT_PATH/fullchain.pem" ]; then
  echo "FATAL: No SSL certificate available!"
  ls -la /etc/letsencrypt/live/ 2>/dev/null || echo "No letsencrypt directory found"
  exit 1
fi

echo "Using certificate: $CERT_PATH"
openssl x509 -in "$CERT_PATH/fullchain.pem" -noout -subject -enddate 2>/dev/null || true

echo "=== Writing HTTPS nginx site config ==="
sudo tee /etc/nginx/sites-available/lyria > /dev/null << SITECFG
# Redirect HTTP -> HTTPS
server {
    listen 80;
    server_name lyria.risadev.com admin.lyria.risadev.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# API server — mobile app
server {
    listen 443 ssl http2;
    server_name lyria.risadev.com;

    ssl_certificate     ${CERT_PATH}/fullchain.pem;
    ssl_certificate_key ${CERT_PATH}/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_buffering    off;
        proxy_cache        off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location /auth/login {
        limit_req  zone=lyria_auth burst=3 nodelay;
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /auth/register {
        limit_req  zone=lyria_auth burst=3 nodelay;
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Admin panel
server {
    listen 443 ssl http2;
    server_name admin.lyria.risadev.com;

    ssl_certificate     ${CERT_PATH}/fullchain.pem;
    ssl_certificate_key ${CERT_PATH}/privkey.pem;

    root  /opt/lyria/admin;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        limit_req  zone=lyria_api burst=20 nodelay;
        proxy_pass http://127.0.0.1:9000/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering    off;
        proxy_cache        off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
SITECFG

sudo ln -sf /etc/nginx/sites-available/lyria /etc/nginx/sites-enabled/lyria

if ! sudo nginx -t 2>&1; then
  echo "ERROR: nginx config test failed! Dumping config:"
  cat /etc/nginx/sites-available/lyria
  exit 1
fi

sudo systemctl reload nginx

# Ensure certbot auto-renewal is enabled
sudo systemctl enable --now certbot.timer 2>/dev/null || true

echo "=== Nginx + SSL configured successfully ==="
