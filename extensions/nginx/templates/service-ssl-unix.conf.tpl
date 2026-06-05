server {
    listen unix:/dev/shm/nginx.sock ssl http2 proxy_protocol;
    listen unix:/dev/shm/nginxTLS.sock proxy_protocol;
    listen unix:/dev/shm/nginx_h2.sock http2 proxy_protocol;
    server_name ${SERVICE_DOMAIN};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    ssl_certificate     /etc/letsencrypt/live/${SERVICE_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${SERVICE_DOMAIN}/privkey.pem;

    location / {
        proxy_pass ${SERVICE_UPSTREAM};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # WEBSOCKET_DIRECTIVES
    }
}
