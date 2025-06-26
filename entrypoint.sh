#!/bin/bash

# Script de inicialização para WordPress com LiteSpeed
# Autor: Sistema de Deploy Automatizado
# Data: 2025

set -e

# Cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

log "🚀 Iniciando container WordPress com LiteSpeed..."

# Verificar se é uma instalação existente
check_database_protection() {
    if [[ -n "${MYSQL_HOST}" && -n "${MYSQL_USER}" && -n "${MYSQL_PASSWORD}" && -n "${MYSQL_DATABASE}" ]]; then
        log "🔍 Verificando proteção de dados existentes..."
        
        # Tentar conectar ao MySQL e verificar se existem tabelas
        if mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD:-password123}" "${MYSQL_DATABASE}" -e "SHOW TABLES;" 2>/dev/null | grep -q "wp_\|wpx_"; then
            warn "⚠️  DADOS EXISTENTES DETECTADOS!"
            warn "⚠️  Tabelas WordPress encontradas no banco de dados"
            warn "⚠️  Pulando configuração inicial para proteger dados existentes"
            return 1
        else
            info "✅ Banco de dados vazio ou sem tabelas WordPress - configuração segura"
            return 0
        fi
    else
        warn "⚠️  Variáveis de banco não definidas - assumindo primeira instalação"
        return 0
    fi
}

# Configurar wp-config.php apenas se necessário
configure_wordpress() {
    if [[ ! -f "/var/www/html/wp-config.php" ]] && check_database_protection; then
        log "📝 Configurando wp-config.php..."
        
        # Copiar template se não existir
        if [[ ! -f "/var/www/html/wp-config.php" ]]; then
            cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
        fi
        
        # Configurar banco de dados
        sed -i "s/database_name_here/${MYSQL_DATABASE:-wordpress}/" /var/www/html/wp-config.php
        sed -i "s/username_here/${MYSQL_USER:-wordpress}/" /var/www/html/wp-config.php
        sed -i "s/password_here/${MYSQL_PASSWORD:-password123}/" /var/www/html/wp-config.php
        sed -i "s/localhost/${MYSQL_HOST:-mysql}/" /var/www/html/wp-config.php
        
        # Configurar prefixo personalizado
        sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '${WP_TABLE_PREFIX:-wpx_}';/" /var/www/html/wp-config.php
        
        # Gerar salt keys únicos
        SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
        if [[ -n "$SALT" ]]; then
            # Remover as linhas de salt existentes
            sed -i '/AUTH_KEY/d' /var/www/html/wp-config.php
            sed -i '/SECURE_AUTH_KEY/d' /var/www/html/wp-config.php
            sed -i '/LOGGED_IN_KEY/d' /var/www/html/wp-config.php
            sed -i '/NONCE_KEY/d' /var/www/html/wp-config.php
            sed -i '/AUTH_SALT/d' /var/www/html/wp-config.php
            sed -i '/SECURE_AUTH_SALT/d' /var/www/html/wp-config.php
            sed -i '/LOGGED_IN_SALT/d' /var/www/html/wp-config.php
            sed -i '/NONCE_SALT/d' /var/www/html/wp-config.php
            
            # Adicionar novas salt keys
            sed -i "/\$table_prefix/i\\$SALT" /var/www/html/wp-config.php
        fi
        
        # Configurações de Redis
        cat >> /var/www/html/wp-config.php << 'EOF'

// Redis Configuration
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_REDIS_PASSWORD', 'password123');
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);

// Cache Configuration
define('WP_CACHE', true);
define('FORCE_SSL_ADMIN', false);

// Debug Configuration (disable in production)
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);

// Security
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);
define('FORCE_SSL_ADMIN', false);

// Performance
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Auto-updates
define('WP_AUTO_UPDATE_CORE', true);
define('AUTOMATIC_UPDATER_DISABLED', false);

EOF
        
        log "✅ wp-config.php configurado com sucesso!"
    else
        info "📋 wp-config.php já existe ou dados protegidos - pulando configuração"
    fi
}

# Testar conexão Redis
test_redis_connection() {
    log "🔗 Testando conexão com Redis..."
    
    # Aguardar Redis estar disponível
    local retry_count=0
    local max_retries=30
    
    while [[ $retry_count -lt $max_retries ]]; do
        if redis-cli -h redis -p 6379 -a "${REDIS_PASSWORD:-password123}" ping > /dev/null 2>&1; then
            log "✅ Redis conectado com sucesso!"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        warn "⏳ Aguardando Redis... (tentativa $retry_count/$max_retries)"
        sleep 2
    done
    
    error "❌ Falha ao conectar com Redis após $max_retries tentativas"
    return 1
}

