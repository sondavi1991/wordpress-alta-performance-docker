#!/bin/bash
set -e

# Função para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Função para verificar se banco já existe e tem dados
check_database_protection() {
    local db_exists=false
    local has_data=false
    
    if [ ! -z "$MYSQL_HOST" ] && [ ! -z "$MYSQL_DATABASE" ]; then
        log "Verificando proteção de dados do banco..."
        
        # Aguardar banco estar disponível
        for i in {1..30}; do
            if mysqladmin ping -h"$MYSQL_HOST" -u"${MYSQL_USER:-wordpress}" -p"${MYSQL_PASSWORD:-wordpress_secure_password}" --silent 2>/dev/null; then
                break
            fi
            
            if [ $i -eq 30 ]; then
                log "WARNING: Banco de dados não disponível após 30 tentativas"
                return 1
            fi
            
            log "Aguardando banco de dados... (tentativa $i/30)"
            sleep 2
        done
        
        # Verificar se banco existe
        if mysql -h"$MYSQL_HOST" -u"${MYSQL_USER:-wordpress}" -p"${MYSQL_PASSWORD:-wordpress_secure_password}" -e "USE ${MYSQL_DATABASE}" 2>/dev/null; then
            db_exists=true
            log "✅ Banco de dados '${MYSQL_DATABASE}' já existe"
            
            # Verificar se tem dados (tabelas WordPress)
            local table_count=$(mysql -h"$MYSQL_HOST" -u"${MYSQL_USER:-wordpress}" -p"${MYSQL_PASSWORD:-wordpress_secure_password}" -D"${MYSQL_DATABASE}" -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${MYSQL_DATABASE}' AND table_name LIKE '${WORDPRESS_TABLE_PREFIX:-wpx_}%';" 2>/dev/null || echo "0")
            
            if [ "$table_count" -gt 0 ]; then
                has_data=true
                log "✅ Encontradas $table_count tabelas WordPress existentes"
                log "🛡️ PROTEÇÃO ATIVADA: Dados existentes detectados - pulando configuração inicial"
            fi
        else
            log "ℹ️ Banco de dados '${MYSQL_DATABASE}' não existe ou está vazio"
        fi
    fi
    
    # Definir variáveis globais
    export DB_EXISTS=$db_exists
    export HAS_DATA=$has_data
}

# Configurar LiteSpeed
configure_litespeed() {
    log "Configurando LiteSpeed..."
    
    # Criar diretórios necessários
    mkdir -p /usr/local/lsws/logs/vhosts/wordpress
    mkdir -p /usr/local/lsws/conf/vhosts/wordpress
    mkdir -p /tmp/lshttpd/cache
    mkdir -p /tmp/lshttpd/swap
    mkdir -p /usr/local/lsws/Example/html/blocked
    
    # Definir permissões corretas
    chown -R lsws:lsws /usr/local/lsws/logs 2>/dev/null || true
    chown -R lsws:lsws /tmp/lshttpd 2>/dev/null || true
    chmod -R 755 /usr/local/lsws/logs
    chmod -R 755 /tmp/lshttpd
    
    # Gerar certificado SSL self-signed se não existir
    if [ ! -f "/usr/local/lsws/conf/cert/server.crt" ]; then
        log "Gerando certificado SSL self-signed..."
        mkdir -p /usr/local/lsws/conf/cert
        openssl req -x509 -newkey rsa:4096 -keyout /usr/local/lsws/conf/cert/server.key \
            -out /usr/local/lsws/conf/cert/server.crt -days 365 -nodes \
            -subj "/C=BR/ST=SP/L=Sao Paulo/O=WordPress/CN=${DOMAIN:-localhost}"
        chown lsws:lsws /usr/local/lsws/conf/cert/* 2>/dev/null || true
        chmod 600 /usr/local/lsws/conf/cert/server.key
        chmod 644 /usr/local/lsws/conf/cert/server.crt
    fi
    
    # Configurar página de manutenção
    cat > /usr/local/lsws/Example/html/blocked/index.html << 'EOF'
<!DOCTYPE html>
<html><head><title>Site em Manutenção</title></head>
<body style="font-family:Arial;text-align:center;padding:50px;">
<h1>Site em Manutenção</h1>
<p>Este site está temporariamente indisponível. Tente novamente em alguns minutos.</p>
</body></html>
EOF
}

# Configurar Redis
configure_redis() {
    if [ ! -z "$REDIS_HOST" ]; then
        log "Configurando conexão Redis..."
        
        # Aguardar Redis estar disponível
        for i in {1..30}; do
            if redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" -a "${REDIS_PASSWORD:-redis_secure_password}" ping >/dev/null 2>&1; then
                log "✅ Redis conectado com sucesso!"
                break
            fi
            
            if [ $i -eq 30 ]; then
                log "WARNING: Redis não disponível após 30 tentativas"
                return 1
            fi
            
            log "Aguardando Redis... (tentativa $i/30)"
            sleep 2
        done
        
        # Testar configuração Redis
        redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" -a "${REDIS_PASSWORD:-redis_secure_password}" set test_key "test_value" >/dev/null 2>&1
        local test_result=$(redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" -a "${REDIS_PASSWORD:-redis_secure_password}" get test_key 2>/dev/null)
        
        if [ "$test_result" = "test_value" ]; then
            log "✅ Redis funcionando corretamente"
            redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" -a "${REDIS_PASSWORD:-redis_secure_password}" del test_key >/dev/null 2>&1
        else
            log "❌ ERRO: Redis não está funcionando corretamente"
            return 1
        fi
    fi
}

# Configurar WordPress
configure_wordpress() {
    log "Verificando configuração do WordPress..."
    
    # Se já tem dados, não reconfigurar
    if [ "$HAS_DATA" = true ]; then
        log "🛡️ Dados existentes detectados - pulando configuração inicial do WordPress"
        # Apenas garantir permissões corretas
        chown -R nobody:nogroup /var/www/html
        find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true
        find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
        chmod 600 /var/www/html/wp-config.php 2>/dev/null || true
        return 0
    fi
    
    if [ ! -f "/var/www/html/wp-config.php" ]; then
        log "Configurando WordPress pela primeira vez..."
        cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
        
        # Configurar conexão com banco de dados
        sed -i "s/database_name_here/${MYSQL_DATABASE:-wordpress}/g" /var/www/html/wp-config.php
        sed -i "s/username_here/${MYSQL_USER:-wordpress}/g" /var/www/html/wp-config.php
        sed -i "s/password_here/${MYSQL_PASSWORD:-wordpress_secure_password}/g" /var/www/html/wp-config.php
        sed -i "s/localhost/${MYSQL_HOST:-mysql}/g" /var/www/html/wp-config.php
        
        # Configurar prefixo da tabela
        sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '${WORDPRESS_TABLE_PREFIX:-wpx_}';/g" /var/www/html/wp-config.php
        
        # Adicionar configurações Redis se disponível
        if [ ! -z "$REDIS_HOST" ]; then
            cat >> /var/www/html/wp-config.php << EOF

/* Configurações Redis Object Cache */
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT:-6379});
define('WP_REDIS_PASSWORD', '${REDIS_PASSWORD:-redis_secure_password}');
define('WP_REDIS_DATABASE', ${REDIS_DB:-0});
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);
define('WP_REDIS_MAXTTL', 86400);
define('WP_REDIS_GLOBAL_GROUPS', array('users', 'userlogins', 'usermeta', 'user_meta', 'useremail', 'userslugs', 'site-transient', 'site-options', 'blog-lookup', 'blog-details', 'rss', 'global-posts', 'blog-id-cache', 'networks', 'sites', 'site-details'));
define('WP_REDIS_IGNORED_GROUPS', array('counts', 'plugins'));
EOF
        fi
        
        # Adicionar configurações extras de segurança e performance
        cat >> /var/www/html/wp-config.php << 'EOF'

