# VPS Tencent Uprising - Multi-Application Node.js Production Guide

**Infrastruktur**: Ubuntu 24.04 LTS  
**VPS IP**: yourvps-ippub  
**Domain**: aplikasiabiyorf.id  
**Specs**: 4GB RAM, 2 Core CPU, 50GB Storage  
**Target Apps**: 10-20 React.js Applications  
**Architecture**: Hybrid routing (Port-based + Path-based) dengan Nginx reverse proxy

---

## TAHAP 1: INITIAL SETUP & SECURITY HARDENING

### 1.1 Koneksi Awal & Update System

```bash
# Koneksi ke VPS (ganti dengan password yang tersedia)
ssh root@yourvps-ippub

# Update system packages
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

# Install essential tools
sudo apt install -y curl wget vim git nano htop glances net-tools
```

### 1.2 Setup Firewall (UFW)

```bash
# Enable firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (standar port 22)
sudo ufw allow 22/tcp

# Allow HTTP & HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WireGuard (jika sudah ada)
sudo ufw allow 51820/udp

# Enable firewall
sudo ufw enable

# Verify status
sudo ufw status verbose
```

### 1.3 SSH Hardening

```bash
# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Pastikan pengaturan ini:
# Port 22
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes
# X11Forwarding no
# MaxAuthTries 3
# MaxSessions 5
# AllowUsers devel_me

# Test SSH config
sudo sshd -t

# Restart SSH
sudo systemctl restart sshd
```

### 1.4 Setup User Development (devel_me)

```bash
# Buat user baru
sudo useradd -m -s /bin/bash devel_me

# Set password (akan diminta)
sudo passwd devel_me

# Tambahkan ke grup sudo
sudo usermod -aG sudo devel_me

# Buat direktori .ssh
sudo mkdir -p /home/devel_me/.ssh

# Setup sudoers untuk no-password sudo (opsional, untuk automation)
sudo usermod -aG sudo devel_me
echo "devel_me ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/devel_me
```

### 1.5 Fail2Ban Installation (Brute Force Protection)

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Create local config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit konfigurasi
sudo nano /etc/fail2ban/jail.local

# Pastikan ini:
# [DEFAULT]
# bantime = 3600
# maxretry = 5
# findtime = 600

# [sshd]
# enabled = true

# Restart Fail2Ban
sudo systemctl restart fail2ban

# Check status
sudo fail2ban-client status
```

---

## TAHAP 2: DEVELOPMENT ENVIRONMENT SETUP

### 2.1 Install Node.js & npm (via NVM)

```bash
# Login sebagai devel_me
su - devel_me

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source ~/.bashrc untuk load NVM
source ~/.bashrc

# Verify NVM
nvm --version

# Install Node.js LTS (rekomendasi: v20.x)
nvm install --lts

# Set default Node version
nvm alias default node

# Verify installation
node --version
npm --version

# Upgrade npm ke versi terbaru
npm install -g npm@latest

# Back to root untuk next steps
exit
```

### 2.2 Install & Setup Git

```bash
# Install Git (biasanya sudah ada)
sudo apt install -y git

# Configure Git global (sebagai devel_me)
sudo -u devel_me git config --global user.name "Development Team"
sudo -u devel_me git config --global user.email "dev@aplikasikeren.id"

# Setup Git credential helper
sudo -u devel_me git config --global credential.helper store

# Verify
sudo -u devel_me git config --list
```

### 2.3 Setup SSH Key untuk GitHub

```bash
# Login sebagai devel_me
sudo su - devel_me

# Generate SSH key (tekan Enter saat diminta passphrase, atau beri passphrase)
ssh-keygen -t ed25519 -C "dev@aplikasikeren.id"

# Default location: ~/.ssh/id_ed25519
# Pilih: ~/.ssh/github_vps untuk spesifik

# Jika menggunakan nama custom, buat SSH config
nano ~/.ssh/config

# Isi dengan:
# Host github.com
#     HostName github.com
#     User git
#     IdentityFile ~/.ssh/github_vps
#     AddKeysToAgent yes

# Set permissions
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/github_vps

# Copy public key
cat ~/.ssh/github_vps.pub

# Paste key di GitHub: Settings → SSH and GPG keys → New SSH key

