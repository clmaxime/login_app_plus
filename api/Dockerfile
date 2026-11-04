FROM php:8.3-fpm-alpine
RUN php -r "exit(extension_loaded('pdo_sqlite') ? 0 : 1);"
WORKDIR /srv/api
COPY . .
RUN mkdir -p data && chown -R www-data:www-data data
USER www-data
