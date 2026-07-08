#!/bin/bash

################################################################################
# TAHAP 8: Deploy Aplikasi dari GitHub (ADAPTIVE - v4)
# Ubuntu 24.04 LTS
#
# BARU: Adaptive structure detection untuk:
#   - Full-stack (backend + frontend dalam 1 repo)
#   - Monorepo (backend & frontend terpisah)
#   - Backend-only
#   - Frontend-only
#
# Workflow: repos (source) → staging (test) → production (live)
#
# Usage:
#   bash tahap8-deploy-adaptive-v4.sh --app aplikasi1 --repo git@github.com:user/app.git --env production
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# App structure variables
DETECTED_TYPE=""
BACKEND_DIR=""
FRONTEND_DIR=""

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

print_header "TAHAP 8: Deploy Aplikasi dari GitHub (ADAPTIVE)"

# ============================================================================
# SECTION 1: Collect Configuration
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

mkdir -p "$REPOS_DIR" "$STAGING_DIR" "$PRODUCTION_DIR"
print_success "Main directories verified"

if [ "$DEPLOY_ENV" = "staging" ]; then
    TARGET_DIR="$STAGING_DIR/$APP_NAME"
else
    TARGET_DIR="$PRODUCTION_DIR/$APP_NAME"
fi

REPO_SOURCE="$REPOS_DIR/$APP_NAME"

print_success "Repository source: $REPO_SOURCE"
print_success "Deploy target: $TARGET_DIR"

# ============================================================================
# SECTION 3: Manage Repository Source
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
# SECTION 4: DETECT APPLICATION STRUCTURE
# ============================================================================
print_header "4. Detect Application Structure"

print_info "Analyzing directory structure..."

# Check root level
if [ -f "$REPO_SOURCE/package.json" ]; then
    print_info "Found package.json di root"
    
    if grep -qE "express|fastify|hapi|koa|@nestjs|typeorm|sequelize|mongodb|mongoose|pg|mysql" "$REPO_SOURCE/package.json" 2>/dev/null; then
        BACKEND_MARKER=1
    else
        BACKEND_MARKER=0
    fi
    
    if grep -qE "react|vue|angular|svelte|next|nuxt|gatsby|@remix|astro" "$REPO_SOURCE/package.json" 2>/dev/null; then
        FRONTEND_MARKER=1
    else
        FRONTEND_MARKER=0
    fi
    
    if [ $BACKEND_MARKER -eq 1 ] && [ $FRONTEND_MARKER -eq 1 ]; then
        DETECTED_TYPE="fullstack-single"
    elif [ $BACKEND_MARKER -eq 1 ]; then
        DETECTED_TYPE="backend-only"
    elif [ $FRONTEND_MARKER -eq 1 ]; then
        DETECTED_TYPE="frontend-only"
    else
        DETECTED_TYPE="generic-nodejs"
    fi
    
    print_success "Detected: $DETECTED_TYPE (Root level)"
else
    # Check subdirectories untuk monorepo
    print_info "No root package.json, checking subdirectories..."
    
    BACKEND_CANDIDATES=("backend" "server" "api" "packages/backend" "apps/backend")
    FRONTEND_CANDIDATES=("frontend" "client" "web" "app" "packages/frontend" "apps/frontend")
    
    for candidate in "${BACKEND_CANDIDATES[@]}"; do
        if [ -f "$REPO_SOURCE/$candidate/package.json" ]; then
            if grep -qE "express|fastify|hapi|koa|@nestjs|typeorm" "$REPO_SOURCE/$candidate/package.json" 2>/dev/null; then
                BACKEND_DIR="$candidate"
                print_info "Found backend: $candidate"
                break
            fi
        fi
    done
    
    for candidate in "${FRONTEND_CANDIDATES[@]}"; do
        if [ -f "$REPO_SOURCE/$candidate/package.json" ]; then
            if grep -qE "react|vue|angular|svelte|next|nuxt" "$REPO_SOURCE/$candidate/package.json" 2>/dev/null; then
                FRONTEND_DIR="$candidate"
                print_info "Found frontend: $candidate"
                break
            fi
        fi
    done
    
    if [ -n "$BACKEND_DIR" ] && [ -n "$FRONTEND_DIR" ]; then
        DETECTED_TYPE="fullstack-monorepo"
    elif [ -n "$BACKEND_DIR" ]; then
        DETECTED_TYPE="backend-monorepo"
    elif [ -n "$FRONTEND_DIR" ]; then
        DETECTED_TYPE="frontend-monorepo"
    else
        print_error "Tidak bisa mendeteksi struktur aplikasi"
        print_info "Checking if root has any package.json..."
        DETECTED_TYPE="unknown"
    fi
    
    if [ "$DETECTED_TYPE" != "unknown" ]; then
        print_success "Detected: $DETECTED_TYPE (Monorepo)"
    fi