# Test koneksi
ssh -T git@github.com

# Expected output:
# Hi <your-username>! You've successfully authenticated...

# Exit dari devel_me
exit
```

### 2.4 Install PM2, Nginx & Dependencies

```bash
# PM2 global
npm install -g pm2

# Install Nginx
sudo apt install -y nginx

# Install Certbot untuk SSL
sudo apt install -y certbot python3-certbot-nginx

# Install build tools
sudo apt install -y build-essential python3-dev

# Verify installations
pm2 --version
nginx -v
certbot --version
```

---

## TAHAP 3: MULTI-APPLICATION ARCHITECTURE

### 3.1 Struktur Direktori untuk 10-20 Aplikasi

```bash
# Login sebagai devel_me
sudo su - devel_me

# Buat struktur direktori
mkdir -p ~/applications/{staging,production}
mkdir -p ~/pm2
mkdir -p ~/logs/{nginx,pm2,apps}
mkdir -p ~/backups

# Struktur detail:
# ~/applications/
# ├── production/
# │   ├── app-dashboard/
# │   │   ├── node_modules/
# │   │   ├── dist/ (build output)
# │   │   ├── src/
# │   │   ├── package.json
# │   │   ├── .env.production
# │   │   └── ...
# │   ├── app-analytics/
# │   ├── app-reports/
# │   └── ... (16 more apps)
# │
# ├── staging/
# │   ├── app-dashboard/
# │   ├── app-analytics/
# │   └── ...
#
# ~/pm2/
# ├── ecosystem-production.config.js
# └── ecosystem-staging.config.js
#
# ~/logs/
# ├── nginx/
# ├── pm2/
# └── apps/
```

### 3.2 Port Allocation Strategy

**Routing Strategy Hybrid**:

1. **Development** (Port-based):
   - Port 3001-3020: React Apps (frontend)
   - Port 4001-4020: Backend APIs (jika ada)

2. **Staging** (Path-based):
   - `https://staging.aplikasikeren.id/app-dashboard`
   - `https://staging.aplikasikeren.id/app-analytics`
   - Backend: `:4001-4020` (internal)

3. **Production** (Hybrid):
   - Primary: Subdomains
     - `https://dashboard.aplikasikeren.id`
     - `https://analytics.aplikasikeren.id`
   - Secondary: Path-based
     - `https://aplikasikeren.id/app/dashboard`
     - `https://aplikasikeren.id/app/analytics`
   - Backend: `:4001-4020` (internal, no expose)

### 3.3 Port Mapping Reference

```bash
# PRODUCTION APPS (React Frontend)
# Port 3001: app-dashboard
# Port 3002: app-analytics
# Port 3003: app-reports
# Port 3004: app-invoicing
# Port 3005: app-crm
# Port 3006: app-inventory
# Port 3007: app-accounting
# Port 3008: app-hrm
# Port 3009: app-erp
# Port 3010: app-ecommerce
# ... (up to 3020)

# BACKEND APIS (Node.js/Express)
# Port 4001-4020: Corresponding backend services

# STAGING APPS (all on single port + path routing)
# Port 3100: Staging reverse proxy
```

---

## TAHAP 4: NGINX CONFIGURATION

### 4.1 Backup & Clear Default Config

```bash
# Backup default config
sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
sudo mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup

# Remove from enabled
sudo rm -f /etc/nginx/sites-enabled/default
```

### 4.2 Production Nginx Config (Multi-subdomain)

```bash
# Create production config
sudo nano /etc/nginx/sites-available/aplikasikeren-production

# Isi dengan:
```

