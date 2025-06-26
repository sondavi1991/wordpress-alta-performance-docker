# 🚀 WordPress Alta Performance com Docker

Stack completo WordPress + LiteSpeed + Redis + MySQL otimizado para máxima performance e pronto para produção.

## 🔑 Senhas Padrão (IMPORTANTE!)

**⚠️ ATENÇÃO: Estas são senhas padrão para desenvolvimento. SEMPRE altere em produção!**

| Serviço | Usuário | Senha | Acesso |
|---------|---------|-------|--------|
| **MySQL** | `wordpress` | `password123` | Banco de dados |
| **MySQL Root** | `root` | `password123` | Admin do banco |
| **Redis** | - | `password123` | Cache |
| **LiteSpeed Admin** | `admin` | `password123` | http://localhost:7080 |
| **phpMyAdmin** | `wordpress` | `password123` | http://localhost:8080 |

## 📦 Como usar no Coolify

1. **Fork ou clone** este repositório
2. **Configure no Coolify:**
   - Repository: `seu-usuario/wordpress-alta-performance-docker`
   - Branch: `main`
   - Build pack: `Dockerfile`

3. **Variáveis de ambiente** (opcionais - usa padrões se não definir):
```bash
# Banco de dados
MYSQL_ROOT_PASSWORD=sua_senha_root
MYSQL_PASSWORD=sua_senha_user
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress

# Redis
REDIS_PASSWORD=sua_senha_redis

# LiteSpeed
LSWS_ADMIN_PASS=sua_senha_admin

# WordPress
WP_TABLE_PREFIX=wpx_
```

4. **Deploy** - O Coolify irá construir e executar automaticamente!

## 🌟 Características

- ⚡ **LiteSpeed Web Server** - 3x mais rápido que Apache
- 🚀 **PHP 8.2** com OPcache + APCu
- 📊 **Redis** para cache de objetos e sessões
- 🗄️ **MySQL 8.0** otimizado
- 🔧 **phpMyAdmin** para gerenciamento
- 🛡️ **Proteção automática** de dados existentes
- 🔄 **Health checks** em todos os serviços
- 📈 **Monitoramento** integrado

## 🔧 Desenvolvimento Local

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/wordpress-alta-performance-docker.git
cd wordpress-alta-performance-docker

# Inicie os serviços
docker-compose up -d

# Acompanhe os logs
docker-compose logs -f wordpress
```

### 🌐 Acessos após o deploy:

- **WordPress**: http://localhost
- **LiteSpeed Admin**: http://localhost:7080 (admin/password)
- **phpMyAdmin**: http://localhost:8080
- **SSL**: https://localhost (certificado self-signed)

## 🛠️ Configurações Avançadas

### Alterar senhas em produção:

1. **No Coolify**, vá em Environment Variables
2. **Adicione as variáveis** com suas senhas seguras:
```bash
MYSQL_ROOT_PASSWORD=minha_senha_super_segura_mysql_root
MYSQL_PASSWORD=minha_senha_super_segura_mysql_user  
REDIS_PASSWORD=minha_senha_super_segura_redis
LSWS_ADMIN_PASS=minha_senha_super_segura_litespeed
```
3. **Redeploy** o container

### Performance para sites grandes:
```bash
# Adicione estas variáveis no Coolify para +100k visitas/mês
PHP_MEMORY_LIMIT=1024M
PHP_UPLOAD_MAX_SIZE=256M
```

## 🔍 Monitoramento

```bash
# Logs do WordPress
docker-compose logs -f wordpress

# Logs do MySQL  
docker-compose logs -f mysql

# Status dos serviços
docker-compose ps

# Uso de recursos
docker stats
```

## 🚨 Solução de Problemas

### Container em loop/erro de senha:
- Verifique se todas as senhas batem entre os serviços
- Use as senhas padrão primeiro, depois altere
- Verifique os logs: `docker-compose logs wordpress`

### Performance lenta:
- Aumente memória PHP: `PHP_MEMORY_LIMIT=1024M`
- Verifique Redis: `redis-cli -a password ping`
- Monitor recursos: `docker stats`

### Backup e Restore:
```bash
# Backup completo
./scripts/backup.sh

# Restore (se necessário)
./scripts/restore.sh backup-YYYYMMDD-HHMMSS.tar.gz
```

## 📈 Especificações Técnicas

| Componente | Versão | Configuração |
|------------|--------|--------------|
| **OS** | Ubuntu 24.04 | Base estável |
| **LiteSpeed** | Latest | OpenLiteSpeed |
| **PHP** | 8.2-FPM | 512M memory, OPcache |
| **MySQL** | 8.0 | InnoDB otimizado |
| **Redis** | 7-Alpine | 256MB cache |

## 🤝 Contribuições

Contribuições são bem-vindas! Por favor:

1. **Fork** o projeto
2. **Crie** uma branch para sua feature
3. **Commit** suas mudanças
4. **Push** para a branch
5. **Abra** um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para detalhes.

---

**💡 Dica:** Este stack é otimizado para sites WordPress de alta performance. Para projetos menores, considere usar apenas WordPress + MySQL.
