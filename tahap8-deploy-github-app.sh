#!/bin/bash

################################################################################
# TAHAP 8: Deploy GitHub Application
# Ubuntu 24.04 LTS - Multi-App Deployment
#
# Script ini menghandle:
# - Clone repository dari GitHub (fresh atau update existing)
# - Setup environment variables
# - Install dependencies (npm)
# - Build aplikasi (jika diperlukan)
# - Start/restart dengan PM2
# - Health check setelah deploy
#
# Usage: 
#   Fresh deployment:
#     bash tahap8-deploy-github-app.sh
#   
#   Update existing app:
#     bash tahap8-deploy-github-app.sh --app aplikasi1 --update
#   
#   Deploy multiple apps:
#     bash tahap8-deploy-github-app.sh --app aplikasi1
#     bash tahap8-deploy-github-app.sh --app aplikasi2
#
# Prerequisites:
#   - Tahap 1-7 sudah completed
#   - GitHub SSH key sudah configured (tahap 3)
#   - PM2 ecosystem config sudah ada
#
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if running as development user (not root)
if [[ $EUID -eq 0 ]]; then
    print_error "Script ini harus dijalankan sebagai development user (bukan sudo)"
    echo "Usage: bash tahap8-deploy-github-app.sh"
    exit 1
fi

# Default values
UPDATE_ONLY=false
DEV_USER=$(whoami)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            APP_NAME="$2"
            shift 2
            ;;
        --update)
            UPDATE_ONLY=true
            shift
            ;;
        --repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

print_header "TAHAP 8: Deploy GitHub Application"

# ============================================================================
# SECTION 1: Get Configuration Information
# ============================================================================
print_header "1. Konfigurasi Aplikasi"

# Get app name
if [ -z "$APP_NAME" ]; then
    read -p "Nama aplikasi [aplikasi1]: " APP_NAME
    APP_NAME=${APP_NAME:-aplikasi1}
fi

print_success "Aplikasi: $APP_NAME"

# Extract app number from name (aplikasi1 -> 1)
APP_NUM=$(echo "$APP_NAME" | sed 's/[^0-9]*//g')
if [ -z "$APP_NUM" ]; then
    APP_NUM=1
fi

APP_PORT=$((3000 + APP_NUM))

print_success "Port: $APP_PORT"

# Get GitHub repository
if [ -z "$GITHUB_REPO" ]; then
    read -p "GitHub repository URL (git@github.com:username/repo.git): " GITHUB_REPO
    if [ -z "$GITHUB_REPO" ]; then
        print_error "GitHub repository URL diperlukan"
        exit 1
    fi
fi

print_success "Repository: $GITHUB_REPO"

# ============================================================================
# SECTION 2: Setup Application Directory
# ============================================================================
print_header "2. Setup Direktori Aplikasi"

APPS_DIR="/home/$DEV_USER/apps"
APP_REPO_DIR="$APPS_DIR/repos/$APP_NAME"
APP_PROD_DIR="$APPS_DIR/production/$APP_NAME"

# Create directories if not exist
mkdir -p "$APPS_DIR/repos"
mkdir -p "$APPS_DIR/production"

print_success "Directories siap: $APPS_DIR"

# ============================================================================
# SECTION 3: Clone or Update Repository
# ============================================================================
print_header "3. Clone/Update Repository dari GitHub"

if [ -d "$APP_REPO_DIR/.git" ]; then
    print_info "Repository sudah ada, melakukan update..."
    
    cd "$APP_REPO_DIR"
    git fetch origin
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
    
    print_success "Repository diupdate"
else
    print_info "Melakukan clone repository..."
    
    git clone "$GITHUB_REPO" "$APP_REPO_DIR"
    
    if [ ! -d "$APP_REPO_DIR" ]; then
        print_error "Clone gagal. Periksa GitHub URL dan SSH key"
        exit 1
    fi
    
    print_success "Repository di-clone: $APP_REPO_DIR"
