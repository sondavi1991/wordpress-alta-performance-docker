#!/bin/bash

# Script de Backup Automático - WordPress + MySQL + Redis
# Protege dados contra perda durante deploys

set -e

# Configurações
BACKUP_DIR="/var/www/html/wp-content/backup"
DATE=$(date +%Y%m%d_%H%M%S)
MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_USER=${MYSQL_USER:-wordpress}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-wordpress_secure_password}
MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PASSWORD=${REDIS_PASSWORD:-redis_secure_password}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Função de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] BACKUP: $1"
}

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Função para backup do MySQL
backup_mysql() {
    log "Iniciando backup do MySQL..."
    
    local backup_file="$BACKUP_DIR/mysql_backup_$DATE.sql.gz"
    
    if mysqldump -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --databases "$MYSQL_DATABASE" | gzip > "$backup_file"; then
        
        log "✅ Backup MySQL criado: $(basename $backup_file)"
        echo "$backup_file"
    else
        log "❌ ERRO: Falha no backup do MySQL"
        return 1
    fi
}

# Função para backup do Redis
backup_redis() {
    if [ ! -z "$REDIS_HOST" ]; then
        log "Iniciando backup do Redis..."
        
        local backup_file="$BACKUP_DIR/redis_backup_$DATE.rdb"
        
        if redis-cli -h "$REDIS_HOST" -a "$REDIS_PASSWORD" --rdb "$backup_file" >/dev/null 2>&1; then
            log "✅ Backup Redis criado: $(basename $backup_file)"
            echo "$backup_file"
        else
            log "⚠️ Warning: Falha no backup do Redis (não crítico)"
        fi
    fi
}

# Função para backup dos arquivos WordPress
backup_wordpress_files() {
    log "Iniciando backup dos arquivos WordPress..."
    
    local backup_file="$BACKUP_DIR/wordpress_files_$DATE.tar.gz"
    local temp_dir="/tmp/wp_backup_$DATE"
    
    mkdir -p "$temp_dir"
    
    # Copiar arquivos importantes, excluindo cache e temporários
    tar -czf "$backup_file" \
        --exclude="$BACKUP_DIR" \
        --exclude="wp-content/cache" \
        --exclude="wp-content/temp" \
        --exclude="wp-content/backup" \
        --exclude="wp-content/uploads/cache" \
        --exclude="*.log" \
        -C "/var/www/html" \
        wp-content/themes \
        wp-content/plugins \
        wp-content/uploads \
        wp-config.php \
        .htaccess 2>/dev/null || true
    
    if [ -f "$backup_file" ]; then
        log "✅ Backup arquivos criado: $(basename $backup_file) ($(du -h $backup_file | cut -f1))"
        echo "$backup_file"
    else
        log "❌ ERRO: Falha no backup dos arquivos"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# Função para limpeza de backups antigos
cleanup_old_backups() {
    log "Limpando backups antigos (>$RETENTION_DAYS dias)..."
    
    local deleted_count=0
    
    # Remover backups antigos
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete && deleted_count=$((deleted_count + $(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS | wc -l)))
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete && deleted_count=$((deleted_count + $(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS | wc -l)))
    find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete && deleted_count=$((deleted_count + $(find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS | wc -l)))
    
    if [ $deleted_count -gt 0 ]; then
        log "🗑️ Removidos $deleted_count backups antigos"
    else
        log "ℹ️ Nenhum backup antigo para remover"
    fi
}

# Função para verificar espaço em disco
check_disk_space() {
    local available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    local required_space=1048576  # 1GB em KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log "⚠️ WARNING: Pouco espaço em disco disponível ($available_space KB)"
        return 1
    fi
    
    log "✅ Espaço em disco suficiente ($(($available_space / 1024))MB disponível)"
}

# Função para criar resumo do backup
create_backup_summary() {
    local summary_file="$BACKUP_DIR/backup_summary_$DATE.txt"
    
    cat > "$summary_file" << EOF
RESUMO DO BACKUP - $DATE
====================================

Data/Hora: $(date)
Sistema: $(uname -a)
Usuário: $(whoami)

ARQUIVOS CRIADOS:
EOF

    # Listar backups criados
    find "$BACKUP_DIR" -name "*$DATE*" -exec ls -lh {} \; >> "$summary_file"
    
    cat >> "$summary_file" << EOF

VERIFICAÇÃO DE INTEGRIDADE:
EOF

    # Verificar integridade dos arquivos
    find "$BACKUP_DIR" -name "*$DATE*.gz" -exec gzip -t {} \; && echo "✅ Arquivos comprimidos íntegros" >> "$summary_file" || echo "❌ Problemas na integridade" >> "$summary_file"
    
    log "📋 Resumo criado: $(basename $summary_file)"
}

# Função principal
main() {
    log "🚀 Iniciando processo de backup automático..."
    
    # Verificações iniciais
    if ! check_disk_space; then
        log "❌ ERRO: Espaço insuficiente para backup"
        exit 1
    fi
    
    # Executar backups
    local mysql_backup=""
    local redis_backup=""
    local files_backup=""
    
    # Backup MySQL (crítico)
    if mysql_backup=$(backup_mysql); then
        log "MySQL backup: OK"
    else
        log "❌ ERRO CRÍTICO: Falha no backup MySQL"
        exit 1
    fi
    
    # Backup Redis (não crítico)
    redis_backup=$(backup_redis) || true
    
    # Backup arquivos WordPress (crítico)
    if files_backup=$(backup_wordpress_files); then
        log "WordPress files backup: OK"
    else
        log "❌ ERRO CRÍTICO: Falha no backup dos arquivos"
        exit 1
    fi
    
    # Criar resumo
    create_backup_summary
    
    # Limpeza
    cleanup_old_backups
    
    # Relatório final
    local total_backups=$(find "$BACKUP_DIR" -name "*$DATE*" | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    log "✅ Backup concluído com sucesso!"
    log "📊 Total de arquivos criados: $total_backups"
    log "💾 Tamanho total do backup: $total_size"
    log "📁 Local: $BACKUP_DIR"
}

# Verificar se é execução manual ou via cron
if [ "$1" = "--manual" ]; then
    log "Execução manual solicitada"
    main
elif [ "$1" = "--cron" ]; then
    # Executar apenas se habilitado
    if [ "${BACKUP_ENABLED:-true}" = "true" ]; then
        main
    else
        log "Backup desabilitado via BACKUP_ENABLED=false"
    fi
else
    # Execução padrão
    main
fi 