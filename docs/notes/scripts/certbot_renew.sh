certbot renew --manual --preferred-challenges dns --manual-auth-hook "alidns" --manual-cleanup-hook "alidns clean"
cp /etc/letsencrypt/live/blbl.top/fullchain.pem /opt/1panel/apps/openresty/openresty/www/sites/blbl.top/fullchain.pem
cp /etc/letsencrypt/live/blbl.top/privkey.pem /opt/1panel/apps/openresty/openresty/www/sites/blbl.top/privkey.pem