#!/bin/bash

################################################################################
# TAHAP 8: Deploy Aplikasi dari GitHub
# Ubuntu 24.04 LTS
#
# Workflow: repos (source) → staging (test) → production (live)
#
# Script ini mengkonfigurasi:
# - Clone/pull repository dari GitHub ke repos/
# - Copy ke staging/ atau production/
# - Setup environment variables (.env)
# - Install dependencies (npm install)
# - Build aplikasi (npm run build)
# - Configure PM2
# - Health check
#
# Usage:
#   # Deploy pertama kali (staging)
#   bash tahap8-deploy-github-app.sh --app aplikasi1 --repo git@github.com:user/app.git --env staging
#
#   # Deploy ke production setelah staging OK
#   bash tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
#
#   # Update aplikasi yang sudah ada
#   bash tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Default values
APP_NAME=""
GITHUB_REPO=""
DEV_USER="develme_rf"
APPS_BASE_DIR="/home/$DEV_USER/apps"
REPOS_DIR="$APPS_BASE_DIR/repos"
STAGING_DIR="$APPS_BASE_DIR/staging"
PRODUCTION_DIR="$APPS_BASE_DIR/production"
DEPLOY_ENV="production"
APP_PORT=""
UPDATE_ONLY=false
SKIP_INSTALL=false
OPTIMIZE_NODE_MODULES=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app) APP_NAME="$2"; shift 2 ;;
        --repo) GITHUB_REPO="$2"; shift 2 ;;
        --env) DEPLOY_ENV="$2"; shift 2 ;;
        --update) UPDATE_ONLY=true; shift ;;
        --skip-install) SKIP_INSTALL=true; shift ;;
        --no-optimize) OPTIMIZE_NODE_MODULES=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

print_header "TAHAP 8: Deploy Aplikasi dari GitHub"

# ============================================================================
# SECTION 1: Collect Configuration Information
# ============================================================================
print_header "1. Informasi Aplikasi"

if [ -z "$APP_NAME" ]; then
    read -p "Nama aplikasi [default: aplikasi1]: " APP_NAME
    APP_NAME=${APP_NAME:-aplikasi1}
fi

print_success "Aplikasi: $APP_NAME"

# Calculate port
APP_NUM=$(echo $APP_NAME | sed 's/aplikasi//')
APP_PORT=$((3000 + APP_NUM))

# Validate DEPLOY_ENV
if [[ ! "$DEPLOY_ENV" =~ ^(staging|production)$ ]]; then
    DEPLOY_ENV="production"
fi

# If not update-only, ask for repository
if [ "$UPDATE_ONLY" = false ] && [ -z "$GITHUB_REPO" ]; then
    echo ""
    read -p "GitHub repository URL (git@github.com:user/repo.git): " GITHUB_REPO
    
    if [ -z "$GITHUB_REPO" ]; then
        print_error "Repository URL tidak boleh kosong"
        exit 1
    fi
fi

[ -n "$GITHUB_REPO" ] && print_success "Repository: $GITHUB_REPO"

# Ask for environment if not specified
if [ "$UPDATE_ONLY" = false ]; then
    echo ""
    echo "Pilih environment:"
    echo "1) staging (untuk testing)"
    echo "2) production (live)"
    read -p "Pilihan [default: 2 (production)]: " ENV_CHOICE
    ENV_CHOICE=${ENV_CHOICE:-2}
    
    case $ENV_CHOICE in
        1) DEPLOY_ENV="staging" ;;
        2) DEPLOY_ENV="production" ;;
        *) DEPLOY_ENV="production" ;;
    esac
fi

print_success "Deploy Environment: $DEPLOY_ENV"
print_success "Port: $APP_PORT"

# ============================================================================
# SECTION 2: Setup Directory Structure
# ============================================================================
print_header "2. Setup Directory Structure"

# Ensure main directories exist
mkdir -p "$REPOS_DIR" "$STAGING_DIR" "$PRODUCTION_DIR"
print_success "Main directories verified"

# Setup target directory based on environment
if [ "$DEPLOY_ENV" = "staging" ]; then
    TARGET_DIR="$STAGING_DIR/$APP_NAME"
else
    TARGET_DIR="$PRODUCTION_DIR/$APP_NAME"