```nginx
# Upstream definitions
upstream app_dashboard { server localhost:3001; }
upstream app_analytics { server localhost:3002; }
upstream app_reports { server localhost:3003; }
upstream app_invoicing { server localhost:3004; }
upstream app_crm { server localhost:3005; }
upstream app_inventory { server localhost:3006; }
upstream app_accounting { server localhost:3007; }
upstream app_hrm { server localhost:3008; }
upstream app_erp { server localhost:3009; }
upstream app_ecommerce { server localhost:3010; }

# Gzip compression
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_proxied any;
gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name aplikasikeren.id *.aplikasikeren.id;
    return 301 https://$server_name$request_uri;
}

# Main HTTPS server - path-based routing
server {
    listen 443 ssl http2;
    server_name aplikasikeren.id;

    # SSL certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/aplikasikeren.id/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aplikasikeren.id/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Access & error logs
    access_log /home/devel_me/logs/nginx/aplikasikeren-production-access.log;
    error_log /home/devel_me/logs/nginx/aplikasikeren-production-error.log;

    # Path-based routing untuk production
    location /app/dashboard {
        proxy_pass http://app_dashboard/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /app/dashboard/;
        proxy_buffering off;
    }

    location /app/analytics {
        proxy_pass http://app_analytics/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /app/analytics/;
        proxy_buffering off;
    }

    location /app/reports {
        proxy_pass http://app_reports/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /app/reports/;
        proxy_buffering off;
    }

    # Repeat untuk aplikasi lainnya...

    # Default location
    location / {
        return 404;
    }
}

# Subdomain routing untuk production (optional, untuk future use)
server {
    listen 443 ssl http2;
    server_name *.aplikasikeren.id;

    ssl_certificate /etc/letsencrypt/live/aplikasikeren.id/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aplikasikeren.id/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    access_log /home/devel_me/logs/nginx/aplikasikeren-subdomain-access.log;
    error_log /home/devel_me/logs/nginx/aplikasikeren-subdomain-error.log;

    # Proxy ke upstream sesuai subdomain
    set $subdomain $host;
    if ($subdomain ~ "^(?<app>.+)\.aplikasikeren\.id$") {
        set $app $app;
    }

    # Manual routing per subdomain
    location / {
        if ($host ~* ^dashboard\.aplikasikeren\.id$) {
            proxy_pass http://app_dashboard;
        }
        if ($host ~* ^analytics\.aplikasikeren\.id$) {
            proxy_pass http://app_analytics;
        }
        if ($host ~* ^reports\.aplikasikeren\.id$) {
            proxy_pass http://app_reports;
        }

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }
}
```

### 4.3 Staging Nginx Config

```bash
sudo nano /etc/nginx/sites-available/aplikasikeren-staging
```

```nginx
# Staging upstream - port 3100+ untuk each app
upstream staging_app_dashboard { server localhost:3101; }
upstream staging_app_analytics { server localhost:3102; }
upstream staging_app_reports { server localhost:3103; }

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name staging.aplikasikeren.id;
    return 301 https://staging.aplikasikeren.id$request_uri;
}

# HTTPS Staging server
server {
    listen 443 ssl http2;
    server_name staging.aplikasikeren.id;

    ssl_certificate /etc/letsencrypt/live/staging.aplikasikeren.id/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/staging.aplikasikeren.id/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    access_log /home/devel_me/logs/nginx/aplikasikeren-staging-access.log;
    error_log /home/devel_me/logs/nginx/aplikasikeren-staging-error.log;

    # Staging apps dengan path-based routing
    location /app/dashboard {
        proxy_pass http://staging_app_dashboard/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /app/dashboard/;
        proxy_buffering off;
    }

    location /app/analytics {
        proxy_pass http://staging_app_analytics/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /app/analytics/;
        proxy_buffering off;
    }

    # ... additional staging apps
}
```

### 4.4 Enable Nginx Configs

```bash
# Create symlinks
sudo ln -s /etc/nginx/sites-available/aplikasikeren-production /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/aplikasikeren-staging /etc/nginx/sites-enabled/

# Test Nginx config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Verify status
sudo systemctl status nginx
```

---

## TAHAP 5: PM2 SETUP UNTUK MULTIPLE APPLICATIONS

### 5.1 Production PM2 Ecosystem Config

```bash
# Create production config
sudo -u devel_me nano /home/devel_me/pm2/ecosystem-production.config.js
```

