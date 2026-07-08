#!/bin/bash

################################################################################
# APP STRUCTURE DETECTOR
# Detects: full-stack, separated, backend-only, frontend-only
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}$1${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

if [ -z "$1" ]; then
    print_error "Usage: $0 <app-directory>"
    exit 1
fi

APP_DIR="$1"

if [ ! -d "$APP_DIR" ]; then
    print_error "Directory tidak ditemukan: $APP_DIR"
    exit 1
fi

print_header "APP STRUCTURE DETECTOR"
print_info "Scanning: $APP_DIR"

# Check if directory is empty
if [ -z "$(ls -A "$APP_DIR")" ]; then
    print_error "Direktori kosong"
    exit 1
fi

# Helper functions
has_package_json() {
    [ -f "$1/package.json" ]
}

is_backend() {
    local dir="$1"
    grep -qE "express|fastify|hapi|koa|@nestjs|typeorm|sequelize|mongodb|mongoose|pg|mysql|\"main\"|\"server\"" "$dir/package.json" 2>/dev/null
}

is_frontend() {
    local dir="$1"
    grep -qE "react|vue|angular|svelte|next|nuxt|gatsby|@remix|astro" "$dir/package.json" 2>/dev/null
}

RESULT_TYPE=""
RESULT_DESC=""
RESULT_BACKEND_DIR=""
RESULT_FRONTEND_DIR=""

# Check root level
if has_package_json "$APP_DIR"; then
    print_info "Found package.json di root"
    
    if is_backend "$APP_DIR" && is_frontend "$APP_DIR"; then
        RESULT_TYPE="fullstack-single"
        RESULT_DESC="Full-stack (Backend + Frontend dalam 1 repo)"
    elif is_backend "$APP_DIR"; then
        RESULT_TYPE="backend-only"
        RESULT_DESC="Backend-only application"
    elif is_frontend "$APP_DIR"; then
        RESULT_TYPE="frontend-only"
        RESULT_DESC="Frontend-only application"
    else
        RESULT_TYPE="generic-nodejs"
        RESULT_DESC="Generic Node.js application"
    fi
else
    # Check subdirectories
    print_info "Checking subdirectories..."
    
    BACKEND_CANDIDATES=("backend" "server" "api" "packages/backend" "apps/backend")
    FRONTEND_CANDIDATES=("frontend" "client" "web" "app" "packages/frontend" "apps/frontend")
    
    for candidate in "${BACKEND_CANDIDATES[@]}"; do
        if has_package_json "$APP_DIR/$candidate" && is_backend "$APP_DIR/$candidate"; then
            RESULT_BACKEND_DIR="$candidate"
            break
        fi
    done
    
    for candidate in "${FRONTEND_CANDIDATES[@]}"; do
        if has_package_json "$APP_DIR/$candidate" && is_frontend "$APP_DIR/$candidate"; then
            RESULT_FRONTEND_DIR="$candidate"
            break
        fi
    done
    
    if [ -n "$RESULT_BACKEND_DIR" ] && [ -n "$RESULT_FRONTEND_DIR" ]; then
        RESULT_TYPE="fullstack-monorepo"
        RESULT_DESC="Monorepo: Backend + Frontend terpisah"
    elif [ -n "$RESULT_BACKEND_DIR" ]; then
        RESULT_TYPE="backend-monorepo"
        RESULT_DESC="Monorepo: Backend only"
    elif [ -n "$RESULT_FRONTEND_DIR" ]; then
        RESULT_TYPE="frontend-monorepo"
        RESULT_DESC="Monorepo: Frontend only"
    fi
fi

if [ -z "$RESULT_TYPE" ]; then
    print_error "Tidak bisa mendeteksi aplikasi type"
    exit 1
fi

print_header "DETECTION RESULTS"
print_success "Type: $RESULT_TYPE"
print_info "Description: $RESULT_DESC"

[ -n "$RESULT_BACKEND_DIR" ] && print_info "Backend dir: $RESULT_BACKEND_DIR"
[ -n "$RESULT_FRONTEND_DIR" ] && print_info "Frontend dir: $RESULT_FRONTEND_DIR"

# JSON output
cat << JSONEOF
{
  "type": "$RESULT_TYPE",
  "description": "$RESULT_DESC",
  "backend_dir": "$RESULT_BACKEND_DIR",
  "frontend_dir": "$RESULT_FRONTEND_DIR"
}
JSONEOF