/* Configurações de segurança avançadas */
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);
define('AUTOMATIC_UPDATER_DISABLED', false);
define('WP_AUTO_UPDATE_CORE', true);
define('FORCE_SSL_ADMIN', true);
define('COOKIE_DOMAIN', '');
define('COOKIEHASH', '');

/* Configurações de performance */
define('WP_CACHE', true);
define('COMPRESS_CSS', true);
define('COMPRESS_SCRIPTS', true);
define('CONCATENATE_SCRIPTS', false);
define('ENFORCE_GZIP', true);
define('WP_MEMORY_LIMIT', '512M');

/* Configurações de upload */
ini_set('upload_max_size', '128M');
ini_set('post_max_size', '128M');
ini_set('max_execution_time', 600);
ini_set('max_input_vars', 5000);

/* Configurações de sessão Redis */
ini_set('session.save_handler', 'redis');
ini_set('session.save_path', 'tcp://redis:6379?auth=redis_secure_password');

/* Configurações de banco de dados */
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

/* Configurações de backup automático */
define('WP_BACKUP_DIR', '/var/www/html/wp-content/backup/');
define('BACKUP_IGNORE_FILETYPES', 'jpg,jpeg,png,gif,bmp,pdf,doc,docx,xls,xlsx');
EOF
        
        # Gerar chaves de segurança do WordPress
        log "Gerando chaves de segurança..."
        SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/ 2>/dev/null || echo "")
        if [ ! -z "$SALT" ]; then
            # Remove as linhas de salt padrão e adiciona as novas
            sed -i '/AUTH_KEY\|SECURE_AUTH_KEY\|LOGGED_IN_KEY\|NONCE_KEY\|AUTH_SALT\|SECURE_AUTH_SALT\|LOGGED_IN_SALT\|NONCE_SALT/d' /var/www/html/wp-config.php
            echo "$SALT" >> /var/www/html/wp-config.php
        fi
        
        # Configurar diretório de backup
        mkdir -p /var/www/html/wp-content/backup
        
        # Definir permissões corretas
        chown -R nobody:nogroup /var/www/html
        find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true
        find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
        chmod 600 /var/www/html/wp-config.php
        chmod 755 /var/www/html/wp-content/backup
        
        log "✅ WordPress configurado com sucesso!"
    else
        log "WordPress já está configurado."
    fi
    
    # Garantir permissões corretas sempre
    chown -R nobody:nogroup /var/www/html
    find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
    chmod 600 /var/www/html/wp-config.php 2>/dev/null || true
}