```javascript
module.exports = {
  apps: [
    // ============ APP DASHBOARD ============
    {
      name: 'prod-app-dashboard',
      script: '/home/devel_me/applications/production/app-dashboard/dist/index.js',
      port: 3001,
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      ignore_watch: ['node_modules', 'dist', 'logs'],
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
        REACT_APP_API_URL: 'https://api-dashboard.aplikasikeren.id'
      },
      error_file: '/home/devel_me/logs/pm2/app-dashboard-error.log',
      out_file: '/home/devel_me/logs/pm2/app-dashboard-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '500M',
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      listen_timeout: 5000
    },

    // ============ APP ANALYTICS ============
    {
      name: 'prod-app-analytics',
      script: '/home/devel_me/applications/production/app-analytics/dist/index.js',
      port: 3002,
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      ignore_watch: ['node_modules', 'dist', 'logs'],
      env: {
        NODE_ENV: 'production',
        PORT: 3002,
        REACT_APP_API_URL: 'https://api-analytics.aplikasikeren.id'
      },
      error_file: '/home/devel_me/logs/pm2/app-analytics-error.log',
      out_file: '/home/devel_me/logs/pm2/app-analytics-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '500M',
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      listen_timeout: 5000
    },

    // ============ APP REPORTS ============
    {
      name: 'prod-app-reports',
      script: '/home/devel_me/applications/production/app-reports/dist/index.js',
      port: 3003,
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      ignore_watch: ['node_modules', 'dist', 'logs'],
      env: {
        NODE_ENV: 'production',
        PORT: 3003,
        REACT_APP_API_URL: 'https://api-reports.aplikasikeren.id'
      },
      error_file: '/home/devel_me/logs/pm2/app-reports-error.log',
      out_file: '/home/devel_me/logs/pm2/app-reports-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '500M',
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      listen_timeout: 5000
    },

    // ============ TAMBAHKAN APLIKASI LAIN (3004-3020) ============
    // Ikuti pattern di atas untuk aplikasi sisanya
  ]
};
```

### 5.2 Staging PM2 Ecosystem Config

```bash
sudo -u devel_me nano /home/devel_me/pm2/ecosystem-staging.config.js
```

```javascript
module.exports = {
  apps: [
    // Staging: Port 3101, 3102, 3103, dst
    {
      name: 'staging-app-dashboard',
      script: '/home/devel_me/applications/staging/app-dashboard/dist/index.js',
      port: 3101,
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      env: {
        NODE_ENV: 'staging',
        PORT: 3101,
        REACT_APP_API_URL: 'https://staging-api-dashboard.aplikasikeren.id'
      },
      error_file: '/home/devel_me/logs/pm2/staging-app-dashboard-error.log',
      out_file: '/home/devel_me/logs/pm2/staging-app-dashboard-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '500M',
      autorestart: true
    },

    {
      name: 'staging-app-analytics',
      script: '/home/devel_me/applications/staging/app-analytics/dist/index.js',
      port: 3102,
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      env: {
        NODE_ENV: 'staging',
        PORT: 3102,
        REACT_APP_API_URL: 'https://staging-api-analytics.aplikasikeren.id'
      },
      error_file: '/home/devel_me/logs/pm2/staging-app-analytics-error.log',
      out_file: '/home/devel_me/logs/pm2/staging-app-analytics-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '500M',
      autorestart: true
    }

    // ... lanjutkan untuk staging apps lainnya
  ]
};
```

### 5.3 PM2 Setup & Startup

```bash
# Login sebagai devel_me
sudo su - devel_me

# Start production apps
pm2 start ~/pm2/ecosystem-production.config.js --name "production"

# Start staging apps (di terminal berbeda atau setelah production)
pm2 start ~/pm2/ecosystem-staging.config.js --name "staging"

# Verify running apps
pm2 list

# Monitor real-time
pm2 monit

# Check logs
pm2 logs prod-app-dashboard --lines 50
pm2 logs staging-app-dashboard --lines 50

# Setup PM2 startup (auto-start on reboot)
pm2 startup
pm2 save

# Verify startup was saved
pm2 startup --user devel_me
pm2 save

# Test PM2 persistence
pm2 kill
pm2 status  # Should show apps restarting automatically
```

### 5.4 PM2 Management Commands

```bash
# Start/Stop/Restart
pm2 start ecosystem-production.config.js
pm2 stop prod-app-dashboard
pm2 restart prod-app-dashboard
pm2 reload prod-app-dashboard  # Zero-downtime restart

# Delete & cleanup
pm2 delete prod-app-dashboard
pm2 delete all
pm2 flush  # Clear logs

# Update app
pm2 update

# Generate startup hook
pm2 save
```

---

## TAHAP 6: SSL/HTTPS DENGAN LET'S ENCRYPT

