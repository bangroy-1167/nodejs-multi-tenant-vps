#!/bin/bash

################################################################################
# TAHAP 2: Node.js, NVM, PM2, Nginx Installation & Configuration
# Ubuntu 24.04 LTS
# 
# Script ini menginstal dan mengkonfigurasi:
# - NVM (Node Version Manager)
# - Node.js LTS
# - PM2 (Process Manager)
# - Nginx (Reverse Proxy)
# - Direktori struktur aplikasi
#
# Usage: bash tahap2-nodejs-pm2-nginx.sh
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}===============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if running with appropriate privileges
if [[ $EUID -ne 0 ]]; then
    print_error "Script ini harus dijalankan dengan sudo"
    exit 1
fi

# Check if Ubuntu 24.04
if ! grep -q "24.04" /etc/os-release; then
    print_warning "Script ini dirancang untuk Ubuntu 24.04. Versi Anda mungkin berbeda."
    read -p "Lanjutkan? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_header "TAHAP 2: Node.js, NVM, PM2, dan Nginx Installation"

# ============================================================================
# SECTION 1: Collect User Information
# ============================================================================
print_header "1. Informasi User & Konfigurasi"

# Get development user (default: devel_me)
read -p "Nama development user [default: devel_me]: " DEVEL_USER
DEVEL_USER=${DEVEL_USER:-devel_me}

if ! id "$DEVEL_USER" &>/dev/null; then
    print_error "User '$DEVEL_USER' tidak ditemukan. Jalankan tahap1 terlebih dahulu."
    exit 1
fi

print_success "Development user: $DEVEL_USER"

# Get Node.js version preference
echo -e "\n${YELLOW}Pilih versi Node.js:${NC}"
echo "1) LTS terbaru (18.x)"
echo "2) LTS stabil (20.x) - Direkomendasikan"
echo "3) Latest (22.x)"
read -p "Pilihan [default: 2]: " NODE_VERSION_CHOICE
NODE_VERSION_CHOICE=${NODE_VERSION_CHOICE:-2}

case $NODE_VERSION_CHOICE in
    1) NODE_VERSION="18" ;;
    2) NODE_VERSION="20" ;;
    3) NODE_VERSION="22" ;;
    *) NODE_VERSION="20" ;;
esac

print_success "Node.js versi: $NODE_VERSION (LTS)"

# Get number of applications
read -p "Perkiraan jumlah aplikasi yang akan di-host [default: 15]: " NUM_APPS
NUM_APPS=${NUM_APPS:-15}

print_success "Jumlah aplikasi: $NUM_APPS"

# Get domain
read -p "Domain aplikasi Anda [default: domainaplikasimu.id]: " DOMAIN
DOMAIN=${DOMAIN:-domainaplikasimu.id}

print_success "Domain: $DOMAIN"

# Get email for Nginx/SSL
read -p "Email admin untuk notifikasi [default: admin@$DOMAIN]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$DOMAIN}

print_success "Email admin: $ADMIN_EMAIL"

# ============================================================================
# SECTION 2: System Updates
# ============================================================================
print_header "2. Update System Packages"

apt-get update > /dev/null 2>&1
apt-get install -y curl wget git build-essential python3-minimal > /dev/null 2>&1

print_success "System packages updated"

# ============================================================================
# SECTION 3: Install NVM & Node.js
# ============================================================================
print_header "3. Install NVM dan Node.js"

# Switch to development user for NVM installation
NVM_DIR="/home/$DEVEL_USER/.nvm"

if [ ! -d "$NVM_DIR" ]; then
    print_warning "Menginstal NVM untuk user $DEVEL_USER..."
    
    sudo -u "$DEVEL_USER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'
    
    # Source NVM
    sudo -u "$DEVEL_USER" bash -c '. ~/.nvm/nvm.sh && nvm install --lts'
    
    print_success "NVM terinstal di $NVM_DIR"
else
    print_success "NVM sudah terinstal"
fi

