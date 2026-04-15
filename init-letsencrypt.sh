#!/bin/bash
# Run this script ONCE on the server before the first deploy to obtain SSL certificates.
# After this, certbot will auto-renew via the docker compose certbot service.
#
# Usage:
#   chmod +x init-letsencrypt.sh
#   ./init-letsencrypt.sh

set -e

DOMAINS=("lyria.risadev.com" "admin.lyria.risadev.com")
EMAIL="your-email@example.com"  # <- Replace with your email
STAGING=0                        # Set to 1 for testing (avoids Let's Encrypt rate limits)

DATA_PATH="/var/lib/docker/volumes/lyria_certbot-conf/_data"
TMP_NGINX_CONF="/opt/lyria/nginx/conf.d/default.conf"

# --------------------------------------------------------------------------
# 1. Create placeholder certs so nginx can start without real SSL certs
# --------------------------------------------------------------------------
echo "### Creating placeholder certificates ..."
for domain in "${DOMAINS[@]}"; do
  mkdir -p "$DATA_PATH/live/$domain"
  if [ ! -f "$DATA_PATH/live/$domain/privkey.pem" ]; then
    docker run --rm \
      -v "lyria_certbot-conf:/etc/letsencrypt" \
      --entrypoint openssl \
      certbot/certbot \
      req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout "/etc/letsencrypt/live/$domain/privkey.pem" \
      -out "/etc/letsencrypt/live/$domain/fullchain.pem" \
      -subj "/CN=localhost" 2>/dev/null
    echo "  Created placeholder cert for $domain"
  else
    echo "  Cert already exists for $domain, skipping placeholder"
  fi
done

# --------------------------------------------------------------------------
# 2. Download recommended TLS parameters (if not present)
# --------------------------------------------------------------------------
if [ ! -f "$DATA_PATH/options-ssl-nginx.conf" ] || [ ! -f "$DATA_PATH/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  docker run --rm \
    -v "lyria_certbot-conf:/etc/letsencrypt" \
    --entrypoint /bin/sh \
    certbot/certbot -c "
      curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
        > /etc/letsencrypt/options-ssl-nginx.conf
      curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
        > /etc/letsencrypt/ssl-dhparams.pem
    "
fi

# --------------------------------------------------------------------------
# 3. Start nginx (HTTP only initially — needs placeholder certs)
# --------------------------------------------------------------------------
echo "### Starting nginx ..."
cd /opt/lyria
docker compose up -d nginx
sleep 3

# --------------------------------------------------------------------------
# 4. Request real certificates from Let's Encrypt
# --------------------------------------------------------------------------
echo "### Requesting Let's Encrypt certificates ..."

STAGING_FLAG=""
if [ "$STAGING" = "1" ]; then
  STAGING_FLAG="--staging"
  echo "  (Running in staging mode)"
fi

DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do
  DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done

docker compose run --rm certbot \
  certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  $STAGING_FLAG \
  $DOMAIN_ARGS

# --------------------------------------------------------------------------
# 5. Reload nginx to pick up real certificates
# --------------------------------------------------------------------------
echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload

echo ""
echo "=== Done! SSL certificates obtained. ==="
echo "Now run: docker compose up -d"
echo "Certificates will auto-renew via the certbot container."