### 6.1 Install SSL Certificates

```bash
# Primary domain
sudo certbot certonly --nginx -d aplikasikeren.id -d www.aplikasikeren.id

# Staging subdomain
sudo certbot certonly --nginx -d staging.aplikasikeren.id

# Individual subdomains (jika menggunakan path di production, tidak perlu, tapi jika pakai subdomain)
sudo certbot certonly --nginx -d dashboard.aplikasikeren.id -d analytics.aplikasikeren.id -d reports.aplikasikeren.id

# Verify certificates
sudo certbot certificates
```

### 6.2 Auto-Renewal

```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Setup auto-renewal dengan systemd timer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Check status
sudo systemctl status certbot.timer

# Verify renewal schedule
sudo systemctl list-timers certbot.timer
```

### 6.3 Self-Signed Certificate (Development)

Jika perlu local development dengan HTTPS:

```bash
# Create self-signed cert
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/self-signed.key \
  -out /etc/nginx/ssl/self-signed.crt \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Dev/CN=dev.aplikasikeren.id"

# Update Nginx config dengan self-signed certs
# ssl_certificate /etc/nginx/ssl/self-signed.crt;
# ssl_certificate_key /etc/nginx/ssl/self-signed.key;
```

---

## TAHAP 7: STAGING VS PRODUCTION ENVIRONMENT

### 7.1 Environment File Setup

```bash
# Production .env untuk setiap app
sudo -u devel_me nano /home/devel_me/applications/production/app-dashboard/.env.production
```

```env
NODE_ENV=production
PORT=3001
REACT_APP_API_URL=https://api-dashboard.aplikasikeren.id
REACT_APP_ENV=production
LOG_LEVEL=error
DATABASE_POOL_SIZE=10
CACHE_TTL=3600
```

```bash
# Staging .env untuk setiap app
sudo -u devel_me nano /home/devel_me/applications/staging/app-dashboard/.env.staging
```

```env
NODE_ENV=staging
PORT=3101
REACT_APP_API_URL=https://staging-api-dashboard.aplikasikeren.id
REACT_APP_ENV=staging
LOG_LEVEL=warn
DATABASE_POOL_SIZE=5
CACHE_TTL=1800
DEBUG=true
```

### 7.2 Branching Strategy (Git)

```bash
# Development branch (local development)
# - Developers bekerja di feature branches
# - Merge ke develop setelah code review

# Staging branch
# - Deploy dari staging branch
# - Testing & QA
# - Deploy command: git pull origin staging

# Production branch
# - Deploy dari main/production branch
# - Stable release only
# - Deploy command: git pull origin main
```

### 7.3 Deployment Checklist

**Before Staging**:
- [ ] Code review completed
- [ ] Unit tests passed
- [ ] Lint check passed
- [ ] Build successful
- [ ] No console errors

**Before Production**:
- [ ] Tested in staging environment
- [ ] No database migrations needed or handled
- [ ] Environment variables updated
- [ ] SSL certificates valid
- [ ] Backup data created
- [ ] Rollback plan ready

---

## TAHAP 8: DEPLOYMENT WORKFLOW (MANUAL)

### 8.1 Deployment Script untuk Production

```bash
# Create deployment script
sudo -u devel_me nano /home/devel_me/deploy-production.sh
```