# Configurar plugins automaticamente
configure_plugins() {
    if [ "$HAS_DATA" = false ] && [ ! -z "$REDIS_HOST" ]; then
        log "Ativando plugins de cache..."
        
        # Aguardar WordPress estar disponível
        sleep 10
        
        # Ativar Redis Object Cache plugin via WP-CLI
        cd /var/www/html
        /usr/local/bin/wp plugin activate redis-cache --allow-root --quiet 2>/dev/null || true
        /usr/local/bin/wp redis enable --allow-root --quiet 2>/dev/null || true
        
        # Ativar LiteSpeed Cache plugin
        /usr/local/bin/wp plugin activate litespeed-cache --allow-root --quiet 2>/dev/null || true
        
        log "✅ Plugins de cache ativados"
    fi
}

# Função principal
main() {
    log "=== Iniciando configuração do container WordPress com Redis ==="
    
    # Verificar proteção de dados
    check_database_protection
    
    # Configurar LiteSpeed
    configure_litespeed
    
    # Configurar Redis
    configure_redis
    
    # Configurar WordPress
    configure_wordpress
    
    # Configurar plugins (apenas se não tem dados)
    configure_plugins &
    
    # Criar diretórios de log do supervisor
    mkdir -p /var/log/supervisor
    
    log "=== Configuração concluída! ==="
    log "WordPress: http://localhost"
    log "LiteSpeed Admin: http://localhost:7080 (admin/123456)"
    log "phpMyAdmin: http://localhost:8080"
    if [ ! -z "$REDIS_HOST" ]; then
        log "Redis: Configurado e funcionando"
    fi
    
    if [ "$HAS_DATA" = true ]; then
        log "🛡️ DADOS PROTEGIDOS: Configuração existente preservada"
    fi
    
    # Executar comando fornecido
    exec "$@"
}

# Executar função principal
main "$@"