fi

REPO_SOURCE="$REPOS_DIR/$APP_NAME"

print_success "Repository source: $REPO_SOURCE"
print_success "Deploy target: $TARGET_DIR"

# ============================================================================
# SECTION 3: Manage Repository Source (repos/)
# ============================================================================
print_header "3. Setup Repository Source"

if [ "$UPDATE_ONLY" = false ] && [ -n "$GITHUB_REPO" ]; then
    if [ ! -d "$REPO_SOURCE/.git" ]; then
        print_info "Cloning repository..."
        git clone "$GITHUB_REPO" "$REPO_SOURCE"
        print_success "Repository di-clone: $REPO_SOURCE"
    else
        print_warning "Repository sudah ada di: $REPO_SOURCE"
        read -p "Update ke latest version? (y/n): " UPDATE_REPO
        if [ "$UPDATE_REPO" = "y" ]; then
            cd "$REPO_SOURCE"
            git pull origin main 2>/dev/null || git pull origin master
            print_success "Repository di-update"
        fi
    fi
else
    if [ ! -d "$REPO_SOURCE/.git" ]; then
        print_error "Repository tidak ditemukan di: $REPO_SOURCE"
        print_error "Gunakan --repo untuk clone pertama kali"
        exit 1
    fi
    print_success "Repository source ada: $REPO_SOURCE"
fi

# ============================================================================
# SECTION 4: Copy dari Repository ke Target Environment
# ============================================================================
print_header "4. Copy Aplikasi ke $DEPLOY_ENV"

print_info "Copying dari $REPO_SOURCE ke $TARGET_DIR"

if [ -d "$TARGET_DIR" ]; then
    print_warning "Target directory sudah ada: $TARGET_DIR"
    read -p "Overwrite? (y/n): " OVERWRITE
    if [ "$OVERWRITE" != "y" ]; then
        print_info "Deploy dibatalkan"
        exit 0
    fi
    rm -rf "$TARGET_DIR"
fi

cp -r "$REPO_SOURCE" "$TARGET_DIR"
print_success "Aplikasi di-copy ke: $TARGET_DIR"

# Change to target directory for rest of script
cd "$TARGET_DIR"

# ============================================================================
# SECTION 5: Setup Environment Variables
# ============================================================================
print_header "5. Setup Environment Variables"

ENV_FILE="$TARGET_DIR/.env"
ENV_EXAMPLE="$TARGET_DIR/.env.example"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        print_success ".env created from .env.example"
    else
        # Create basic .env
        cat > "$ENV_FILE" << EOF
NODE_ENV=$DEPLOY_ENV
PORT=$APP_PORT
APP_NAME=$APP_NAME
EOF
        print_success ".env created with basic settings"
    fi
    
    # Ask to edit
    read -p "Edit .env file sekarang? (y/n): " EDIT_ENV
    if [ "$EDIT_ENV" = "y" ]; then
        nano "$ENV_FILE"
    fi
else
    print_success ".env sudah ada"
    read -p "Edit .env file? (y/n): " EDIT_ENV
    if [ "$EDIT_ENV" = "y" ]; then
        nano "$ENV_FILE"
    fi
fi

print_success "Environment setup complete"

# ============================================================================
# SECTION 6: Install Dependencies
# ============================================================================
print_header "6. Install Dependencies"

if [ "$SKIP_INSTALL" = true ]; then
    print_warning "Skipping npm install (--skip-install flag)"
else
    if [ -f "package.json" ]; then
        if [ -d "node_modules" ]; then
            print_info "node_modules sudah ada, updating..."
            npm update
        else
            print_info "Installing npm dependencies..."
            npm install
        fi
        print_success "Dependencies terinstall"
    else
        print_error "package.json tidak ditemukan"
        exit 1
    fi
fi

# ============================================================================
# SECTION 6B: Optimize Node Modules (Symlink Strategy)
# ============================================================================
if [ "$OPTIMIZE_NODE_MODULES" = true ] && [ "$SKIP_INSTALL" = false ]; then
    print_header "6B. Optimize Node Modules"
    
    if [ -f "$APPS_BASE_DIR/node_modules-optimizer.sh" ]; then
        print_info "Running node_modules optimizer..."
        bash "$APPS_BASE_DIR/node_modules-optimizer.sh" "$APP_NAME" init
        print_success "Node modules optimization complete"
    else
        print_warning "node_modules-optimizer.sh not found, skipping optimization"
        print_info "To setup optimization later, run:"
        print_info "  bash $APPS_BASE_DIR/node_modules-optimizer.sh $APP_NAME init"
    fi