```bash
#!/bin/bash

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GITHUB_ORG="your-github-org"
APPS=("app-dashboard" "app-analytics" "app-reports")
ENV="production"
APP_DIR="/home/devel_me/applications/${ENV}"
PM2_CONFIG="/home/devel_me/pm2/ecosystem-${ENV}.config.js"

# Function: Print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 1. Backup current state
print_status "Creating backup of current production state..."
BACKUP_DIR="/home/devel_me/backups/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${BACKUP_DIR}"
for app in "${APPS[@]}"; do
    cp -r "${APP_DIR}/${app}" "${BACKUP_DIR}/" || print_warning "Backup failed for ${app}"
done

# 2. Pull latest code from GitHub
print_status "Pulling latest code from GitHub..."
for app in "${APPS[@]}"; do
    cd "${APP_DIR}/${app}"
    
    # Check if git repo exists
    if [ ! -d .git ]; then
        print_error "Not a git repository: ${app}"
        exit 1
    fi
    
    # Pull code
    git fetch origin || { print_error "Git fetch failed for ${app}"; exit 1; }
    git checkout main || { print_error "Git checkout failed for ${app}"; exit 1; }
    git pull origin main || { print_error "Git pull failed for ${app}"; exit 1; }
    
    print_status "✓ ${app} - Code pulled successfully"
done

# 3. Install dependencies
print_status "Installing npm dependencies..."
for app in "${APPS[@]}"; do
    cd "${APP_DIR}/${app}"
    
    npm ci --omit=dev || { print_error "npm ci failed for ${app}"; exit 1; }
    print_status "✓ ${app} - Dependencies installed"
done

# 4. Build applications
print_status "Building applications..."
for app in "${APPS[@]}"; do
    cd "${APP_DIR}/${app}"
    
    npm run build || { print_error "Build failed for ${app}"; exit 1; }
    print_status "✓ ${app} - Build successful"
done

# 5. Reload apps with PM2
print_status "Reloading apps with PM2..."
pm2 reload all --update || { print_error "PM2 reload failed"; exit 1; }

# 6. Verify apps are running
print_status "Verifying apps status..."
sleep 2
pm2 status

# 7. Run smoke tests
print_status "Running smoke tests..."
# Contoh: curl health check endpoint
for port in {3001..3003}; do
    curl -f http://localhost:${port}/health > /dev/null 2>&1 || print_warning "Health check failed for port ${port}"
done

print_status "${GREEN}✓ Deployment completed successfully!${NC}"

# 8. Log deployment
echo "$(date '+%Y-%m-%d %H:%M:%S') - Deployment completed for ${APPS[@]}" >> /home/devel_me/logs/deployment.log

exit 0
```

### 8.2 Deployment Script untuk Staging

```bash
sudo -u devel_me nano /home/devel_me/deploy-staging.sh
```

```bash
#!/bin/bash

# Same as production, but dengan:
# - ENV="staging"
# - git checkout staging (atau development branch)
# - Port prefix 3100+
# - PM2 config: ecosystem-staging.config.js
```

### 8.3 Execute Deployment

```bash
# Make script executable
sudo chmod +x /home/devel_me/deploy-production.sh
sudo chmod +x /home/devel_me/deploy-staging.sh

# Run deployment (sebagai devel_me)
sudo -u devel_me bash /home/devel_me/deploy-production.sh

# Run staging deployment
sudo -u devel_me bash /home/devel_me/deploy-staging.sh
```

### 8.4 Manual Deployment Steps (Alternative)

Jika tidak ingin menggunakan script:

```bash
# 1. Login sebagai devel_me
sudo su - devel_me

# 2. Pull latest code
cd ~/applications/production/app-dashboard
git fetch origin
git checkout main
git pull origin main

# 3. Install dependencies
npm ci --omit=dev

# 4. Build
npm run build

# 5. Reload PM2
pm2 reload prod-app-dashboard

# 6. Check logs
pm2 logs prod-app-dashboard --lines 50

# 7. Verify with curl
curl -f http://localhost:3001/health
```

---

## TAHAP 9: MONITORING & MAINTENANCE

### 9.1 PM2 Monitoring

```bash
# Real-time monitoring
pm2 monit

# Extended info
pm2 info prod-app-dashboard

# Web dashboard (opsional, butuh Pro version)
pm2 web  # Access at http://localhost:9615

# Monitor dashboard
pm2 monitor
```

### 9.2 System Monitoring

```bash
# Install monitoring tools
sudo apt install -y htop glances

# Real-time system monitor
htop

# Detailed system stats
glances

# Check disk usage
df -h

# Check memory usage
free -h

# Check process list
ps aux | grep node
```

### 9.3 Log Management

```bash
# View logs
pm2 logs
pm2 logs prod-app-dashboard
pm2 logs prod-app-dashboard --lines 100
pm2 logs --err  # Error logs only

# Nginx logs
sudo tail -f /home/devel_me/logs/nginx/aplikasikeren-production-access.log
sudo tail -f /home/devel_me/logs/nginx/aplikasikeren-production-error.log

# Rotate logs (automatic with logrotate)
sudo nano /etc/logrotate.d/pm2-logs
```