fi

[ -n "$BACKEND_DIR" ] && print_info "Backend dir: $BACKEND_DIR"
[ -n "$FRONTEND_DIR" ] && print_info "Frontend dir: $FRONTEND_DIR"

# ============================================================================
# SECTION 5: Copy dari Repository ke Target Environment
# ============================================================================
print_header "5. Copy Aplikasi ke $DEPLOY_ENV"

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

# ============================================================================
# SECTION 6: Setup Environment Variables
# ============================================================================
print_header "6. Setup Environment Variables"

case $DETECTED_TYPE in
    fullstack-single|backend-only|frontend-only|generic-nodejs)
        INSTALL_ROOT="$TARGET_DIR"
        ENV_FILE="$TARGET_DIR/.env"
        ;;
    fullstack-monorepo)
        INSTALL_ROOT="$TARGET_DIR"
        ENV_FILE="$TARGET_DIR/.env"
        BACKEND_ENV="$TARGET_DIR/$BACKEND_DIR/.env"
        FRONTEND_ENV="$TARGET_DIR/$FRONTEND_DIR/.env"
        ;;
    backend-monorepo)
        INSTALL_ROOT="$TARGET_DIR/$BACKEND_DIR"
        ENV_FILE="$INSTALL_ROOT/.env"
        ;;
    frontend-monorepo)
        INSTALL_ROOT="$TARGET_DIR/$FRONTEND_DIR"
        ENV_FILE="$INSTALL_ROOT/.env"
        ;;
    unknown)
        INSTALL_ROOT="$TARGET_DIR"
        ENV_FILE="$TARGET_DIR/.env"
        ;;
esac

# Create or update .env
if [ ! -f "$ENV_FILE" ]; then
    # Check for .env.example
    ENV_EXAMPLE="${ENV_FILE}.example"
    
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
else
    print_success ".env sudah ada"
fi

# Offer to edit
read -p "Edit .env file? (y/n): " EDIT_ENV
if [ "$EDIT_ENV" = "y" ]; then
    nano "$ENV_FILE"
fi

# For monorepo, setup backend/frontend .env too
if [ "$DETECTED_TYPE" = "fullstack-monorepo" ]; then
    if [ ! -f "$BACKEND_ENV" ]; then
        cp "$ENV_FILE" "$BACKEND_ENV" || print_info ".env untuk backend dibuat dari root"
    fi
    if [ ! -f "$FRONTEND_ENV" ]; then
        cp "$ENV_FILE" "$FRONTEND_ENV" || print_info ".env untuk frontend dibuat dari root"
    fi
fi

print_success "Environment setup complete"

# ============================================================================
# SECTION 7: Install Dependencies (ADAPTIVE)
# ============================================================================
print_header "7. Install Dependencies (Adaptive)"

if [ "$SKIP_INSTALL" = true ]; then
    print_warning "Skipping npm install (--skip-install flag)"
