#!/bin/bash

#################################################################
# TAHAP 1: INITIAL VPS SETUP - Ubuntu 24.04
# Multi-App Node.js/React Development VPS
# Version: 2.0 (Cleaned)
#################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Detect public IP
print_info "Detecting public IP address..."
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [[ -z "$PUBLIC_IP" ]]; then
    PUBLIC_IP="your-public-ip"
fi
print_success "Detected IP: $PUBLIC_IP"

# Default values
DEFAULT_SSH_PORT=2222
DEFAULT_DEV_USER=devel_me
DEFAULT_TIMEZONE="Asia/Jakarta"
DEFAULT_ADMIN_EMAIL="admin@example.com"
DOMAIN_TEMPLATE="domainaplikasimu.id"

print_header "TAHAP 1: INITIAL VPS SETUP"

print_header "STEP 1: Gathering Configuration Information"

echo ""
echo "Detected Configuration:"
echo -e "  VPS IP: ${GREEN}${PUBLIC_IP}${NC}"
echo -e "  Domain Template: ${GREEN}${DOMAIN_TEMPLATE}${NC}"
echo ""

# SSH Port configuration
echo -n "Enter SSH port (default: $DEFAULT_SSH_PORT): "
read SSH_PORT
SSH_PORT=${SSH_PORT:-$DEFAULT_SSH_PORT}
print_info "SSH Port set to: $SSH_PORT"

# Development user configuration
echo -n "Enter development username (default: $DEFAULT_DEV_USER): "
read DEV_USER
DEV_USER=${DEV_USER:-$DEFAULT_DEV_USER}
print_info "Development user set to: $DEV_USER"

# Timezone configuration
echo -n "Enter timezone (default: $DEFAULT_TIMEZONE): "
read TIMEZONE
TIMEZONE=${TIMEZONE:-$DEFAULT_TIMEZONE}
print_info "Timezone set to: $TIMEZONE"

# Admin email configuration
echo -n "Enter admin email (default: $DEFAULT_ADMIN_EMAIL): "
read ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}
print_info "Admin email set to: $ADMIN_EMAIL"

# Confirmation
echo ""
echo -e "${YELLOW}Summary of configuration:${NC}"
echo "  SSH Port: $SSH_PORT"
echo "  Development User: $DEV_USER"
echo "  Timezone: $TIMEZONE"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""
echo -n "Continue with these settings? (yes/no): "
read CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    print_error "Setup cancelled"
    exit 1
fi

print_header "STEP 2: System Update & Essential Packages"

print_info "Updating system packages..."
apt update
apt upgrade -y

print_info "Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    htop \
    glances \
    iotop \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    telnet \
    nano \
    vim \
    ufw \
    fail2ban \
    unzip \
    zip

print_success "System update completed"

print_header "STEP 3: Create Development User"

if id "$DEV_USER" &>/dev/null; then
    print_info "User $DEV_USER already exists"
else
    print_info "Creating user $DEV_USER..."
    useradd -m -s /bin/bash "$DEV_USER"
    usermod -aG sudo "$DEV_USER"
    print_success "User $DEV_USER created with sudo access"
fi

# Create .ssh directory for development user
DEV_HOME="/home/$DEV_USER"
DEV_SSH_DIR="$DEV_HOME/.ssh"

mkdir -p "$DEV_SSH_DIR"
chmod 700 "$DEV_SSH_DIR"
chown "$DEV_USER:$DEV_USER" "$DEV_SSH_DIR"

print_info "SSH directory created for $DEV_USER"

print_header "STEP 4: Timezone Configuration"

print_info "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"
print_success "Timezone configured"

print_header "STEP 5: SSH Configuration"

print_info "Backing up original SSH config..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

print_info "Configuring SSH security..."
cat > /tmp/ssh_config_patch.txt <<'EOF'
Port PORT_PLACEHOLDER
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers USERNAME_PLACEHOLDER
EOF

sed -i "s/PORT_PLACEHOLDER/$SSH_PORT/" /tmp/ssh_config_patch.txt
sed -i "s/USERNAME_PLACEHOLDER/$DEV_USER/" /tmp/ssh_config_patch.txt

# Apply SSH configuration
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config

# Add AllowUsers if not exists
if ! grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    echo "AllowUsers $DEV_USER" >> /etc/ssh/sshd_config
fi