```
/home/devel_me/logs/pm2/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 devel_me devel_me
    sharedscripts
}

/home/devel_me/logs/nginx/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 devel_me devel_me
}
```

### 9.4 Backup Strategy

```bash
# Create daily backup script
sudo -u devel_me nano /home/devel_me/backup.sh
```

```bash
#!/bin/bash

BACKUP_DIR="/home/devel_me/backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup-${DATE}.tar.gz"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup applications & configs
tar -czf "${BACKUP_FILE}" \
    /home/devel_me/applications/production \
    /home/devel_me/pm2 \
    /etc/nginx/sites-available \
    /home/devel_me/.env* \
    2>/dev/null

# Keep only last 7 backups
find "${BACKUP_DIR}" -name "backup-*.tar.gz" -mtime +7 -delete

echo "Backup created: ${BACKUP_FILE}"
```

```bash
# Make executable
chmod +x /home/devel_me/backup.sh

# Setup cron job (run daily at 2 AM)
sudo -u devel_me crontab -e

# Add line:
# 0 2 * * * /home/devel_me/backup.sh
```

### 9.5 Health Check Script

```bash
sudo -u devel_me nano /home/devel_me/health-check.sh
```

```bash
#!/bin/bash

# Check if all apps are running
echo "=== Health Check ==="
echo "Time: $(date)"
echo ""

# Check PM2 status
echo "PM2 Status:"
pm2 status | grep -E "prod-app|staging-app"

echo ""
echo "Port Status:"
# Production ports (3001-3003)
for port in {3001..3003}; do
    if nc -z localhost $port 2>/dev/null; then
        echo "✓ Port $port: Open"
    else
        echo "✗ Port $port: Closed"
    fi
done

echo ""
echo "HTTP Health Checks:"
for port in {3001..3003}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health)
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Port $port: Healthy ($HTTP_CODE)"
    else
        echo "✗ Port $port: Unhealthy ($HTTP_CODE)"
    fi
done

echo ""
echo "=== End Health Check ==="
```

```bash
# Make executable
chmod +x /home/devel_me/health-check.sh

# Run health check
/home/devel_me/health-check.sh
```

---

## TAHAP 10: TROUBLESHOOTING & BEST PRACTICES

### 10.1 Common Issues & Solutions

**Port already in use:**
```bash
# Find process using port
lsof -i :3001
sudo fuser -k 3001/tcp

# Or change port in PM2 config
```

**PM2 not starting on boot:**
```bash
# Reinstall startup hook
pm2 unstartup
pm2 startup
pm2 save
```

**Nginx config errors:**
```bash
# Test config
sudo nginx -t

# View error log
sudo tail -f /var/log/nginx/error.log
```

**High memory usage:**
```bash
# Check which process consuming memory
top
ps aux --sort=-%mem | head

# Increase memory restart threshold in PM2
# max_memory_restart: '1G'
```

**Git permission denied:**
```bash
# Verify SSH key permissions
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Test SSH connection
ssh -T git@github.com
```

### 10.2 Best Practices

**Security**:
- [ ] Always use SSH keys, never password authentication
- [ ] Keep secrets in `.env` files with mode 600
- [ ] Rotate SSH keys regularly
- [ ] Use firewall (UFW) for port management
- [ ] Enable SSL/HTTPS for all domains
- [ ] Keep system packages updated

**Performance**:
- [ ] Use Nginx gzip compression
- [ ] Implement caching headers
- [ ] Monitor memory and CPU usage
- [ ] Set appropriate PM2 max_memory_restart
- [ ] Use CDN for static assets

**Reliability**:
- [ ] Setup PM2 startup hooks for auto-restart
- [ ] Create backups daily
- [ ] Monitor health checks regularly
- [ ] Setup log rotation
- [ ] Keep deployment logs

**Development**:
- [ ] Use separate branches (main/production, staging, develop)
- [ ] Test builds before deployment
- [ ] Setup code review process
- [ ] Automate testing with GitHub Actions
- [ ] Document deployment process

### 10.3 Useful Commands Reference