# Aguardar MySQL estar disponível
wait_for_mysql() {
    if [[ -n "${MYSQL_HOST}" ]]; then
        log "🔗 Aguardando MySQL estar disponível..."
        
        local retry_count=0
        local max_retries=30
        
        while [[ $retry_count -lt $max_retries ]]; do
            if mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER:-wordpress}" -p"${MYSQL_PASSWORD:-password123}" -e "SELECT 1" > /dev/null 2>&1; then
                log "✅ MySQL conectado com sucesso!"
                return 0
            fi
            
            retry_count=$((retry_count + 1))
            warn "⏳ Aguardando MySQL... (tentativa $retry_count/$max_retries)"
            sleep 2
        done
        
        error "❌ Falha ao conectar com MySQL após $max_retries tentativas"
        return 1
    fi
}

# Ativar plugins essenciais
activate_plugins() {
    if [[ -f "/var/www/html/wp-config.php" ]] && check_database_protection; then
        log "🔌 Ativando plugins essenciais..."
        
        cd /var/www/html
        
        # Aguardar WordPress estar acessível
        local retry_count=0
        while [[ $retry_count -lt 10 ]]; do
            if wp core is-installed --allow-root 2>/dev/null; then
                break
            fi
            retry_count=$((retry_count + 1))
            sleep 3
        done
        
        # Ativar Redis Object Cache
        if wp plugin is-installed redis-cache --allow-root 2>/dev/null; then
            wp plugin activate redis-cache --allow-root 2>/dev/null || true
            wp redis enable --allow-root 2>/dev/null || true
            log "✅ Redis Object Cache ativado"
        fi
        
        # Ativar LiteSpeed Cache
        if wp plugin is-installed litespeed-cache --allow-root 2>/dev/null; then
            wp plugin activate litespeed-cache --allow-root 2>/dev/null || true
            log "✅ LiteSpeed Cache ativado"
        fi
    else
        info "⏭️  Pulando ativação de plugins - proteção de dados ativa"
    fi
}

# Configurar permissões
setup_permissions() {
    log "🔒 Configurando permissões de arquivos..."
    
    # Definir ownership correto
    chown -R nobody:nogroup /var/www/html
    
    # Permissões de arquivos
    find /var/www/html -type f -exec chmod 644 {} \;
    find /var/www/html -type d -exec chmod 755 {} \;
    
    # wp-config.php deve ser mais restrito
    if [[ -f "/var/www/html/wp-config.php" ]]; then
        chmod 600 /var/www/html/wp-config.php
    fi
    
    # .htaccess precisa ser writeable para plugins de cache
    if [[ -f "/var/www/html/.htaccess" ]]; then
        chmod 666 /var/www/html/.htaccess
    fi
    
    log "✅ Permissões configuradas"
}

# Configurar LiteSpeed
setup_litespeed() {
    log "⚡ Configurando LiteSpeed..."
    
    # Definir senha do admin se não existir
    if [[ -n "${LSWS_ADMIN_PASS}" ]]; then
        echo "admin:${LSWS_ADMIN_PASS:-password123}" | /usr/local/lsws/admin/misc/admpass.sh
        log "✅ Senha do admin LiteSpeed definida"
    else
        echo "admin:password123" | /usr/local/lsws/admin/misc/admpass.sh
        log "✅ Senha padrão do admin LiteSpeed definida (admin/password123)"
    fi
    
    # Copiar configurações se não existirem
    if [[ ! -f "/usr/local/lsws/conf/httpd_config.conf" ]]; then
        warn "⚠️  Arquivo de configuração LiteSpeed não encontrado, usando padrão"
    fi
    
    log "✅ LiteSpeed configurado"
}

# Função principal
main() {
    log "🌟 === WORDPRESS ALTA PERFORMANCE - LITESPEED ===" 
    log "🚀 Versão: 2.0.0"
    log "📦 Stack: Ubuntu 24.04 + LiteSpeed + PHP 8.2 + Redis + MySQL"
    log "🔧 Deploy: Coolify Ready"
    log "🔑 Senhas padrão: password123 (TROQUE EM PRODUÇÃO!)"
    
    # Aguardar dependências
    wait_for_mysql
    test_redis_connection
    
    # Configurar componentes
    setup_litespeed
    configure_wordpress
    setup_permissions
    
    # Ativar plugins em background para não bloquear
    (sleep 30 && activate_plugins) &
    
    log "🎉 Inicialização concluída!"
    log "🌐 WordPress disponível em: http://localhost"
    log "🔧 Admin LiteSpeed: http://localhost:7080 (admin/password123)"
    log "📊 phpMyAdmin: http://localhost:8080"
    log "📈 Use 'docker-compose logs -f wordpress' para monitorar"
    
    # Executar comando passado como argumento
    exec "$@"
}

# Capturar sinais para shutdown graceful
trap 'log "🛑 Recebido sinal de parada..."; exit 0' SIGTERM SIGINT

# Executar função principal
main "$@"
