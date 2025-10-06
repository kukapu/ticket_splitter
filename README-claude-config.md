# Claude Code Configuration Manager

Utilidad para cambiar fácilmente entre diferentes métodos de autenticación en Claude Code (extensión de VS Code).

## 🚀 Instalación

### Instalación rápida con alias global:
```bash
./install-claude-manager.sh
source ~/.bashrc  # o ~/.zshrc si usas zsh
```

Después de la instalación podrás usar `ccode` desde cualquier lugar.

### Uso directo:
```bash
./claude-config-manager.sh [comando]
```

## 📋 Comandos Disponibles

### Ver estado actual
```bash
ccode status
```
Muestra:
- Método de autenticación actual
- API Key (parcialmente oculta si está configurada)
- Información de backup disponible

### Configurar con API Key
```bash
# Te pedirá la API Key de forma segura
ccode apikey

# O proporcionarla directamente
ccode apikey sk-ant-api03-tu-key-aqui
```

### Configurar con login OAuth
```bash
ccode login
```
Remueve la API Key y configura para usar login OAuth (método por defecto).

### Gestión de backups
```bash
# Crear backup manual
ccode backup

# Restaurar desde backup
ccode restore
```

### Ayuda
```bash
ccode help
```

## 📁 Archivos del Sistema

### Scripts principales:
- `claude-config-manager.sh` - Script principal
- `claude-config-apikey.sh` - Configuración para API Key
- `claude-config-login.sh` - Configuración para login OAuth
- `install-claude-manager.sh` - Instalador de alias

### Archivos de configuración:
- `~/.config/Code/User/settings.json` - Configuración de VS Code
- `~/.config/Code/User/settings.json.backup` - Backup automático

## 🔧 Configuraciones que se Modifican

### Para API Key:
```json
{
  "anthropic.apiKey": "tu-api-key",
  "anthropic.auth.method": "apiKey",
  "claude-code.anthropic.apiKey": "tu-api-key",
  "claude-code.authentication.method": "apiKey"
}
```

### Para Login OAuth:
```json
{
  "anthropic.auth.method": "oauth",
  "claude-code.authentication.method": "oauth"
}
```

## 🛡️ Seguridad

- Las API Keys se solicitan de forma segura (no aparecen en la terminal)
- Se crean backups automáticos antes de cualquier cambio
- Se valida la sintaxis JSON antes de aplicar cambios
- Las API Keys se muestran parcialmente ocultas en el status

## 📖 Ejemplos de Uso

### Cambiar de login a API Key:
```bash
# Ver estado actual
ccode status

# Cambiar a API Key
ccode apikey
# (introducir tu API Key cuando se solicite)

# Verificar el cambio
ccode status

# Reiniciar VS Code para aplicar cambios
```

### Volver al login OAuth:
```bash
# Cambiar a OAuth
ccode login

# Verificar el cambio
ccode status

# Reiniciar VS Code
```

### Recuperar configuración anterior:
```bash
# Si algo sale mal, restaurar backup
ccode restore
```

## ⚠️ Notas Importantes

1. **Reinicia VS Code** después de cualquier cambio para que se aplique
2. Los backups se crean automáticamente antes de cualquier modificación
3. Si usas API Key, asegúrate de tener créditos disponibles en tu cuenta Anthropic
4. El script requiere `jq` para manipular JSON (ya instalado en tu sistema)

## 🔍 Resolución de Problemas

### Error: "jq no encontrado"
```bash
sudo pacman -S jq
```

### La configuración no se aplica
- Asegúrate de reiniciar VS Code completamente
- Verifica que Claude Code esté instalado y actualizado

### Backup corrupto
Los backups con timestamp se mantienen en:
```
~/.config/Code/User/settings.json.backup.YYYYMMDD_HHMMSS
```

### Verificar configuración manualmente
```bash
jq '.' ~/.config/Code/User/settings.json | grep -E "(anthropic|claude)"
```

## 📞 Uso con Proveedores Externos

Este sistema funciona especialmente bien para:
- **Desarrollo**: Usar login OAuth para desarrollo casual
- **Producción/CI**: Usar API Key para automatización
- **Múltiples cuentas**: Cambiar rápidamente entre diferentes API Keys
- **Equipos**: Facilitar configuración en múltiples máquinas

¡Disfruta de Claude Code con mayor flexibilidad! 🤖✨