fi

# ============================================================================
# SECTION 7: Build Application
# ============================================================================
print_header "7. Build Aplikasi"

if [ -f "package.json" ]; then
    # Check for build script
    if grep -q '"build"' package.json; then
        print_info "Running npm run build..."
        npm run build
        print_success "Aplikasi berhasil di-build"
    else
        print_warning "Build script tidak ditemukan di package.json"
        print_info "Skipping build step"
    fi
fi

# ============================================================================
# SECTION 8: Configure PM2
# ============================================================================
print_header "8. Configure PM2"

PM2_NAME="$APP_NAME"
if [ "$DEPLOY_ENV" = "staging" ]; then
    PM2_NAME="staging-${APP_NAME}"
fi

PM2_CONFIG_DIR="/home/$DEV_USER/pm2-configs"
PM2_APP_CONFIG="$PM2_CONFIG_DIR/${APP_NAME}.js"

if [ -f "$PM2_APP_CONFIG" ]; then
    print_success "PM2 config sudah ada: $PM2_APP_CONFIG"
else
    print_info "Creating PM2 configuration..."
    
    cat > "$PM2_APP_CONFIG" << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    script: './dist/index.js',
    instances: 1,
    env: {
      NODE_ENV: '$DEPLOY_ENV',
      PORT: $APP_PORT
    },
    error_file: '/var/log/pm2/${APP_NAME}.error.log',
    out_file: '/var/log/pm2/${APP_NAME}.out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
EOF
    
    print_success "PM2 config created"
fi

# ============================================================================
# SECTION 9: Start Application with PM2
# ============================================================================
print_header "9. Start/Restart Aplikasi dengan PM2"

# Check if already running
if pm2 list | grep -q "$PM2_NAME"; then
    print_warning "Aplikasi sudah running: $PM2_NAME"
    read -p "Restart? (y/n): " RESTART
    if [ "$RESTART" = "y" ]; then
        pm2 restart "$PM2_NAME"
        print_success "Aplikasi di-restart: $PM2_NAME"
    fi
else
    print_info "Starting aplikasi: $PM2_NAME"
    pm2 start "$PM2_APP_CONFIG" --name "$PM2_NAME"
    print_success "Aplikasi started dengan PM2: $PM2_NAME"
fi

# Save PM2 config
pm2 save
print_success "PM2 config disimpan"

# ============================================================================
# SECTION 10: Health Check
# ============================================================================
print_header "10. Health Check"

print_info "Checking if application is responding..."

# Wait for application to start
sleep 3

# Check if port is listening
if netstat -tuln | grep -q ":$APP_PORT "; then
    print_success "Port $APP_PORT is listening ✓"
else
    print_error "Port $APP_PORT is not listening ✗"
    print_info "PM2 logs:"
    pm2 logs "$PM2_NAME" --lines 20
    exit 1
fi

# Try HTTP request
if curl -s http://localhost:$APP_PORT > /dev/null 2>&1; then
    print_success "HTTP health check passed ✓"
else
    print_warning "HTTP health check failed (aplikasi mungkin belum siap)"
fi

# ============================================================================
# SECTION 11: Setup Nginx Integration
# ============================================================================
print_header "11. Setup Nginx Integration"

echo ""
echo "${CYAN}Aplikasi Status:${NC}"
echo "  Nama: $APP_NAME"
echo "  Environment: $DEPLOY_ENV"
echo "  Port: $APP_PORT"
echo "  PM2 Process: $PM2_NAME"
echo ""
echo "${CYAN}Untuk mengaktifkan di Nginx:${NC}"
echo ""
echo "1. PATH-BASED routing (https://sv1.thinking.my.id/$APP_NAME):"
echo "   sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-path /etc/nginx/sites-enabled/"
echo ""
echo "2. SUBDOMAIN-BASED routing (https://${APP_NAME}.sv1.thinking.my.id):"
echo "   sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-subdomain /etc/nginx/sites-enabled/"
echo ""
echo "3. HYBRID (keduanya):"
echo "   sudo ln -s /etc/nginx/sites-available/app-${APP_NAME}-hybrid /etc/nginx/sites-enabled/"
echo ""
echo "${CYAN}Setelah itu reload nginx:${NC}"
echo "   sudo systemctl reload nginx"
echo ""