fi

cd "$APP_REPO_DIR"

# Get latest commit info
COMMIT_HASH=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B)

print_info "Commit: $COMMIT_HASH - $COMMIT_MSG"

# ============================================================================
# SECTION 4: Setup Environment File
# ============================================================================
print_header "4. Setup Environment Variables"

ENV_FILE="$APP_PROD_DIR/.env"

# Create production directory
mkdir -p "$APP_PROD_DIR"

# Check if template exists
if [ -f "$APP_REPO_DIR/.env.example" ]; then
    print_info "Menggunakan .env.example dari repository"
    cp "$APP_REPO_DIR/.env.example" "$ENV_FILE"
elif [ -f "/home/$DEV_USER/pm2-configs/${APP_NAME}.env" ]; then
    print_info "Menggunakan template dari pm2-configs"
    cp "/home/$DEV_USER/pm2-configs/${APP_NAME}.env" "$ENV_FILE"
else
    print_info "Membuat .env file baru"
    cat > "$ENV_FILE" << EOF
# Environment untuk $APP_NAME
NODE_ENV=production
PORT=$APP_PORT
APP_NAME=$APP_NAME
APP_URL=https://$APP_NAME.sv1.thinking.my.id

# Database (optional, adjust sesuai kebutuhan)
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=$APP_NAME
# DB_USER=$DEV_USER
# DB_PASSWORD=your_password

# API Keys (optional)
# API_KEY=your_api_key
# SECRET_KEY=your_secret_key

# Logging
LOG_LEVEL=info
LOG_DIR=/home/$DEV_USER/apps/logs/$APP_NAME
EOF
fi

# Prompt to customize .env
echo -e "\n${YELLOW}Environment file dibuat: $ENV_FILE${NC}"
read -p "Edit .env file sekarang? (y/n) [default: n]: " EDIT_ENV
EDIT_ENV=${EDIT_ENV:-n}

if [ "$EDIT_ENV" = "y" ] || [ "$EDIT_ENV" = "Y" ]; then
    nano "$ENV_FILE"
fi

print_success "Environment file siap"

# ============================================================================
# SECTION 5: Install Dependencies
# ============================================================================
print_header "5. Install Dependencies"

cd "$APP_REPO_DIR"

# Check Node.js version
NODE_VERSION=$(node -v)
NPM_VERSION=$(npm -v)

print_info "Node.js: $NODE_VERSION"
print_info "NPM: $NPM_VERSION"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    print_error "package.json tidak ditemukan di repository"
    exit 1
fi

# Install dependencies
print_info "Menginstall dependencies (ini mungkin butuh beberapa menit)..."

npm install --production 2>&1 | tail -5

if [ -d "node_modules" ]; then
    DEPS_COUNT=$(ls node_modules | wc -l)
    print_success "Dependencies terinstall: $DEPS_COUNT packages"
else
    print_error "Instalasi dependencies gagal"
    exit 1
fi

# ============================================================================
# SECTION 6: Build Application (if needed)
# ============================================================================
print_header "6. Build Aplikasi"

if grep -q '"build"' package.json; then
    print_info "Build script ditemukan di package.json"
    
    read -p "Jalankan build script? (y/n) [default: y]: " RUN_BUILD
    RUN_BUILD=${RUN_BUILD:-y}
    
    if [ "$RUN_BUILD" = "y" ] || [ "$RUN_BUILD" = "Y" ]; then
        print_info "Menjalankan npm run build..."
        npm run build 2>&1 | tail -10
        
        if [ $? -eq 0 ]; then
            print_success "Build completed"
        else
            print_warning "Build completed dengan warning/error"
        fi
    fi
else
    print_info "Tidak ada build script di package.json"
fi

# ============================================================================
# SECTION 7: Copy to Production Directory
# ============================================================================
print_header "7. Persiapan Production Directory"

