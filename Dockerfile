# Dockerfile para WordPress com PHP 8.2, LiteSpeed, OPcache, Redis
# Otimizado para máxima performance e segurança

# Usar imagem Ubuntu 24.04 como base e instalar LiteSpeed manualmente
FROM ubuntu:24.04

# Definir variáveis de ambiente
ENV DEBIAN_FRONTEND=noninteractive
ENV LSWS_VERSION=latest
ENV PHP_VERSION=8.2
ENV WORDPRESS_VERSION=latest

# Atualizar sistema e instalar dependências essenciais
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    zip \
    unzip \
    git \
    nano \
    supervisor \
    mysql-client \
    redis-tools \
    imagemagick \
    jpegoptim \
    optipng \
    pngquant \
    gifsicle \
    webp \
    htop \
    net-tools \
    iputils-ping \
    ca-certificates \
    gnupg2 \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Adicionar repositório LiteSpeed e instalar
RUN wget -O - https://repo.litespeed.sh | bash && \
    apt-get update && \
    apt-get install -y openlitespeed && \
    rm -rf /var/lib/apt/lists/*

# Instalar PHP 8.2 e extensões necessárias
RUN add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    php8.2 \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-curl \
    php8.2-gd \
    php8.2-intl \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-bcmath \
    php8.2-imagick \
    php8.2-opcache \
    php8.2-redis \
    php8.2-memcached \
    php8.2-apcu \
    php8.2-soap \
    php8.2-xmlrpc \
    php8.2-imap \
    php8.2-cli \
    php8.2-common \
    php8.2-dev \
    && rm -rf /var/lib/apt/lists/*

# Configurar PHP para WordPress com máxima performance
RUN echo "memory_limit = 512M" > /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "upload_max_filesize = 128M" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "post_max_size = 128M" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "max_execution_time = 600" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "max_input_time = 600" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "max_input_vars = 5000" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "date.timezone = America/Sao_Paulo" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "session.save_handler = redis" >> /etc/php/8.2/fpm/conf.d/wordpress.ini && \
    echo "session.save_path = 'tcp://redis:6379?auth=password123'" >> /etc/php/8.2/fpm/conf.d/wordpress.ini

# Copiar configurações para CLI também
RUN cp /etc/php/8.2/fpm/conf.d/wordpress.ini /etc/php/8.2/cli/conf.d/

# Configurar OPcache para máxima performance
RUN echo "opcache.enable=1" > /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=512" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.interned_strings_buffer=32" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=20000" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.revalidate_freq=0" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.fast_shutdown=1" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.enable_cli=1" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.save_comments=1" >> /etc/php/8.2/fpm/conf.d/opcache.ini && \
    echo "opcache.enable_file_override=1" >> /etc/php/8.2/fpm/conf.d/opcache.ini

# Copiar para CLI
RUN cp /etc/php/8.2/fpm/conf.d/opcache.ini /etc/php/8.2/cli/conf.d/

# Configurar APCu para cache de objetos
RUN echo "apc.enabled=1" > /etc/php/8.2/fpm/conf.d/apcu.ini && \
    echo "apc.shm_size=256M" >> /etc/php/8.2/fpm/conf.d/apcu.ini && \
    echo "apc.ttl=7200" >> /etc/php/8.2/fpm/conf.d/apcu.ini && \
    echo "apc.enable_cli=1" >> /etc/php/8.2/fpm/conf.d/apcu.ini

# Copiar para CLI
RUN cp /etc/php/8.2/fpm/conf.d/apcu.ini /etc/php/8.2/cli/conf.d/

# Configurações de segurança PHP
RUN echo "expose_php = Off" > /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "display_errors = Off" >> /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "log_errors = On" >> /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "error_log = /var/log/php_errors.log" >> /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "allow_url_fopen = Off" >> /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "allow_url_include = Off" >> /etc/php/8.2/fpm/conf.d/security.ini && \
    echo "disable_functions = exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source" >> /etc/php/8.2/fpm/conf.d/security.ini

# Copiar para CLI
RUN cp /etc/php/8.2/fpm/conf.d/security.ini /etc/php/8.2/cli/conf.d/

# Configurar PHP-FPM
RUN sed -i 's/listen = \/run\/php\/php8.2-fpm.sock/listen = 127.0.0.1:9000/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/;listen.owner = www-data/listen.owner = www-data/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/;listen.group = www-data/listen.group = www-data/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/user = www-data/user = nobody/' /etc/php/8.2/fpm/pool.d/www.conf && \
    sed -i 's/group = www-data/group = nogroup/' /etc/php/8.2/fpm/pool.d/www.conf

# Criar diretórios necessários
RUN mkdir -p /var/www/html && \
    mkdir -p /usr/local/lsws/conf/templates && \
    mkdir -p /usr/local/lsws/conf/vhosts/wordpress && \
    mkdir -p /etc/supervisor/conf.d && \
    mkdir -p /var/log && \
    mkdir -p /tmp/php-sessions && \
    chmod -R 777 /tmp/php-sessions && \
    mkdir -p /usr/local/lsws/admin/conf

# Configurar OpenLiteSpeed (sem configurar senha durante build)
RUN mkdir -p /usr/local/lsws/admin/conf

# Baixar e instalar WordPress
WORKDIR /var/www/html
RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rmdir wordpress && \
    rm latest.tar.gz

# Baixar WP-CLI para automação
RUN curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Instalar Redis Object Cache plugin
RUN curl -L https://downloads.wordpress.org/plugin/redis-cache.latest.zip -o redis-cache.zip && \
    unzip redis-cache.zip -d /var/www/html/wp-content/plugins/ && \
    rm redis-cache.zip

# Instalar LiteSpeed Cache plugin
RUN curl -L https://downloads.wordpress.org/plugin/litespeed-cache.latest.zip -o litespeed-cache.zip && \
    unzip litespeed-cache.zip -d /var/www/html/wp-content/plugins/ && \
    rm litespeed-cache.zip

# Configurar permissões corretas
RUN chown -R nobody:nogroup /var/www/html && \
    find /var/www/html -type f -exec chmod 644 {} \; && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    chmod 600 /var/www/html/wp-config-sample.php

# Copiar configurações do LiteSpeed
COPY litespeed/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY litespeed/conf/vhosts.conf /usr/local/lsws/conf/vhosts/wordpress/vhconf.conf

# Copiar configuração do supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Script de inicialização
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Script de backup automático
COPY scripts/backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

# Expor portas
EXPOSE 80 443 7080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Ponto de entrada
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