# Test SSH config
sshd -t
if [[ $? -eq 0 ]]; then
    print_success "SSH configuration is valid"
    systemctl restart ssh
    print_success "SSH service restarted"
else
    print_error "SSH configuration has errors, restoring backup..."
    cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    systemctl restart ssh
    exit 1
fi

print_header "STEP 6: Firewall Configuration"

print_info "Enabling UFW firewall..."
ufw --force enable

print_info "Setting firewall rules..."
ufw default deny incoming
ufw default allow outgoing

ufw allow "$SSH_PORT/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000:3020/tcp

print_success "Firewall configured"

print_header "STEP 7: Fail2Ban Configuration"

print_info "Configuring Fail2Ban..."

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[sshd-ddos]
enabled = true
port = $SSH_PORT
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 10
bantime = 3600
findtime = 600
action = iptables-multiport[name=SSH, port="ssh,http,https"]
EOF

systemctl restart fail2ban
print_success "Fail2Ban configured"

print_header "STEP 8: Directory Structure Setup"

print_info "Creating application directory structure..."

# Root directories
mkdir -p /home/$DEV_USER/apps
mkdir -p /home/$DEV_USER/apps/repos
mkdir -p /home/$DEV_USER/apps/staging
mkdir -p /home/$DEV_USER/apps/production
mkdir -p /home/$DEV_USER/logs
mkdir -p /home/$DEV_USER/backups
mkdir -p /home/$DEV_USER/config
mkdir -p /home/$DEV_USER/scripts

# Set proper permissions
chown -R "$DEV_USER:$DEV_USER" /home/$DEV_USER/apps
chown -R "$DEV_USER:$DEV_USER" /home/$DEV_USER/logs
chown -R "$DEV_USER:$DEV_USER" /home/$DEV_USER/backups
chown -R "$DEV_USER:$DEV_USER" /home/$DEV_USER/config
chown -R "$DEV_USER:$DEV_USER" /home/$DEV_USER/scripts

chmod 755 /home/$DEV_USER/apps
chmod 755 /home/$DEV_USER/logs
chmod 755 /home/$DEV_USER/backups
chmod 755 /home/$DEV_USER/config
chmod 755 /home/$DEV_USER/scripts

print_success "Directory structure created"

print_header "STEP 9: System Limits Configuration"

print_info "Increasing file descriptor limits..."

cat >> /etc/security/limits.conf <<EOF

# Development User Limits
$DEV_USER soft nofile 65536
$DEV_USER hard nofile 65536
$DEV_USER soft nproc 32768
$DEV_USER hard nproc 32768
EOF

print_success "System limits configured"

print_header "STEP 10: Basic System Security"

print_info "Configuring automatic security updates..."
apt install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
EOF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

print_success "Automatic security updates enabled"

print_header "STEP 11: Information Summary"

cat <<EOF

${GREEN}========================================${NC}
${GREEN}TAHAP 1 SETUP COMPLETED SUCCESSFULLY${NC}
${GREEN}========================================${NC}

${YELLOW}Important Information:${NC}
  VPS Public IP: $PUBLIC_IP
  SSH Port: $SSH_PORT
  Development User: $DEV_USER
  Domain Template: $DOMAIN_TEMPLATE
  Timezone: $TIMEZONE

${YELLOW}Next Steps:${NC}
1. Make sure you can SSH into the server with the new port:
   ssh -p $SSH_PORT $DEV_USER@$PUBLIC_IP

2. Run TAHAP 2: Node.js, NVM, PM2, and Nginx installation
   sudo bash tahap2-nodejs-pm2-nginx.sh

${YELLOW}Important Notes:${NC}
- SSH root login is disabled
- Password authentication is disabled (use SSH keys only)
- Firewall is enabled
- Fail2Ban is protecting against brute force attacks
- Automatic security updates are enabled

${YELLOW}Directory Structure Created:${NC}
  /home/$DEV_USER/apps/repos/        - Git repositories
  /home/$DEV_USER/apps/staging/      - Staging applications
  /home/$DEV_USER/apps/production/   - Production applications
  /home/$DEV_USER/logs/              - Application logs
  /home/$DEV_USER/backups/           - Backup directory
  /home/$DEV_USER/config/            - Configuration files
  /home/$DEV_USER/scripts/           - Helper scripts

EOF

print_success "All configurations completed!"