else
    case $DETECTED_TYPE in
        fullstack-single|backend-only|frontend-only|generic-nodejs)
            print_info "Installing for single app: $INSTALL_ROOT"
            
            if [ ! -f "$INSTALL_ROOT/package.json" ]; then
                print_error "package.json tidak ditemukan di $INSTALL_ROOT"
                exit 1
            fi
            
            cd "$INSTALL_ROOT"
            print_info "Running npm ci..."
            npm ci
            print_success "Dependencies installed"
            ;;
        
        fullstack-monorepo)
            print_info "Monorepo detected: Installing backend dan frontend"
            
            # Backend
            print_info "Installing backend dependencies..."
            if [ ! -f "$TARGET_DIR/$BACKEND_DIR/package.json" ]; then
                print_error "Backend package.json tidak ditemukan"
                exit 1
            fi
            cd "$TARGET_DIR/$BACKEND_DIR"
            npm ci
            print_success "Backend dependencies installed"
            
            # Frontend
            print_info "Installing frontend dependencies..."
            if [ ! -f "$TARGET_DIR/$FRONTEND_DIR/package.json" ]; then
                print_error "Frontend package.json tidak ditemukan"
                exit 1
            fi
            cd "$TARGET_DIR/$FRONTEND_DIR"
            npm ci
            print_success "Frontend dependencies installed"
            ;;
        
        backend-monorepo)
            print_info "Backend monorepo: Installing dari $BACKEND_DIR"
            
            if [ ! -f "$INSTALL_ROOT/package.json" ]; then
                print_error "Backend package.json tidak ditemukan"
                exit 1
            fi
            cd "$INSTALL_ROOT"
            npm ci
            print_success "Backend dependencies installed"
            ;;
        
        frontend-monorepo)
            print_info "Frontend monorepo: Installing dari $FRONTEND_DIR"
            
            if [ ! -f "$INSTALL_ROOT/package.json" ]; then
                print_error "Frontend package.json tidak ditemukan"
                exit 1
            fi
            cd "$INSTALL_ROOT"
            npm ci
            print_success "Frontend dependencies installed"
            ;;
        
        unknown)
            print_warning "Struktur tidak terdeteksi, mencoba install dari root..."
            
            if [ ! -f "$TARGET_DIR/package.json" ]; then
                print_error "package.json tidak ditemukan"
                print_info "Pastikan repo struktur salah satu dari:"
                print_info "  - Root level dengan package.json"
                print_info "  - Subdirektori: backend/, server/, api/"
                print_info "  - Subdirektori: frontend/, client/, web/"
                exit 1
            fi
            
            cd "$TARGET_DIR"
            npm ci
            print_success "Dependencies installed (generic mode)"
            ;;
    esac
fi

# ============================================================================
# SECTION 8: Build Application
# ============================================================================
print_header "8. Build Aplikasi"

case $DETECTED_TYPE in
    fullstack-single|backend-only|frontend-only|generic-nodejs)
        if [ -f "$INSTALL_ROOT/package.json" ]; then
            if grep -q '"build"' "$INSTALL_ROOT/package.json"; then
                print_info "Running npm run build..."
                cd "$INSTALL_ROOT"
                npm run build
                print_success "Aplikasi berhasil di-build"
            else
                print_warning "Build script tidak ditemukan"
            fi
        fi
        ;;
    
    fullstack-monorepo)
        # Build backend
        if [ -f "$TARGET_DIR/$BACKEND_DIR/package.json" ] && grep -q '"build"' "$TARGET_DIR/$BACKEND_DIR/package.json"; then
            print_info "Building backend..."
            cd "$TARGET_DIR/$BACKEND_DIR"
            npm run build
            print_success "Backend built"
        fi
        
        # Build frontend
        if [ -f "$TARGET_DIR/$FRONTEND_DIR/package.json" ] && grep -q '"build"' "$TARGET_DIR/$FRONTEND_DIR/package.json"; then
            print_info "Building frontend..."
            cd "$TARGET_DIR/$FRONTEND_DIR"
            npm run build
            print_success "Frontend built"
        fi
        ;;
    
    backend-monorepo)
        if [ -f "$INSTALL_ROOT/package.json" ] && grep -q '"build"' "$INSTALL_ROOT/package.json"; then
            print_info "Building backend..."
            cd "$INSTALL_ROOT"
            npm run build
            print_success "Backend built"
        fi
        ;;
    
    frontend-monorepo)
        if [ -f "$INSTALL_ROOT/package.json" ] && grep -q '"build"' "$INSTALL_ROOT/package.json"; then
            print_info "Building frontend..."
            cd "$INSTALL_ROOT"
            npm run build
            print_success "Frontend built"
        fi
        ;;