print_info "Copying files to production directory..."

# Copy source code
rsync -av --exclude='node_modules' --exclude='.git' \
    "$APP_REPO_DIR/" "$APP_PROD_DIR/" > /dev/null 2>&1

# Create node_modules symlink to save disk space (optional)
if [ -d "$APP_REPO_DIR/node_modules" ]; then
    rm -rf "$APP_PROD_DIR/node_modules" 2>/dev/null || true
    ln -sf "$APP_REPO_DIR/node_modules" "$APP_PROD_DIR/node_modules"
    print_info "node_modules symlinked (hemat disk space)"
fi

# Create logs directory
mkdir -p "/home/$DEV_USER/apps/logs/$APP_NAME"
chmod 755 "/home/$DEV_USER/apps/logs/$APP_NAME"

print_success "Production directory siap: $APP_PROD_DIR"

# ============================================================================
# SECTION 8: PM2 Configuration
# ============================================================================
print_header "8. Setup PM2 Configuration"

PM2_CONFIG="/home/$DEV_USER/pm2-configs/${APP_NAME}.config.js"

if [ ! -f "$PM2_CONFIG" ]; then
    print_info "Membuat PM2 config untuk $APP_NAME..."
    
    cat > "$PM2_CONFIG" << 'PM2_EOF'
module.exports = {
  apps: [{
    name: 'APP_NAME_PLACEHOLDER',
    script: 'npm',
    args: 'start',
    cwd: 'APP_DIR_PLACEHOLDER',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: APP_PORT_PLACEHOLDER
    },
    error_file: '/home/DEV_USER_PLACEHOLDER/apps/logs/APP_NAME_PLACEHOLDER/error.log',
    out_file: '/home/DEV_USER_PLACEHOLDER/apps/logs/APP_NAME_PLACEHOLDER/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    max_memory_restart: '500M',
    min_uptime: '10s',
    max_restarts: 10,
    autorestart: true,
    watch: false,
    merge_logs: true,
    ignore_watch: ['node_modules', 'logs', '.git']
  }]
};
PM2_EOF
    
    # Replace placeholders
    sed -i "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" "$PM2_CONFIG"
    sed -i "s|APP_DIR_PLACEHOLDER|$APP_PROD_DIR|g" "$PM2_CONFIG"
    sed -i "s/APP_PORT_PLACEHOLDER/$APP_PORT/g" "$PM2_CONFIG"
    sed -i "s/DEV_USER_PLACEHOLDER/$DEV_USER/g" "$PM2_CONFIG"
    
    print_success "PM2 config dibuat: $PM2_CONFIG"
else
    print_success "PM2 config sudah ada: $PM2_CONFIG"
fi

# ============================================================================
# SECTION 9: Start/Restart Application with PM2
# ============================================================================
print_header "9. Start/Restart Aplikasi dengan PM2"

print_info "Checking PM2 status..."

# Check if app already running
if pm2 list | grep -q "$APP_NAME"; then
    print_info "Aplikasi $APP_NAME sudah running, melakukan restart..."
    pm2 restart "$APP_NAME"
    
    sleep 2
    PM2_STATUS=$(pm2 list | grep "$APP_NAME" | awk '{print $12}')
    
    if [ "$PM2_STATUS" = "online" ]; then
        print_success "Aplikasi di-restart: $APP_NAME (status: online)"
    else
        print_warning "Aplikasi di-restart, tapi status: $PM2_STATUS"
    fi
else
    print_info "Starting aplikasi $APP_NAME untuk pertama kali..."
    pm2 start "$PM2_CONFIG"
    
    sleep 2
    PM2_STATUS=$(pm2 list | grep "$APP_NAME" | awk '{print $12}')
    
    if [ "$PM2_STATUS" = "online" ]; then
        print_success "Aplikasi started: $APP_NAME (status: online)"
    else
        print_warning "Aplikasi started, tapi status: $PM2_STATUS"
    fi