# Source NVM and install specific Node.js version
sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    nvm install $NODE_VERSION
    nvm alias default $NODE_VERSION
    nvm use $NODE_VERSION
"

# Verify Node.js installation
NODE_VERSION_CHECK=$(sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    node -v
")

print_success "Node.js terinstal: $NODE_VERSION_CHECK"

# ============================================================================
# SECTION 4: Install PM2 Globally
# ============================================================================
print_header "4. Install PM2 (Process Manager)"

sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    npm install -g pm2
"

PM2_VERSION=$(sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    pm2 -v
")

print_success "PM2 terinstal: versi $PM2_VERSION"

# Setup PM2 startup script
sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    pm2 startup systemd -u $DEVEL_USER --hp /home/$DEVEL_USER
"

print_success "PM2 startup script dikonfigurasi"

# ============================================================================
# SECTION 5: Install & Configure Nginx
# ============================================================================
print_header "5. Install dan Konfigurasi Nginx"

apt-get install -y nginx > /dev/null 2>&1

# Create directory for app configs
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/conf.d

# Create main Nginx configuration for reverse proxy
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Test Nginx configuration
nginx -t > /dev/null 2>&1

print_success "Nginx terinstal dan dikonfigurasi"

# Start Nginx
systemctl enable nginx
systemctl start nginx

print_success "Nginx enabled dan dijalankan"

# ============================================================================
# SECTION 6: Create Application Directory Structure
# ============================================================================
print_header "6. Membuat Direktori Struktur Aplikasi"

APP_BASE_DIR="/home/$DEVEL_USER/apps"
mkdir -p "$APP_BASE_DIR"
mkdir -p "$APP_BASE_DIR/logs"
mkdir -p "$APP_BASE_DIR/shared"

# Create PM2 config directory
PM2_CONFIG_DIR="/home/$DEVEL_USER/pm2-configs"
mkdir -p "$PM2_CONFIG_DIR"

# Create example app directories
for ((i=1; i<=5; i++)); do
    APP_NAME="aplikasi$i"
    mkdir -p "$APP_BASE_DIR/$APP_NAME"/{src,public,dist}
    chown -R "$DEVEL_USER:$DEVEL_USER" "$APP_BASE_DIR/$APP_NAME"
done

# Set proper permissions
chown -R "$DEVEL_USER:$DEVEL_USER" "$APP_BASE_DIR"
chown -R "$DEVEL_USER:$DEVEL_USER" "$PM2_CONFIG_DIR"
chmod 755 "$APP_BASE_DIR"

print_success "Direktori aplikasi dibuat di $APP_BASE_DIR"

# ============================================================================
# SECTION 7: Create Default Nginx Configuration Template
# ============================================================================
print_header "7. Membuat Template Nginx Configuration"

cat > /etc/nginx/sites-available/default-template << 'EOF'
# Template untuk single aplikasi
# Copy dan modifikasi untuk setiap aplikasi

server {
    listen 80;
    listen [::]:80;
    
    # Ganti APPNAME dengan nama aplikasi Anda
    server_name app.DOMAIN_NAME;
    
    # Logging
    access_log /var/log/nginx/APPNAME.access.log;
    error_log /var/log/nginx/APPNAME.error.log;
    
    # Gzip compression untuk responses
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    
    # Reverse proxy ke Node.js aplikasi
    # Ganti 3001 dengan port aplikasi Anda
    location / {
        proxy_pass http://localhost:PORT_NUMBER;
        
        # Headers untuk preservasi informasi client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

print_success "Template Nginx configuration dibuat"

# ============================================================================
# SECTION 8: Create PM2 Example Ecosystem Configuration
# ============================================================================
print_header "8. Membuat Template PM2 Ecosystem Configuration"

cat > "$PM2_CONFIG_DIR/ecosystem.template.js" << 'EOF'
// Template PM2 Ecosystem Configuration
// Copy file ini dan modifikasi sesuai kebutuhan aplikasi Anda

module.exports = {
  apps: [
    {
      name: 'aplikasi1',
      script: '/home/devel_me/apps/aplikasi1/dist/index.js',
      instances: 2,
      exec_mode: 'cluster',
      watch: false,
      
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      
      error_file: '/home/devel_me/apps/logs/aplikasi1.error.log',
      out_file: '/home/devel_me/apps/logs/aplikasi1.out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      
      autorestart: true,
      max_memory_restart: '500M',
      
      // Graceful shutdown
      kill_timeout: 5000,
      wait_ready: true,
      
      // Environment file
      env_file: '/home/devel_me/apps/aplikasi1/.env.production'
    }
  ],
  
  // Deploy configuration (optional)
  deploy: {
    production: {
      user: 'devel_me',
      host: 'your-ip-address',
      ref: 'origin/main',
      repo: 'git@github.com:youruser/repo.git',
      path: '/home/devel_me/apps/aplikasi1',
      'post-deploy': 'npm install && npm run build && pm2 reload ecosystem.config.js --env production'
    }
  }
};
EOF

chown "$DEVEL_USER:$DEVEL_USER" "$PM2_CONFIG_DIR/ecosystem.template.js"

print_success "Template PM2 ecosystem configuration dibuat"

# ============================================================================
# SECTION 9: Configure User Shell
# ============================================================================
print_header "9. Konfigurasi Shell untuk Development User"

# Add NVM to user's bashrc if not already there
if ! sudo -u "$DEVEL_USER" grep -q "NVM_DIR" /home/$DEVEL_USER/.bashrc; then
    sudo -u "$DEVEL_USER" bash -c 'cat >> ~/.bashrc << "BASHRC_EOF"

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
BASHRC_EOF'
fi

print_success "Shell configuration diperbarui"

# ============================================================================
# SECTION 10: Verification & Summary
# ============================================================================
print_header "10. Verifikasi dan Summary"

echo -e "\n${BLUE}Hasil Instalasi:${NC}\n"

# Check Node.js
NODE_CHECK=$(sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    node -v && npm -v
" 2>/dev/null)

if [ $? -eq 0 ]; then
    print_success "Node.js & NPM:"
    echo "$NODE_CHECK" | sed 's/^/    /'
else
    print_error "Node.js installation verification failed"
fi

# Check PM2
PM2_CHECK=$(sudo -u "$DEVEL_USER" bash -c "
    export NVM_DIR=\"$NVM_DIR\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    pm2 -v
" 2>/dev/null)

if [ $? -eq 0 ]; then
    print_success "PM2: v$PM2_CHECK"
else
    print_error "PM2 verification failed"
fi

# Check Nginx
if nginx -v 2>&1 | grep -q "nginx"; then
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3)
    print_success "Nginx: $NGINX_VERSION"
else
    print_error "Nginx verification failed"
fi

echo -e "\n${BLUE}Direktori Penting:${NC}\n"
echo "    Apps directory:       $APP_BASE_DIR"
echo "    PM2 configs:          $PM2_CONFIG_DIR"
echo "    Nginx configs:        /etc/nginx/sites-available"
echo "    Nginx logs:           /var/log/nginx"
echo "    Development user:     $DEVEL_USER"

echo -e "\n${BLUE}Langkah Selanjutnya:${NC}\n"
echo "    1. Jalankan tahap3 untuk setup GitHub SSH key"
echo "    2. Persiapkan repository aplikasi Anda di GitHub"
echo "    3. Clone repository ke dalam $APP_BASE_DIR"
echo "    4. Konfigurasi Nginx untuk setiap aplikasi"
echo "    5. Setup PM2 ecosystem configuration untuk setiap app"

echo -e "\n${BLUE}Testing Nginx:${NC}\n"
curl -s http://localhost/ 2>&1 | head -5 | sed 's/^/    /'

print_header "✓ TAHAP 2 Selesai!"

echo -e "${GREEN}Instalasi tahap 2 berhasil dikonfigurasi.${NC}"
echo -e "Lanjut ke tahap berikutnya dengan perintah:\n"
echo -e "  ${YELLOW}bash tahap3-github-git-setup.sh${NC}\n"