esac

# ============================================================================
# SECTION 9: Configure PM2
# ============================================================================
print_header "9. Configure PM2"

PM2_NAME="$APP_NAME"
if [ "$DEPLOY_ENV" = "staging" ]; then
    PM2_NAME="staging-${APP_NAME}"
fi

PM2_CONFIG_DIR="/home/$DEV_USER/pm2-configs"
mkdir -p "$PM2_CONFIG_DIR"

PM2_APP_CONFIG="$PM2_CONFIG_DIR/${APP_NAME}.js"

# Determine entry point based on app structure
case $DETECTED_TYPE in
    fullstack-single|backend-only|generic-nodejs)
        # Single backend app
        ENTRY_POINT="./dist/index.js"
        if [ ! -f "$INSTALL_ROOT/dist/index.js" ] && [ -f "$INSTALL_ROOT/dist/server.js" ]; then
            ENTRY_POINT="./dist/server.js"
        fi
        ;;
    frontend-only|frontend-monorepo)
        # Frontend - usually starts with npm start
        ENTRY_POINT="./dist/index.js"
        ;;
    *)
        ENTRY_POINT="./dist/index.js"
        ;;
esac

cat > "$PM2_APP_CONFIG" << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    cwd: '$INSTALL_ROOT',
    script: '$ENTRY_POINT',
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

# ============================================================================
# SECTION 10: Start Application with PM2
# ============================================================================
print_header "10. Start Aplikasi dengan PM2"

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

pm2 save
print_success "PM2 config disimpan"

# ============================================================================
# SECTION 11: Health Check
# ============================================================================
print_header "11. Health Check"

print_info "Checking if application is responding..."
sleep 3

if netstat -tuln | grep -q ":$APP_PORT "; then
    print_success "Port $APP_PORT is listening ✓"
else
    print_error "Port $APP_PORT is not listening ✗"
    print_info "PM2 logs:"
    pm2 logs "$PM2_NAME" --lines 20
    exit 1
fi

if curl -s http://localhost:$APP_PORT > /dev/null 2>&1; then
    print_success "HTTP health check passed ✓"
else
    print_warning "HTTP health check failed (aplikasi mungkin belum siap)"
fi

# ============================================================================
# SECTION 12: Summary
# ============================================================================
print_header "✓ TAHAP 8 Selesai! (ADAPTIVE)"

echo ""
echo -e "${CYAN}Application Structure:${NC}"
echo "  Type: $DETECTED_TYPE"
[ -n "$BACKEND_DIR" ] && echo "  Backend: $BACKEND_DIR"
[ -n "$FRONTEND_DIR" ] && echo "  Frontend: $FRONTEND_DIR"
echo ""

echo -e "${CYAN}Deployment Information:${NC}"
echo "  Aplikasi: $APP_NAME"
echo "  Environment: $DEPLOY_ENV"
echo "  Port: $APP_PORT"
echo "  Source: $REPO_SOURCE"
echo "  Target: $TARGET_DIR"
echo "  PM2 Process: $PM2_NAME"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo ""
if [ "$DEPLOY_ENV" = "staging" ]; then
    echo "1. Test di staging"
    echo "2. View logs: pm2 logs $PM2_NAME"
    echo "3. Deploy to production:"
    echo "   bash tahap8-deploy-adaptive-v4.sh --app $APP_NAME --env production --update"
else
    echo "1. Link Nginx configuration"
    echo "2. Test akses aplikasi"
    echo "3. Monitor: pm2 monit"
fi
echo ""

echo -e "${GREEN}Aplikasi $APP_NAME berhasil di-deploy! ✓${NC}\n"
