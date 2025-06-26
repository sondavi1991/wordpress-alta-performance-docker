# Dockerfile para WordPress com PHP 8.2, LiteSpeed, OPcache, Redis
# Otimizado para máxima performance e segurança

# Imagem base com LiteSpeed e PHP 8.2
FROM litespeedtech/litespeed:6.1-lsphp82

# Definir variáveis de ambiente
ENV LSWS_VERSION=latest
ENV PHP_VERSION=lsphp82
ENV WORDPRESS_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive

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
    && rm -rf /var/lib/apt/lists/*

# Instalar extensões PHP necessárias para WordPress + Redis
RUN apt-get update && apt-get install -y --no-install-recommends \
    ${PHP_VERSION}-mysql \
    ${PHP_VERSION}-curl \
    ${PHP_VERSION}-gd \
    ${PHP_VERSION}-intl \
    ${PHP_VERSION}-mbstring \
    ${PHP_VERSION}-xml \
    ${PHP_VERSION}-zip \
    ${PHP_VERSION}-bcmath \
    ${PHP_VERSION}-imagick \
    ${PHP_VERSION}-opcache \
    ${PHP_VERSION}-redis \
    ${PHP_VERSION}-memcached \
    ${PHP_VERSION}-apcu \
    ${PHP_VERSION}-xdebug \
    ${PHP_VERSION}-soap \
    ${PHP_VERSION}-xmlrpc \
    ${PHP_VERSION}-imap \
    && rm -rf /var/lib/apt/lists/*

# Configurar PHP para WordPress com máxima performance
RUN echo "memory_limit = 512M" > /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "upload_max_filesize = 128M" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "post_max_size = 128M" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "max_execution_time = 600" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "max_input_time = 600" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "max_input_vars = 5000" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "date.timezone = America/Sao_Paulo" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "session.save_handler = redis" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini && \
    echo "session.save_path = 'tcp://redis:6379?auth=redis_secure_password'" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/wordpress.ini

# Configurar OPcache para máxima performance
RUN echo "opcache.enable=1" > /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=512" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.interned_strings_buffer=32" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=20000" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.revalidate_freq=0" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.fast_shutdown=1" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.enable_cli=1" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.save_comments=1" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini && \
    echo "opcache.enable_file_override=1" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/opcache.ini

# Configurar APCu para cache de objetos
RUN echo "apc.enabled=1" > /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/apcu.ini && \
    echo "apc.shm_size=256M" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/apcu.ini && \
    echo "apc.ttl=7200" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/apcu.ini && \
    echo "apc.enable_cli=1" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/apcu.ini

# Configurações de segurança PHP
RUN echo "expose_php = Off" > /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "display_errors = Off" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "log_errors = On" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "error_log = /var/log/php_errors.log" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "allow_url_fopen = Off" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "allow_url_include = Off" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini && \
    echo "disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source" >> /usr/local/lsws/${PHP_VERSION}/etc/php/8.2/litespeed/conf.d/security.ini

# Criar diretórios necessários
RUN mkdir -p /var/www/html && \
    mkdir -p /usr/local/lsws/conf/templates && \
    mkdir -p /usr/local/lsws/conf/vhosts/wordpress && \
    mkdir -p /etc/supervisor/conf.d && \
    mkdir -p /var/log && \
    mkdir -p /tmp/php-sessions && \
    chmod -R 777 /tmp/php-sessions

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

# Criar usuário admin do LiteSpeed (admin/123456)
RUN /usr/local/lsws/admin/misc/admpass.sh

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
