#!/bin/bash

################################################################################
# TAHAP 1: INITIAL VPS SETUP - Ubuntu 24.04
# VPS Multi-App Setup Script
# Purpose: System update, security hardening, user creation, and firewall setup
# Auto-detects public IP and uses generic domain placeholder for public repo
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

################################################################################
# AUTO-DETECT PUBLIC IP
################################################################################

print_info "Detecting public IP address..."
VPS_IP=$(curl -s https://api.ipify.org || curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
if [ -z "$VPS_IP" ] || [ "$VPS_IP" == "" ]; then
    VPS_IP="your-vps-ippub"
    print_warning "Could not auto-detect IP. Please set manually."
else
    print_success "Detected IP: $VPS_IP"
fi

# Generic domain placeholder for public repository
DOMAIN_PLACEHOLDER="domainaplikasimu.id"

################################################################################
# START: TAHAP 1 SETUP
################################################################################

print_header "TAHAP 1: INITIAL VPS SETUP"

# ============================================================================
# STEP 1: COLLECT USER INPUTS
# ============================================================================
print_header "STEP 1: Gathering Configuration Information"

echo -e "${BLUE}Detected Configuration:${NC}"
echo "  VPS IP: ${GREEN}$VPS_IP${NC}"
echo "  Domain Template: ${GREEN}$DOMAIN_PLACEHOLDER${NC}"
echo ""

# SSH Port
read -p "$(echo -e ${YELLOW}Enter new SSH port (default: 2222):${NC} )" SSH_PORT
SSH_PORT=${SSH_PORT:-2222}
print_info "SSH port will be changed to: $SSH_PORT"

# Development Username
read -p "$(echo -e ${YELLOW}Enter development username (default: devel_me):${NC} )" DEV_USERNAME
DEV_USERNAME=${DEV_USERNAME:-devel_me}
print_info "Development user will be: $DEV_USERNAME"

# Timezone
read -p "$(echo -e ${YELLOW}Enter timezone (e.g., Asia/Jakarta, UTC):${NC} )" TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
print_info "Timezone will be set to: $TIMEZONE"

# Email for Let's Encrypt (future use)
read -p "$(echo -e ${YELLOW}Enter email for SSL certificates (e.g., admin@example.com):${NC} )" ADMIN_EMAIL
print_info "Admin email: $ADMIN_EMAIL"

# Confirmation
echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo "  VPS IP: $VPS_IP"
echo "  Domain Template: $DOMAIN_PLACEHOLDER"
echo "  SSH Port: $SSH_PORT"
echo "  Dev Username: $DEV_USERNAME"
echo "  Timezone: $TIMEZONE"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""
read -p "$(echo -e ${YELLOW}Continue with these settings? (y/n):${NC} )" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Setup cancelled"
    exit 1
fi

# ============================================================================
# STEP 2: SYSTEM UPDATE
# ============================================================================
print_header "STEP 2: System Update and Upgrade"

print_info "Updating package lists..."
apt update

print_info "Upgrading installed packages..."
apt upgrade -y

print_info "Installing build essentials..."
apt install -y build-essential curl wget git htop net-tools nano vim

print_info "Installing additional utilities..."
apt install -y unzip tar gzip bzip2 zip

print_success "System update and upgrade completed"

# ============================================================================
# STEP 3: SET TIMEZONE
# ============================================================================
print_header "STEP 3: Setting Timezone"

timedatectl set-timezone "$TIMEZONE"
print_success "Timezone set to: $(timedatectl | grep 'Time zone')"

# ============================================================================
# STEP 4: CREATE DEVELOPMENT USER
# ============================================================================
print_header "STEP 4: Creating Development User"

if id "$DEV_USERNAME" &>/dev/null; then
    print_warning "User $DEV_USERNAME already exists, skipping user creation"
else
    print_info "Creating user: $DEV_USERNAME"
    useradd -m -s /bin/bash "$DEV_USERNAME"
    print_success "User $DEV_USERNAME created"
    
    # Add to sudoers
    print_info "Adding $DEV_USERNAME to sudoers..."
    usermod -aG sudo "$DEV_USERNAME"
    print_success "$DEV_USERNAME added to sudoers"
fi

# Create .ssh directory
print_info "Setting up SSH directory for $DEV_USERNAME..."
mkdir -p /home/"$DEV_USERNAME"/.ssh
chmod 700 /home/"$DEV_USERNAME"/.ssh
chown "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/.ssh
touch /home/"$DEV_USERNAME"/.ssh/authorized_keys
chmod 600 /home/"$DEV_USERNAME"/.ssh/authorized_keys
chown "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/.ssh/authorized_keys
print_success "SSH directory configured for $DEV_USERNAME"

# ============================================================================
# STEP 5: SSH HARDENING
# ============================================================================
print_header "STEP 5: SSH Hardening"

# Backup original sshd_config
print_info "Backing up original sshd_config..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)
print_success "Backup created"

# Update SSH configuration
print_info "Hardening SSH configuration..."

# Use sed to update SSH config
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#PubkeyAuthentication no/PubkeyAuthentication yes/" /etc/ssh/sshd_config

# Add specific configurations if not present
if ! grep -q "AllowUsers" /etc/ssh/sshd_config; then
    echo "AllowUsers $DEV_USERNAME" >> /etc/ssh/sshd_config
fi

if ! grep -q "X11Forwarding no" /etc/ssh/sshd_config; then
    echo "X11Forwarding no" >> /etc/ssh/sshd_config
fi

if ! grep -q "MaxAuthTries 3" /etc/ssh/sshd_config; then
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
fi

# Validate SSH config
if sshd -t > /dev/null 2>&1; then
    print_success "SSH configuration is valid"
    systemctl restart ssh
    print_success "SSH service restarted"
else
    print_error "SSH configuration validation failed!"
    print_info "Restoring original sshd_config..."
    cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
    systemctl restart ssh
    exit 1
fi

print_info "SSH Configuration Applied:"
echo "  Port: $SSH_PORT"
echo "  PermitRootLogin: no"
echo "  PasswordAuthentication: no"
echo "  AllowUsers: $DEV_USERNAME"

# ============================================================================
# STEP 6: INSTALL AND CONFIGURE FAIL2BAN
# ============================================================================
print_header "STEP 6: Installing and Configuring Fail2Ban"

print_info "Installing Fail2Ban..."
apt install -y fail2ban

# Create local jail configuration
print_info "Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = $ADMIN_EMAIL
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
EOF

print_success "Fail2Ban configuration created"

systemctl enable fail2ban
systemctl start fail2ban
print_success "Fail2Ban enabled and started"

# ============================================================================
# STEP 7: FIREWALL SETUP (UFW)
# ============================================================================
print_header "STEP 7: Firewall Setup with UFW"

# Enable UFW
print_info "Enabling UFW firewall..."
ufw --force enable

# Default policies
ufw default deny incoming
ufw default allow outgoing
print_success "Default firewall policies set"

# Allow SSH on new port
print_info "Allowing SSH on port $SSH_PORT..."
ufw allow "$SSH_PORT"/tcp

# Allow HTTP and HTTPS
print_info "Allowing HTTP and HTTPS..."
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Wireguard (if using standard port)
print_info "Allowing Wireguard (51820)..."
ufw allow 51820/udp

# Allow app ports range (3001-3020 for React apps)
print_info "Allowing application ports (3001-3020)..."
ufw allow 3001:3020/tcp

# Allow Webmin (if installed)
print_info "Allowing Webmin (10000)..."
ufw allow 10000/tcp

# Reload firewall
ufw reload
print_success "Firewall configuration applied"

print_info "UFW Rules Summary:"
ufw status numbered

# ============================================================================
# STEP 8: CREATE APPLICATION DIRECTORIES
# ============================================================================
print_header "STEP 8: Creating Application Directories"

print_info "Creating app directories..."
mkdir -p /home/"$DEV_USERNAME"/apps
mkdir -p /home/"$DEV_USERNAME"/pm2
mkdir -p /home/"$DEV_USERNAME"/logs
mkdir -p /home/"$DEV_USERNAME"/backups

# Set permissions
chown -R "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/apps
chown -R "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/pm2
chown -R "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/logs
chown -R "$DEV_USERNAME":"$DEV_USERNAME" /home/"$DEV_USERNAME"/backups

chmod -R 755 /home/"$DEV_USERNAME"/apps
chmod -R 755 /home/"$DEV_USERNAME"/pm2
chmod -R 755 /home/"$DEV_USERNAME"/logs
chmod -R 755 /home/"$DEV_USERNAME"/backups

print_success "Application directories created and configured"

# ============================================================================
# STEP 9: VERIFICATION
# ============================================================================
print_header "STEP 9: Verification"

echo ""
print_info "System Information:"
echo "  Hostname: $(hostname)"
echo "  IP Address: $VPS_IP"
echo "  OS: $(lsb_release -ds)"
echo "  Kernel: $(uname -r)"
echo "  Timezone: $TIMEZONE"
echo ""

print_info "User Information:"
id "$DEV_USERNAME"
echo ""

print_info "SSH Status:"
systemctl status ssh --no-pager | head -n 5
echo ""

print_info "Fail2Ban Status:"
systemctl status fail2ban --no-pager | head -n 5
echo ""

print_info "Firewall Status:"
ufw status
echo ""

# ============================================================================
# STEP 10: SUMMARY AND NEXT STEPS
# ============================================================================
print_header "TAHAP 1: SETUP COMPLETED SUCCESSFULLY"

echo -e "${GREEN}✓ All tasks completed!${NC}\n"

cat << EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

IMPORTANT NOTES:

1. SSH Configuration Changed:
   ${YELLOW}Old Port: 22${NC}
   ${YELLOW}New Port: $SSH_PORT${NC}
   
   Update your VSCode Remote SSH config:
   ${YELLOW}Host your-vps${NC}
   ${YELLOW}    HostName $VPS_IP${NC}
   ${YELLOW}    Port $SSH_PORT${NC}
   ${YELLOW}    User $DEV_USERNAME${NC}

2. SSH Key Authentication Required:
   You MUST add your public key to authorized_keys.
   From your local machine:
   ${YELLOW}ssh-copy-id -i ~/.ssh/your_key -p $SSH_PORT $DEV_USERNAME@$VPS_IP${NC}

3. Firewall Rules Applied:
   - SSH: Port $SSH_PORT
   - HTTP: Port 80
   - HTTPS: Port 443
   - App Ports: 3001-3020
   - Wireguard: Port 51820
   - Webmin: Port 10000

4. Development User Created:
   Username: ${YELLOW}$DEV_USERNAME${NC}
   Has sudo privileges: ${YELLOW}Yes${NC}

5. Domain Configuration:
   Replace '${YELLOW}$DOMAIN_PLACEHOLDER${NC}' with your actual domain in:
   - Nginx configuration files (Tahap 4)
   - DNS records
   - SSL certificate setup (Tahap 5)

6. Next Steps (Run Tahap 2):
   - Install Node.js and NVM
   - Install PM2
   - Install Nginx
   - Configure system monitoring

   Execute: ${YELLOW}bash tahap2-nodejs-pm2-nginx.sh${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

Configuration files saved:
  - SSH config: /etc/ssh/sshd_config
  - SSH backup: /etc/ssh/sshd_config.backup.*
  - Fail2Ban: /etc/fail2ban/jail.local
  - Firewall: ufw status

Logs and monitoring:
  ${YELLOW}tail -f /var/log/auth.log${NC} (SSH logs)
  ${YELLOW}fail2ban-client status${NC} (Fail2Ban status)
  ${YELLOW}ufw status verbose${NC} (Firewall details)

EOF

print_success "TAHAP 1 Setup Complete!"
print_warning "Please test SSH connection with new port before closing this terminal"

exit 0
