# VPS Multi-App Setup: Ubuntu 24.04 Production Deployment Guide

**Infrastruktur**: Ubuntu 24.04 LTS  
**VPS IP**: yourvps-ippub  
**Domain**: aplikasiabiyorf.id  
**Specs**: 4GB RAM, 2 Core CPU, 50GB Storage  
**Target Apps**: 10-20 React.js Applications  
**Architecture**: Hybrid routing (Port-based + Path-based) dengan Nginx reverse proxy

Complete production-ready Ubuntu 24.04 VPS configuration for hosting 10-20+ React applications. Features PM2 cluster management, Nginx reverse proxy (path-based & subdomain routing), staging/production environments, automated SSL/HTTPS, and deployment workflows.

**Perfect for:** Full-stack development teams managing multiple React applications on a single VPS with separate staging and production environments.

---

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Step-by-Step Setup](#step-by-step-setup)
- [File Structure](#file-structure)
- [Deployment Workflow](#deployment-workflow)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [FAQ](#faq)
- [Support & Contributing](#support--contributing)

---

## ✨ Features

- 🚀 **Multi-Application Hosting** - Support 10-20+ React apps on single VPS
- 🔒 **Security First** - SSH hardening, Fail2Ban, UFW firewall, SSL/HTTPS
- 🌐 **Flexible Routing** - Hybrid path-based, port-based, and subdomain support
- 📦 **PM2 Management** - Cluster mode with zero-downtime reloads
- 🔄 **Staging + Production** - Separate environments with distinct configurations
- 🔑 **Environment Variables** - Per-app .env management with secrets protection
- 📊 **Monitoring & Logging** - Real-time monitoring, log rotation, health checks
- 💾 **Automated Backups** - Configuration and database backups
- 🔐 **SSL/HTTPS** - Let's Encrypt automation with auto-renewal
- 🛠️ **Fully Automated** - Shell scripts handle 90% of setup
- 📖 **Comprehensive Documentation** - Step-by-step guides + troubleshooting

---

## 📋 Requirements

### VPS Specifications
- **OS:** Ubuntu 24.04 LTS
- **RAM:** 4GB minimum (tested with 4GB)
- **CPU:** 2 cores minimum
- **Storage:** 50GB minimum
- **Network:** Public IP address

### Local Requirements
- SSH client (Terminal on macOS/Linux, PuTTY/Git Bash on Windows)
- Git configured locally
- Text editor (VSCode with Remote SSH extension recommended)
- Domain name (optional but recommended for production)

### Account Requirements
- GitHub account with SSH key setup
- Supabase account (if using backend database)
- Domain registrar access (if using custom domain)

---

## 🚀 Quick Start

### Option A: Fully Automated (Recommended)

Run all setup stages automatically with a single command:

```bash
# SSH ke VPS Anda
ssh root@your-vps-ippub

# Download & execute comprehensive setup
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/full-setup.sh)
```

The script will:
- Auto-detect your public IP
- Prompt for configuration (SSH port, username, domain, timezone, email)
- Install all dependencies
- Configure Nginx, PM2, SSL
- Setup monitoring and backups
- Display final configuration summary

**Estimated time:** 15-20 minutes

---

### Option B: Stage-by-Stage (Recommended for First-Time)

Execute each setup stage individually for more control:

#### **Tahap 1: Initial System Setup** (5 minutes)
```bash
ssh root@your-vps-ippub

bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap1-initial-setup.sh)
```

**What this does:**
- System update & security upgrades
- SSH hardening (port change, key-only auth)
- Create development user (`devel_me`)
- Install Fail2Ban & UFW firewall
- Create directory structure
- Generate security summary

**After completion:** Log out and reconnect with new SSH port

```bash
# Reconnect with new SSH configuration
ssh devel_me@your-vps-ippub -p <your-new-ssh-port>
```

---

#### **Tahap 2: Node.js, PM2, and Nginx** (10 minutes)
```bash
# As devel_me user
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap2-nodejs-pm2-nginx.sh)
```

**What this does:**
- Install Node.js via NVM (latest LTS)
- Install PM2 globally
- Install Nginx with recommended modules
- Create PM2 directory structure
- Setup basic Nginx proxy
- Configure log rotation

---

#### **Tahap 3: GitHub SSH Key & Git Setup** (3 minutes)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap3-github-git-setup.sh)
```

**What this does:**
- Generate SSH key for GitHub
- Display public key for GitHub settings
- Configure Git user settings
- Create SSH config for GitHub
- Test GitHub connectivity

**Next step:** Add SSH public key to GitHub account (https://github.com/settings/keys)

---

#### **Tahap 4: Multi-App Nginx Configuration** (5 minutes)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap4-nginx-multiapp-config.sh)
```

**Interactive prompts:**
- How many applications to setup initially?
- Application names and ports
- Subdomain or path-based routing?
- Domain name configuration

**What this does:**
- Create Nginx config templates
- Setup reverse proxy for each app
- Configure path-based routing (`/app1`, `/app2`)
- Configure subdomain routing (`app1.domainaplikasimu.id`)
- Create symlinks in sites-enabled
- Test Nginx configuration
- Reload Nginx

---

#### **Tahap 5: SSL/HTTPS Setup** (5 minutes)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap5-ssl-https-setup.sh)
```

**Interactive prompts:**
- Use Let's Encrypt or self-signed certificates?
- Domain(s) for SSL certificates
- Email for certificate notifications

**What this does:**
- Install Certbot
- Generate SSL certificates
- Configure auto-renewal
- Update Nginx for HTTPS
- Test certificate validity
- Setup reminder for expiration

---

#### **Tahap 6: PM2 Ecosystem Configuration** (3 minutes)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap6-pm2-ecosystem-config.sh)
```

**What this does:**
- Create ecosystem-production.config.js
- Create ecosystem-staging.config.js
- Configure environment variables per app
- Setup PM2 startup on system boot
- Create monitoring dashboards

---

#### **Tahap 7: Monitoring, Logging & Backups** (2 minutes)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/tahap7-monitoring-backup-setup.sh)
```

**What this does:**
- Install monitoring tools (htop, glances)
- Setup log rotation
- Configure automated backups
- Create health check scripts
- Setup cron jobs for maintenance
- Configure log aggregation

---

## 🏗️ Architecture Overview

### System Architecture
```
Internet
   ↓
[Nginx Reverse Proxy - Port 80/443]
   ↓
   ├─→ [App1 - PM2 Port 3001]
   ├─→ [App2 - PM2 Port 3002]
   ├─→ [App3 - PM2 Port 3003]
   └─→ [App... - PM2 Port 3020]
        ↓
   [Supabase Cloud Database]
```

### Routing Strategy

#### Path-Based Routing (Recommended for development)
```
https://your-vps-ippub/app1       → localhost:3001
https://your-vps-ippub/app2       → localhost:3002
https://domainaplikasimu.id/app1  → localhost:3001
https://domainaplikasimu.id/app2  → localhost:3002
```

#### Subdomain-Based Routing (Recommended for production)
```
https://app1.domainaplikasimu.id   → localhost:3001
https://app2.domainaplikasimu.id   → localhost:3002
https://staging-app1.domainaplikasimu.id → localhost:4001
https://staging-app2.domainaplikasimu.id → localhost:4002
```

#### Port-Based Routing (For direct access)
```
https://your-vps-ippub:3001        → localhost:3001
https://your-vps-ippub:3002        → localhost:3002
https://your-vps-ippub:4001        → localhost:4001 (Staging)
```

### Directory Structure
```
/home/devel_me/
├── apps/
│   ├── production/
│   │   ├── app-1/
│   │   │   ├── src/
│   │   │   ├── public/
│   │   │   ├── .env
│   │   │   └── package.json
│   │   ├── app-2/
│   │   └── app-20/
│   └── staging/
│       ├── app-1/
│       ├── app-2/
│       └── app-20/
├── pm2/
│   ├── ecosystem-production.config.js
│   ├── ecosystem-staging.config.js
│   └── logs/
├── nginx/
│   ├── sites-available/
│   │   ├── default
│   │   ├── app-1-production.conf
│   │   ├── app-2-production.conf
│   │   └── app-1-staging.conf
│   └── templates/
└── backups/
    ├── configs/
    └── databases/
```

---

## 📚 Step-by-Step Setup

For detailed step-by-step instructions including configuration details, troubleshooting, and best practices, see **[VPSTencent_Uprising.md](./VPSTencent_Uprising.md)**.

Key sections:
- **Tahap 1-7:** Complete setup breakdown
- **Tahap 8-10:** Deployment workflows and automation
- **Tahap 11-12:** Monitoring, backup, and emergency procedures

---

## 📂 File Structure

```
vps-multi-app-setup/
├── README.md                              ← You are here
├── VPSTencent_Uprising.md                 # Complete detailed guide (50+ pages)
├── LICENSE                                # MIT License
│
├── scripts/
│   ├── tahap1-initial-setup.sh           # System setup, SSH hardening, firewall
│   ├── tahap2-nodejs-pm2-nginx.sh        # Node.js, PM2, Nginx installation
│   ├── tahap3-github-git-setup.sh        # GitHub SSH keys and Git config
│   ├── tahap4-nginx-multiapp-config.sh   # Nginx multi-app routing
│   ├── tahap5-ssl-https-setup.sh         # Let's Encrypt SSL/HTTPS automation
│   ├── tahap6-pm2-ecosystem-config.sh    # PM2 ecosystem management
│   ├── tahap7-monitoring-backup-setup.sh # Monitoring, logging, backups
│   └── full-setup.sh                      # All-in-one automated setup
│
├── templates/
│   ├── ecosystem-production.config.js     # PM2 production config template
│   ├── ecosystem-staging.config.js        # PM2 staging config template
│   ├── .env.example                       # Environment variables template
│   ├── nginx/
│   │   ├── default-site.conf              # Nginx default server config
│   │   ├── app-template.conf              # Nginx app proxy template
│   │   └── ssl-template.conf              # Nginx SSL/HTTPS template
│   ├── deploy.sh                          # Deployment script template
│   └── health-check.sh                    # Health monitoring script
│
├── docs/
│   ├── INSTALLATION.md                    # Detailed installation guide
│   ├── NGINX_CONFIG.md                    # Nginx configuration reference
│   ├── PM2_MANAGEMENT.md                  # PM2 commands and management
│   ├── SSL_HTTPS_SETUP.md                 # SSL certificate setup guide
│   ├── TROUBLESHOOTING.md                 # Common issues and solutions
│   ├── SECURITY.md                        # Security best practices
│   └── DEPLOYMENT.md                      # Deployment strategies
│
├── examples/
│   ├── simple-react-app/                  # Simple React app example
│   ├── nextjs-fullstack-app/              # Next.js full-stack example
│   └── deployment-workflow.md             # Real-world workflow example
│
└── CONTRIBUTING.md                        # Contribution guidelines
```

---

## 🚀 Deployment Workflow

### Typical Deployment Cycle

#### Development
```bash
# On local machine
git clone https://github.com/yourusername/your-app.git
cd your-app
npm install
npm run dev
# Develop and test locally
```

#### Staging Deployment
```bash
# SSH to VPS
ssh devel_me@your-vps-ippub -p <ssh-port>

# Navigate to staging app directory
cd ~/apps/staging/app-1

# Pull latest changes
git pull origin develop

# Install dependencies
npm install

# Build
npm run build

# Reload with PM2
pm2 reload app-1-staging

# Verify
curl https://staging-app1.domainaplikasimu.id
```

#### Production Deployment
```bash
# After staging testing, deploy to production

# SSH to VPS
ssh devel_me@your-vps-ippub -p <ssh-port>

# Navigate to production app directory
cd ~/apps/production/app-1

# Pull latest changes
git pull origin main

# Install dependencies
npm install

# Build
npm run build

# Reload with PM2 (zero-downtime)
pm2 reload app-1-production

# Verify
curl https://app1.domainaplikasimu.id
```

### Using Deployment Script

```bash
# Download and use deployment helper
bash <(curl -fsSL https://raw.githubusercontent.com/bangroy-1167/nodejs-multi-tenant-vps/main/scripts/deploy.sh)

# Interactive prompts:
# Select environment (staging/production)
# Select application
# Enter git branch to deploy
# Confirm deployment
```

---

## 📊 Monitoring & Maintenance

### Real-Time Monitoring
```bash
# View all running PM2 processes
pm2 monit

# View specific app logs
pm2 logs app-1-production --lines 100

# System resource monitoring
htop
glances
```

### Health Checks
```bash
# Manual health check
bash ~/pm2/health-check.sh

# View health check status
pm2 describe app-1-production
```

### Backup & Recovery
```bash
# Backup all configs (runs daily via cron)
bash ~/pm2/backup-configs.sh

# List recent backups
ls -lh ~/backups/configs/

# Restore from backup
tar -xzf ~/backups/configs/configs-2024-01-15.tar.gz -C ~/
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. SSH Connection Issues
```bash
# Debug SSH connection
ssh -vvv devel_me@your-vps-ippub -p <ssh-port>

# Check SSH service
sudo systemctl status ssh

# Verify SSH key permissions
ls -la ~/.ssh/
# Should be: drwx------ (700) for ~/.ssh/
# Should be: -rw------- (600) for ~/.ssh/authorized_keys
```

#### 2. Nginx Not Working
```bash
# Check Nginx syntax
sudo nginx -t

# View Nginx error log
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx

# Check if ports are in use
sudo lsof -i -P -n | grep LISTEN
```

#### 3. PM2 Process Not Running
```bash
# List all PM2 processes
pm2 list

# Start specific app
pm2 start app-1-production

# View PM2 logs
pm2 logs

# Restart PM2 daemon
pm2 kill
pm2 resurrect
```

#### 4. SSL Certificate Issues
```bash
# Check certificate validity
sudo certbot certificates

# Renew certificates manually
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run

# View renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Emergency Procedures

#### Restore from Backup
```bash
# Stop all applications
pm2 stop all

# Restore Nginx configs
sudo tar -xzf ~/backups/configs/configs-YYYY-MM-DD.tar.gz -C /

# Restore PM2 configs
cp ~/backups/pm2/ecosystem-*.config.js ~/pm2/

# Restart services
sudo systemctl restart nginx
pm2 start ecosystem-production.config.js
```

#### Revert Recent Deployment
```bash
cd ~/apps/production/app-1

# Check git log
git log --oneline -n 5

# Revert to previous commit
git revert <commit-hash>
npm run build
pm2 reload app-1-production
```

For more troubleshooting, see **[TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)**

---

## 🔐 Security Best Practices

### Essential Security Checklist

- ✅ Change SSH port from default 22
- ✅ Disable password authentication (key-only)
- ✅ Enable Fail2Ban for brute-force protection
- ✅ Configure UFW firewall
- ✅ Setup SSL/HTTPS (Let's Encrypt)
- ✅ Store secrets in .env files (chmod 600)
- ✅ Never commit .env to git
- ✅ Use strong SSH key (4096-bit RSA or Ed25519)
- ✅ Enable automatic security updates
- ✅ Backup configuration regularly
- ✅ Monitor logs for suspicious activity
- ✅ Use Supabase Row Level Security (RLS)
- ✅ Implement rate limiting in Nginx
- ✅ Keep software updated (`sudo apt upgrade`)

### Environment Variables Security
```bash
# Create .env with restrictive permissions
touch ~/apps/production/app-1/.env
chmod 600 ~/apps/production/app-1/.env

# Add to .gitignore (never commit!)
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
echo ".env.*.local" >> .gitignore
```

### SSH Key Best Practices
```bash
# Generate secure SSH key (4096-bit)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/vps-key -C "your-email@example.com"

# Or use modern Ed25519
ssh-keygen -t ed25519 -f ~/.ssh/vps-key -C "your-email@example.com"

# Set correct permissions
chmod 600 ~/.ssh/vps-key
chmod 644 ~/.ssh/vps-key.pub
```

For comprehensive security guide, see **[SECURITY.md](./docs/SECURITY.md)**

---

## ❓ FAQ

### Q: Can I host more than 20 applications?
**A:** Yes! The setup scales to 30+ apps. Adjust port ranges in Tahap 2 and Nginx configuration accordingly. For 50+ apps, consider multiple VPS instances with load balancing.

### Q: Do I need a domain name?
**A:** Not for development/testing. You can access apps via IP:PORT (e.g., `43.157.201.129:3001`). For production, a domain is highly recommended for SSL certificates and professional appearance.

### Q: Can I use Docker instead?
**A:** Yes! This guide is designed as an alternative to Docker. Docker adds overhead; for small-medium apps, native Node.js + PM2 is lighter and faster.

### Q: How do I update an application?
**A:** Pull latest code, rebuild, and reload:
```bash
cd ~/apps/production/app-1
git pull origin main
npm install
npm run build
pm2 reload app-1-production
```

### Q: Can multiple developers deploy?
**A:** Yes. Create multiple SSH keys and add each developer's public key to `~/.ssh/authorized_keys`. Use git branching for separation (develop/staging branches).

### Q: How much traffic can this handle?
**A:** With 4GB RAM and 2 CPU, expect:
- Development apps: 100-300 concurrent users per app
- Production apps: 200-500 concurrent users per app

Scale with load balancing or upgrade VPS specs for higher traffic.

### Q: What about database backup?
**A:** Supabase handles backups automatically. You control retention policies in Supabase dashboard. No manual backup needed for database.

### Q: Can I use a different database (MongoDB, PostgreSQL)?
**A:** Yes! Modify connection strings in .env files. The guide is database-agnostic. Supabase is recommended for managed PostgreSQL.

### Q: How do I monitor performance?
**A:** Use included tools:
- `pm2 monit` - Real-time process monitoring
- `htop` - System resource usage
- `/var/log/nginx/access.log` - Web traffic logs
- PM2 health checks - Application health

### Q: What if I mess up the Nginx config?
**A:** Simple recovery:
```bash
sudo nginx -t              # Test syntax
sudo systemctl restart nginx
# Or restore from backup
sudo tar -xzf ~/backups/configs/configs-YYYY-MM-DD.tar.gz -C /
```

---

## 📞 Support & Contributing

### Getting Help

1. **Check Documentation:** Read [VPSTencent_Uprising.md](./VPSTencent_Uprising.md) first
2. **Review Troubleshooting:** See [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)
3. **Search Issues:** Check [GitHub Issues](https://github.com/bangroy-1167/nodejs-multi-tenant-vps/issues)
4. **Create Issue:** Provide:
   - OS version
   - Error message (full output)
   - Steps to reproduce
   - Expected vs actual behavior

### Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

### Reporting Issues

Found a bug? Have a suggestion?
- **Bugs:** [Open Issue](https://github.com/bangroy-1167/nodejs-multi-tenant-vps/issues/new?labels=bug)
- **Feature Requests:** [Open Issue](https://github.com/bangroy-1167/nodejs-multi-tenant-vps/issues/new?labels=enhancement)
- **Documentation:** [Open Issue](https://github.com/bangroy-1167/nodejs-multi-tenant-vps/issues/new?labels=documentation)

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](./LICENSE) file for details.

You are free to:
- ✅ Use for personal and commercial projects
- ✅ Modify and distribute
- ✅ Use privately or commercially

You must:
- ℹ️ Include original license and copyright notice

---

## 🌟 Acknowledgments

Built with ❤️ for developers who want production-grade infrastructure without Docker complexity.

**Tested on:**
- Ubuntu 24.04 LTS
- 4GB RAM, 2 CPU VPS
- 10-20 React applications
- Supabase backend

---

## 📊 Project Status

| Component | Status | Notes |
|-----------|--------|-------|
| Core Setup Scripts | ✅ Stable | Tested in production |
| Documentation | ✅ Stable | Comprehensive coverage |
| Nginx Config | ✅ Stable | Multi-app support verified |
| PM2 Management | ✅ Stable | Zero-downtime reloads working |
| SSL/HTTPS | ✅ Stable | Let's Encrypt auto-renewal tested |
| Monitoring | ✅ Stable | Health checks and logging verified |
| Backup System | ✅ Stable | Daily automated backups |

---

## 📞 Quick Links

- 📖 [Full Documentation](./VPSTencent_Uprising.md)
- 🔧 [Installation Guide](./docs/INSTALLATION.md)
- 🔐 [Security Guide](./docs/SECURITY.md)
- 🛠️ [Troubleshooting](./docs/TROUBLESHOOTING.md)
- 📚 [Examples](./examples/)
- 🤝 [Contributing](./CONTRIBUTING.md)
- 📝 [License](./LICENSE)

---

**Happy deploying! 🚀**

For questions or issues, please open an issue on GitHub.