fi

# Save PM2 config
pm2 save

print_success "PM2 config disimpan"

# ============================================================================
# SECTION 10: Health Check
# ============================================================================
print_header "10. Health Check"

print_info "Waiting for application to be ready..."
sleep 3

# Check if port is listening
if netstat -tuln | grep -q ":$APP_PORT "; then
    print_success "Aplikasi listening di port $APP_PORT"
else
    print_warning "Port $APP_PORT tidak listening. Check logs: pm2 logs $APP_NAME"
fi

# Test HTTP endpoint
print_info "Testing HTTP endpoint..."

HEALTH_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$APP_PORT/ 2>/dev/null || echo "000")

if [ "$HEALTH_TEST" = "200" ] || [ "$HEALTH_TEST" = "301" ] || [ "$HEALTH_TEST" = "302" ]; then
    print_success "HTTP endpoint responding: $HEALTH_TEST"
else
    print_warning "HTTP endpoint returned: $HEALTH_TEST"
fi

# ============================================================================
# SECTION 11: Enable Nginx for Application
# ============================================================================
print_header "11. Enable Nginx Configuration"

echo -e "\n${YELLOW}Aplikasi sudah ready. Untuk enable di Nginx, pilih salah satu:${NC}\n"

echo "Path-based routing (https://sv1.thinking.my.id/$APP_NAME):"
echo "  sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-path /etc/nginx/sites-enabled/"
echo ""

echo "Subdomain-based routing (https://${APP_NAME}.sv1.thinking.my.id):"
echo "  sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-subdomain /etc/nginx/sites-enabled/"
echo ""

echo "Hybrid (both):"
echo "  sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-hybrid /etc/nginx/sites-enabled/"
echo ""

echo "Kemudian reload Nginx:"
echo "  sudo systemctl reload nginx"
echo ""

# ============================================================================
# SECTION 12: Summary
# ============================================================================
print_header "12. Deployment Summary"

echo -e "${BLUE}Aplikasi Information:${NC}\n"
echo "    Nama:               $APP_NAME"
echo "    Port:               $APP_PORT"
echo "    Repository:         $GITHUB_REPO"
echo "    Commit:             $COMMIT_HASH"
echo ""

echo -e "${BLUE}Direktori:${NC}\n"
echo "    Repository:         $APP_REPO_DIR"
echo "    Production:         $APP_PROD_DIR"
echo "    Environment:        $ENV_FILE"
echo "    Logs:               /home/$DEV_USER/apps/logs/$APP_NAME"
echo ""

echo -e "${BLUE}PM2 Configuration:${NC}\n"
echo "    Config file:        $PM2_CONFIG"
echo ""

echo -e "${BLUE}Useful Commands:${NC}\n"
echo "    View logs:          pm2 logs $APP_NAME"
echo "    Restart:            pm2 restart $APP_NAME"
echo "    Stop:               pm2 stop $APP_NAME"
echo "    Delete:             pm2 delete $APP_NAME"
echo "    Monitor:            pm2 monit"
echo ""

# ============================================================================
# SECTION 13: Deploy Another App (Optional)
# ============================================================================
print_header "13. Langkah Selanjutnya"

echo -e "${GREEN}✓ Deployment $APP_NAME completed!${NC}\n"

echo -e "${YELLOW}Next steps:${NC}\n"
echo "1. Enable Nginx (pilih path/subdomain/hybrid)"
echo "2. Reload Nginx: sudo systemctl reload nginx"
echo "3. Test aplikasi:"
echo "   - Path: https://sv1.thinking.my.id/$APP_NAME"
echo "   - Subdomain: https://$APP_NAME.sv1.thinking.my.id"
echo ""
echo "Deploy aplikasi lain:"
echo "   bash tahap8-deploy-github-app.sh --app aplikasi2"
echo ""

print_header "✓ TAHAP 8 - $APP_NAME Completed"

exit 0
