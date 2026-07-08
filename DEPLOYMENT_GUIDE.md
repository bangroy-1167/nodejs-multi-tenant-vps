# TAHAP 8: Deploy Aplikasi dari GitHub

Panduan lengkap untuk deploy Node.js aplikasi dari GitHub repository ke VPS multi-app infrastructure.

---

## Overview

Script `tahap8-deploy-github-app.sh` mengotomatisasi:

- ✅ Clone atau update repository dari GitHub
- ✅ Setup environment variables (.env)
- ✅ Install dependencies (npm install)
- ✅ Build aplikasi (jika ada build script)
- ✅ Copy ke production directory
- ✅ Setup PM2 configuration
- ✅ Start/restart aplikasi
- ✅ Health check
- ✅ Nginx integration instructions

**Designed untuk reusable**: Bisa deploy aplikasi1, aplikasi2, ..., aplikasi30 dengan script yang sama.

---

## Prerequisites

Pastikan tahap-tahap berikut sudah **completed**:

- ✅ **Tahap 1**: Initial Setup (SSH, firewall, fail2ban)
- ✅ **Tahap 2**: Node.js, PM2, Nginx terinstall
- ✅ **Tahap 3**: GitHub SSH key configured
- ✅ **Tahap 4**: Nginx multi-app configuration
- ✅ **Tahap 6**: PM2 ecosystem setup
- ✅ **Tahap 7**: Monitoring & backup

---

## Quick Start

### Deploy Aplikasi Pertama (aplikasi1)

```bash
# Login sebagai development user
ssh -p 2222 develme_rf@43.157.201.129

# Jalankan script
bash tahap8-deploy-github-app.sh
```

**Interactive prompts:**
```
Nama aplikasi [aplikasi1]: aplikasi1
GitHub repository URL: git@github.com:bangroy-1167/my-nodejs-app.git
```

**Selesai!** Aplikasi siap di production directory.

---

### Deploy Aplikasi Kedua (aplikasi2)

```bash
bash tahap8-deploy-github-app.sh --app aplikasi2
```

Script otomatis extract port (3002), setup directory, etc.

---

## Usage Patterns

### 1. Fresh Deployment (Default)

```bash
bash tahap8-deploy-github-app.sh
```

- Prompt untuk app name + GitHub URL
- Clone repository
- Setup environment
- Install dependencies
- Start dengan PM2

### 2. Update Existing Application

```bash
bash tahap8-deploy-github-app.sh --app aplikasi1 --update
```

- Pull latest code dari GitHub
- npm install (update dependencies)
- Rebuild jika ada build script
- Restart PM2

### 3. Quick Deploy dengan Semua Parameter

```bash
bash tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --repo git@github.com:bangroy-1167/my-app.git
```

Tidak ada prompt, langsung execute.

### 4. Bulk Deploy Multiple Apps

```bash
for i in {1..5}; do
  bash tahap8-deploy-github-app.sh --app aplikasi$i
done
```

Deploy aplikasi1 sampai aplikasi5 otomatis.

---

## File Structure After Deployment

```
/home/develme_rf/
├── apps/
│   ├── repos/
│   │   ├── aplikasi1/              ← Repository clone
│   │   │   ├── .git/
│   │   │   ├── src/
│   │   │   ├── node_modules/
│   │   │   ├── package.json
│   │   │   └── .env.example
│   │   ├── aplikasi2/
│   │   └── aplikasi3/
│   │
│   ├── production/
│   │   ├── aplikasi1/              ← Production symlink
│   │   │   ├── src/
│   │   │   ├── node_modules → ../repos/aplikasi1/node_modules
│   │   │   ├── .env
│   │   │   └── package.json
│   │   ├── aplikasi2/
│   │   └── aplikasi3/
│   │
│   ├── logs/
│   │   ├── aplikasi1/
│   │   │   ├── out.log
│   │   │   └── error.log
│   │   ├── aplikasi2/
│   │   └── aplikasi3/
│   │
│   └── nginx-configs/
│       ├── APP-MAPPING.md
│       ├── app-aplikasi1-path
│       ├── app-aplikasi1-subdomain
│       └── app-aplikasi1-hybrid
│
├── pm2-configs/
│   ├── aplikasi1.config.js
│   ├── aplikasi1.env
│   ├── aplikasi2.config.js
│   └── aplikasi2.env
│
└── [monitoring scripts]
```

---

## Environment File (.env)

Script otomatis membuat `.env` file dengan prioritas:

1. **Dari repository**: `<repo>/.env.example`
2. **Dari template**: `/home/develme_rf/pm2-configs/<APP_NAME>.env`
3. **Generated**: Script buat baru dengan defaults

### Default Environment Variables

```env
NODE_ENV=production
PORT=3001
APP_NAME=aplikasi1
APP_URL=https://aplikasi1.sv1.thinking.my.id

LOG_LEVEL=info
LOG_DIR=/home/develme_rf/apps/logs/aplikasi1
```

### Customize .env

Script bertanya: **"Edit .env file sekarang? (y/n)"**

Pilih `y` atau edit manual nanti:

```bash
nano /home/develme_rf/apps/production/aplikasi1/.env
```

---

## PM2 Configuration

Script otomatis generate PM2 config di `/home/develme_rf/pm2-configs/<APP_NAME>.config.js`

Includes cluster mode, auto-restart, memory limits, dan logging.

---

## Health Check & Monitoring

Setelah deployment, script otomatis:

1. ✅ Test port listening
2. ✅ Test HTTP endpoint
3. ✅ Verify PM2 status

### Manual Health Check

```bash
# View logs
pm2 logs aplikasi1

# Monitor
pm2 monit

# Check status
pm2 list
```

---

## Nginx Integration

Setelah aplikasi running, enable di Nginx:

### Path-Based

```bash
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-path \
           /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

URL: `https://sv1.thinking.my.id/aplikasi1`

### Subdomain-Based

```bash
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-subdomain \
           /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

URL: `https://aplikasi1.sv1.thinking.my.id`

### Hybrid (Both)

```bash
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-hybrid \
           /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

---

## Common Workflows

### Deploy New App

```bash
bash tahap8-deploy-github-app.sh --app aplikasi1 \
  --repo git@github.com:bangroy-1167/my-app.git

sudo ln -s /etc/nginx/sites-available/app-aplikasi1-hybrid \
           /etc/nginx/sites-enabled/
sudo systemctl reload nginx

curl https://aplikasi1.sv1.thinking.my.id
```

### Update Existing App

```bash
bash tahap8-deploy-github-app.sh --app aplikasi1 --update
```

### Change Environment Variables

```bash
nano /home/develme_rf/apps/production/aplikasi1/.env
pm2 restart aplikasi1
```

### View Logs

```bash
pm2 logs aplikasi1
tail -f /home/develme_rf/apps/logs/aplikasi1/error.log
```

### Rollback

```bash
cd /home/develme_rf/apps/repos/aplikasi1
git log --oneline -10
git checkout <commit_hash>
npm install
npm run build
pm2 restart aplikasi1
```

---

## Troubleshooting

### Port Already in Use

```bash
sudo lsof -i :3001
sudo kill -9 <PID>
pm2 restart aplikasi1
```

### GitHub SSH Failed

```bash
ssh -T git@github.com
bash tahap3-github-git-setup.sh  # Re-run if needed
```

### Application Not Responding

```bash
pm2 logs aplikasi1
pm2 restart aplikasi1
netstat -tuln | grep 3001
curl http://localhost:3001/
```

### Nginx Not Forwarding

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
curl http://localhost:3001/
ls -la /etc/nginx/sites-enabled/app-aplikasi1-*
```

---

## Best Practices

1. **Keep .env out of git** - Use `.env.example` for reference
2. **Implement health check endpoint** - Script tests it
3. **Use structured logging** - Help with debugging
4. **Never commit secrets** - Use environment variables
5. **Monitor resource usage** - Check PM2 monit regularly

---

## Port Reference

| Aplikasi | Port | Path | Subdomain |
|----------|------|------|-----------|
| aplikasi1 | 3001 | /aplikasi1 | aplikasi1.sv1.thinking.my.id |
| aplikasi2 | 3002 | /aplikasi2 | aplikasi2.sv1.thinking.my.id |
| aplikasi3 | 3003 | /aplikasi3 | aplikasi3.sv1.thinking.my.id |
| ... | ... | ... | ... |
| aplikasi30 | 3030 | /aplikasi30 | aplikasi30.sv1.thinking.my.id |

---

## Next Steps

1. Deploy aplikasi1
2. Enable Nginx
3. Test aplikasi
4. Deploy aplikasi2, 3, dst
5. Return ke Tahap 5 untuk HTTPS Wildcard setup

---

**Version**: 1.0 | **Last Updated**: July 8, 2026
