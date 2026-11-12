# Instalador de Entorno Web LAMP (Ubuntu 26.04)

Un script de Bash automatizado para configurar un entorno de desarrollo web básico (**L**inux, **A**pache, **M**ySQL, **P**HP) en Ubuntu 26.04. 

Este script crea un VirtualHost, configura una base de datos dedicada con su usuario, y genera un archivo de bienvenida, **sin depender de frameworks externos** como SlimPHP.

## ✨ Características

- 📦 **Instalación completa**: Apache2, MySQL Server, PHP 8.x y extensiones esenciales (`mysql`, `mbstring`, `curl`, `xml`, `json`, `cli`).
- 🗄️ **Base de datos automatizada**: Crea una base de datos y un usuario MySQL con permisos exclusivos para el proyecto.
- 🌐 **VirtualHost dinámico**: Configura `ServerName` (www.dominio.internal) y `ServerAlias` (dominio.internal) automáticamente.
- 📝 **Resolución local**: Añade las entradas necesarias al archivo `/etc/hosts` para que el dominio funcione de inmediato en el navegador.
- 🛡️ **Compatibilidad MySQL 8.4+**: Utiliza el método de autenticación moderno (`caching_sha2_password`), evitando errores por el obsoleto `mysql_native_password`.
- 📂 **Estructura lista**: Genera un `index.php` de prueba visual y un `.htaccess` base con `RewriteEngine` activado.

## 📋 Requisitos Previos

- Sistema operativo: **Ubuntu 26.04** (o versiones compatibles basadas en Debian/Ubuntu).
- Permisos de superusuario (`sudo`).
- Conexión a internet para descargar los paquetes.

## 🚀 Uso

1. **Crea el archivo del script** en tu servidor o máquina local:
   ```bash
   nano instalar-entorno-web.sh
