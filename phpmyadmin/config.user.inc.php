<?php
/**
 * Configuração de segurança phpMyAdmin para WordPress
 * Configurações adicionais de segurança e performance
 */

// Configurações de segurança
$cfg['LoginCookieValidity'] = 3600; // 1 hora
$cfg['LoginCookieStore'] = 0;
$cfg['LoginCookieDeleteAll'] = true;

// Ocultar informações sensíveis
$cfg['Servers'][$i]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';
$cfg['ShowServerInfo'] = false;
$cfg['ShowPhpInfo'] = false;
$cfg['ShowCreateDb'] = false;

// Configurações de upload e import
$cfg['UploadDir'] = '/tmp/';
$cfg['SaveDir'] = '/tmp/';
$cfg['MaxFileUploads'] = 20;
$cfg['MemoryLimit'] = '512M';
$cfg['ExecTimeLimit'] = 600;

// Configurações de interface
$cfg['NavigationTreePointerEnable'] = true;
$cfg['BrowsePointerEnable'] = true;
$cfg['BrowseMarkerEnable'] = true;
$cfg['TextareaRows'] = 20;
$cfg['TextareaCols'] = 80;
$cfg['LimitChars'] = 100;
$cfg['RowActionLinks'] = 'left';

// Configurações de export
$cfg['Export']['method'] = 'quick';
$cfg['Export']['format'] = 'sql';
$cfg['Export']['compression'] = 'gzip';
$cfg['Export']['charset'] = 'utf-8';

// Configurações específicas para WordPress
$cfg['DefaultTabDatabase'] = 'structure';
$cfg['DefaultTabTable'] = 'browse';
$cfg['ShowStats'] = false;
$cfg['ShowServerInfo'] = false;

// Configurações de segurança avançadas
$cfg['AllowThirdPartyFraming'] = false;
$cfg['CSPAllow'] = '';

// Configurações de tema
$cfg['ThemeDefault'] = 'pmahomme';
$cfg['FontSize'] = '82%';

// Configurações de backup automático
$cfg['Export']['quick_export_onserver'] = true;
$cfg['Export']['quick_export_onserver_overwrite'] = true;

// Configurações de timeout
$cfg['LoginCookieRecall'] = false;
$cfg['LoginCookieValidity'] = 3600;

// Desabilitar recursos desnecessários
$cfg['ShowChgPassword'] = false;
$cfg['ShowCreateDb'] = false;
$cfg['SuhosinDisableWarning'] = true;

// Configurações de log
$cfg['Error_Handler']['display'] = false;
$cfg['Error_Handler']['gather'] = false;

// Configurações específicas para produção
if (isset($_ENV['ENVIRONMENT']) && $_ENV['ENVIRONMENT'] === 'production') {
    $cfg['ShowPhpInfo'] = false;
    $cfg['ShowServerInfo'] = false;
    $cfg['ShowStats'] = false;
    $cfg['Error_Handler']['display'] = false;
}

// Configurações de cache
$cfg['OBGzip'] = 'auto';
$cfg['PersistentConnections'] = true;

// Configurações de charset para WordPress
$cfg['DefaultCharset'] = 'utf8mb4';
$cfg['RecodingEngine'] = 'auto';
$cfg['IconvExtraParams'] = '//TRANSLIT';

// Configurações de tabelas para WordPress
$cfg['DefaultTabTable'] = 'browse';
$cfg['NumRowsInsert'] = 2;
$cfg['ForeignKeyMaxLimit'] = 100;

// Configurações de SQL para WordPress
$cfg['SQLQuery']['Edit'] = true;
$cfg['SQLQuery']['Explain'] = true;
$cfg['SQLQuery']['ShowAsPHP'] = true;
$cfg['SQLQuery']['Validate'] = false;
$cfg['SQLQuery']['Refresh'] = true;

?> 