if [ "$OPTIMIZE_NODE_MODULES" = true ]; then
    echo "${CYAN}Node Modules Info:${NC}"
    echo "  Strategy: Hybrid Symlinks (repos → staging → production)"
    echo "  - repos/$APP_NAME/node_modules: Full install (dev + prod)"
    echo "  - staging/$APP_NAME/node_modules: Symlink ke repos"
    echo "  - production/$APP_NAME/node_modules: Prod-only install"
    echo ""
    echo "${CYAN}Disk Savings:${NC}"
    echo "  Expected: ~600MB per app (vs 1.5GB without optimization)"
    echo "  For 30 apps: ~18GB instead of 45GB (60% savings)"
    echo ""
    echo "${CYAN}Monitor Disk Usage:${NC}"
    echo "  bash $APPS_BASE_DIR/disk-usage-report.sh"
    echo ""
fi

# ============================================================================
# SECTION 12: Summary
# ============================================================================
print_header "12. Deployment Summary"

echo ""
echo "${CYAN}Deployment Information:${NC}"
echo "  Application: $APP_NAME"
echo "  Environment: $DEPLOY_ENV"
echo "  Port: $APP_PORT"
echo "  Source: $REPO_SOURCE"
echo "  Deploy: $TARGET_DIR"
echo "  PM2 Process: $PM2_NAME"
echo ""
echo "${CYAN}Directory Structure:${NC}"
echo "  repos/$APP_NAME ← Source (from GitHub)"
echo "  $DEPLOY_ENV/$APP_NAME ← Working copy"
echo ""
echo "${CYAN}Useful Commands:${NC}"
echo ""
echo "View logs:"
echo "  pm2 logs $PM2_NAME"
echo ""
echo "Restart:"
echo "  pm2 restart $PM2_NAME"
echo ""
echo "Monitor:"
echo "  pm2 monit"
echo ""
echo "Stop:"
echo "  pm2 stop $PM2_NAME"
echo ""
echo "View directory:"
echo "  ls -la $TARGET_DIR"
echo ""
echo "${CYAN}Next Steps:${NC}"
echo ""
if [ "$DEPLOY_ENV" = "staging" ]; then
    echo "1. Test aplikasi di staging"
    echo "2. Verify logs: pm2 logs $PM2_NAME"
    echo "3. Approve deployment"
    echo "4. Deploy to production:"
    echo "   bash tahap8-deploy-github-app.sh --app $APP_NAME --env production --update"
else
    echo "1. Link Nginx configuration (pilih path, subdomain, atau hybrid)"
    echo "2. Reload Nginx: sudo systemctl reload nginx"
    echo "3. Test akses aplikasi"
    echo "4. Monitor: pm2 monit"
fi
echo ""

print_header "✓ TAHAP 8 Selesai!"

echo -e "${GREEN}Aplikasi $APP_NAME berhasil di-deploy ke $DEPLOY_ENV!${NC}"
echo ""
echo "${CYAN}Update aplikasi kedepannya:${NC}"
echo "  bash tahap8-deploy-github-app.sh --app $APP_NAME --env $DEPLOY_ENV --update"
echo ""
echo "${CYAN}Deploy aplikasi lainnya:${NC}"
echo "  bash tahap8-deploy-github-app.sh --app aplikasi2 --repo git@github.com:user/app2.git --env production"
echo ""
echo "${CYAN}Deploy multiple apps dengan optimization:${NC}"
echo "  for i in {1..5}; do"
echo "    bash tahap8-deploy-github-app.sh --app aplikasi\$i --repo <repo-url> --env production"
echo "  done"
echo ""
echo "${CYAN}Skip optimization (use full installs):${NC}"
echo "  bash tahap8-deploy-github-app.sh --app $APP_NAME --env $DEPLOY_ENV --no-optimize"
echo ""