```bash
# System
uname -a                    # System info
df -h                      # Disk usage
free -h                    # Memory usage
uptime                     # System uptime
ps aux                     # Process list
top                        # Real-time monitor

# Networking
netstat -tuln              # Open ports
curl http://localhost:3001 # Test endpoint
nc -z localhost 3001       # Port check
dig aplikasikeren.id       # DNS lookup

# Git
git status                 # Check status
git log --oneline          # View commits
git branch -a              # List branches
git diff                   # View changes
git stash                  # Save changes temporarily

# PM2
pm2 list                   # List processes
pm2 logs                   # View logs
pm2 monit                  # Monitor
pm2 restart all            # Restart all
pm2 delete all             # Delete all

# Nginx
sudo nginx -t              # Test config
sudo systemctl restart nginx
sudo systemctl status nginx
sudo tail -f /var/log/nginx/access.log

# Node.js
node --version
npm --version
npm list -g                # Global packages
npm outdated               # Check updates

# File permissions
chmod 600 file             # Read/write owner
chmod 644 file             # Read all, write owner
chmod 755 directory        # Full permissions
chown devel_me:devel_me file
```

### 10.4 Emergency Procedures

**Rollback Production**:
```bash
# 1. Stop current apps
pm2 stop all

# 2. Restore from backup
LATEST_BACKUP=$(ls -t /home/devel_me/backups/backup-*.tar.gz | head -1)
tar -xzf ${LATEST_BACKUP} -C /

# 3. Restart apps
pm2 restart all

# 4. Verify
pm2 status
```

**Emergency Restart**:
```bash
# Kill all Node processes
killall node

# Clear PM2 cache
pm2 kill

# Restart PM2
pm2 start ~/pm2/ecosystem-production.config.js

# Start PM2 daemon
pm2 start /home/devel_me/applications/production/app-dashboard/dist/index.js --name prod-app-dashboard
```

---

## TAHAP 11: QUICK REFERENCE - ESSENTIAL COMMANDS

```bash
# === DEPLOYMENT ===
sudo -u devel_me bash /home/devel_me/deploy-production.sh
sudo -u devel_me bash /home/devel_me/deploy-staging.sh

# === MONITORING ===
pm2 monit
pm2 status
/home/devel_me/health-check.sh

# === LOGS ===
pm2 logs prod-app-dashboard --lines 100
sudo tail -f /home/devel_me/logs/nginx/aplikasikeren-production-access.log

# === MANAGEMENT ===
pm2 restart all
pm2 reload prod-app-dashboard
pm2 delete prod-app-dashboard

# === NGINX ===
sudo nginx -t && sudo systemctl restart nginx

# === BACKUPS ===
/home/devel_me/backup.sh

# === GIT ===
cd ~/applications/production/app-dashboard && git status
```

---

## TAHAP 12: NEXT STEPS UNTUK DEVELOPMENT TEAM

1. **Setup Local Development**:
   - Install Node.js (sama versi di VPS)
   - Setup Git SSH keys
   - Clone repositories

2. **VSCode Remote Setup**:
   - Install "Remote - SSH" extension
   - Add to `~/.ssh/config`:
     ```
     Host vps-production
         HostName yourvps-ippub
         User devel_me
         IdentityFile ~/.ssh/your-key
     ```

3. **GitHub Workflow**:
   - Create feature branches from `develop`
   - Push to GitHub
   - Code review
   - Merge to `develop`
   - Deploy to staging
   - After testing, merge to `main`
   - Deploy to production

4. **Database Management**:
   - All data via Supabase API
   - Connection strings in `.env`
   - No direct database access needed

---

## Summary Configuration Files

**File Locations**:
- Nginx: `/etc/nginx/sites-available/`
- PM2: `/home/devel_me/pm2/ecosystem-*.config.js`
- Apps: `/home/devel_me/applications/{staging,production}/`
- Logs: `/home/devel_me/logs/`
- Backups: `/home/devel_me/backups/`

**Key Credentials** (Keep secure!):
- SSH key: `~/.ssh/github_vps`
- SSL certs: `/etc/letsencrypt/live/`
- Environment vars: `.env` files (600 permissions)

**Ports**:
- Production: 3001-3020 (apps), 4001-4020 (APIs)
- Staging: 3101-3120 (apps), 4101-4120 (APIs)
- Nginx: 80, 443
- SSH: 22

---

*Last Updated: 2026-07-07*  
*VPS Provider: Tencent Cloud*  
*OS: Ubuntu 24.04 LTS*
