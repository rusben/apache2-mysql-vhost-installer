#!/bin/bash

# ------------------------------------------------------------
# Script para instalar entorno web básico (PHP/MySQL/Apache) en Ubuntu 26.04
# Uso: sudo ./instalar-entorno-web.sh dominio.internal
# Nota: ServerName = www.dominio.internal, ServerAlias = dominio.internal
# ------------------------------------------------------------

set -e  # Salir si ocurre un error

WEB_ALIAS="$1"  # Este será el ServerAlias (ej: miweb.internal)

if [ -z "$WEB_ALIAS" ]; then
    echo "❌ Error: Debes proporcionar un nombre de dominio (ej: miweb.internal)"
    echo "Uso: $0 <dominio.internal>"
    exit 1
fi

# Extraer el nombre base sin la extensión (ej: "miweb" de "miweb.internal")
BASE_NAME="${WEB_ALIAS%%.*}"
TLD="${WEB_ALIAS#*.}"

# Si no hay punto, asumimos .internal
if [[ "$WEB_ALIAS" == "$BASE_NAME" ]]; then
    TLD="internal"
    WEB_ALIAS="${BASE_NAME}.internal"
fi

# Definir ServerName y ServerAlias
SERVER_NAME="www.${BASE_NAME}.${TLD}"
SERVER_ALIAS="${BASE_NAME}.${TLD}"

# Variables de configuración
DB_NAME="${SERVER_ALIAS//./_}"
DB_USER="user_${DB_NAME}"
DB_PASS="pass_$(openssl rand -hex 12)"
PROJECT_DIR="/var/www/${SERVER_ALIAS}"
VHOST_FILE="/etc/apache2/sites-available/${SERVER_ALIAS}.conf"

# Comprobar que se ejecuta como root o con sudo
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Por favor, ejecuta este script con sudo."
  exit 1
fi

# Obtener el usuario original que ejecutó sudo
REAL_USER=${SUDO_USER:-$USER}

echo "🔧 Instalando entorno para: $SERVER_ALIAS"
echo "📁 Directorio del proyecto: $PROJECT_DIR"
echo "🗃️  Base de datos: $DB_NAME"
echo "👤 Usuario MySQL: $DB_USER"
echo "🌐 ServerName: $SERVER_NAME"
echo "🌐 ServerAlias: $SERVER_ALIAS"

# 1. Actualizar sistema
echo "🔄 Actualizando sistema..."
apt update -y

# 2. Instalar Apache, MySQL, PHP y dependencias básicas
echo "📦 Instalando Apache, MySQL, PHP y extensiones..."
apt install -y apache2 mysql-server php libapache2-mod-php php-mysql php-cli php-json php-mbstring php-curl php-xml composer

# 3. Configurar MySQL (Compatible con MySQL 8.4+ / Ubuntu 26.04)
echo "🔐 Configurando MySQL..."
# Se elimina 'mysql_native_password' ya que está obsoleto/eliminado en MySQL 8.4+
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass123'; FLUSH PRIVILEGES;" 2>/dev/null || true

mysql -u root -prootpass123 <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "✅ Base de datos y usuario creados."

# 4. Crear directorio del proyecto
echo "📂 Creando directorio del proyecto..."
mkdir -p "$PROJECT_DIR"
chown -R "$REAL_USER":"$REAL_USER" "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5. Crear index.php básico (Sin SlimPHP)
echo "📄 Creando index.php de bienvenida..."
cat > index.php <<EOF
<?php
echo "<!DOCTYPE html>
<html lang='es'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Bienvenido a $SERVER_ALIAS</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; color: #333; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: inline-block; }
        h1 { color: #2c3e50; }
        .info { margin-top: 20px; text-align: left; background: #ecf0f1; padding: 15px; border-radius: 5px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>¡Hola desde $SERVER_ALIAS!</h1>
        <p>Entorno PHP/MySQL/Apache configurado correctamente en Ubuntu 26.04.</p>
        <div class='info'>
            <strong>Detalles del entorno:</strong><br>
            📂 Directorio: $PROJECT_DIR<br>
            🗃️ Base de datos: $DB_NAME<br>
            🌐 PHP Version: " . phpversion() . "
        </div>
    </div>
</body>
</html>
EOF

# 6. Crear .htaccess básico (por si necesitas reescritura de URLs en el futuro)
echo "📄 Creando .htaccess..."
cat > .htaccess <<'EOF'
RewriteEngine On
# Permitir que las solicitudes de archivos y directorios existentes se sirvan directamente
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
# El resto de las solicitudes se pueden manejar aquí si se añade un framework a futuro
EOF

# 7. Crear VirtualHost
echo "🌐 Configurando VirtualHost..."
cat > "$VHOST_FILE" <<EOF
<VirtualHost *:80>
    ServerName $SERVER_NAME
    ServerAlias $SERVER_ALIAS

    DocumentRoot $PROJECT_DIR

    <Directory $PROJECT_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${SERVER_ALIAS}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SERVER_ALIAS}_access.log combined
</VirtualHost>
EOF

# 8. Habilitar módulos y sitio
echo "⚡ Habilitando módulo rewrite y sitio..."
a2enmod rewrite
a2ensite "$(basename "$VHOST_FILE" .conf)"

# 9. Reiniciar Apache
echo "🔄 Reiniciando Apache..."
systemctl restart apache2

# 10. Añadir entradas al /etc/hosts
echo "📝 Configurando /etc/hosts..."
HOSTS_LINE="127.0.0.1 $SERVER_NAME $SERVER_ALIAS"

# Hacer backup de /etc/hosts si no existe
[ ! -f /etc/hosts.bak ] && cp /etc/hosts /etc/hosts.bak

# Verificar si ya existe alguna de las entradas
if ! grep -q "$SERVER_NAME" /etc/hosts && ! grep -q "$SERVER_ALIAS" /etc/hosts; then
    echo "$HOSTS_LINE" >> /etc/hosts
    echo "✅ Añadido a /etc/hosts: $HOSTS_LINE"
else
    echo "ℹ️  Ya existe una entrada para $SERVER_NAME o $SERVER_ALIAS en /etc/hosts"
fi

# 11. Mostrar resumen
echo ""
echo "🎉 ¡Instalación completada con éxito!"
echo ""
echo "🌐 Accede a tu sitio en:"
echo "   → http://$SERVER_NAME"
echo "   → http://$SERVER_ALIAS"
echo "📂 Directorio: $PROJECT_DIR"
echo "🗃️  Base de datos: $DB_NAME"
echo "👤 Usuario DB: $DB_USER"
echo "🔑 Contraseña DB: $DB_PASS"
echo ""
echo "💡 Nota: Se ha configurado /etc/hosts automáticamente para resolución local."
echo "⚠️  Recuerda guardar la contraseña de la base de datos en un lugar seguro."
echo ""
