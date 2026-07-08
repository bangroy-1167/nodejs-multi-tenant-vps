# TAHAP 8: Deploy Aplikasi dari GitHub

## Overview

**Tahap 8** adalah script otomatis untuk deploy Node.js aplikasi dari GitHub dengan support **staging dan production environment**.

### Workflow

```
GitHub Repository
        │
        ↓ (git clone)

repos/aplikasi1/              ← Source code (clean)
        │
        ↓ (cp -r)
        
 staging/aplikasi1/  OR  production/aplikasi1/
        │                       │
        ↓ (npm install)        ↓ (npm install)
      node_modules            node_modules
        │                       │
        ↓ (npm run build)      ↓ (npm run build)
       dist/                   dist/
        │                       │
        ↓ (PM2 start)         ↓ (PM2 start)
   localhost:300X          localhost:300X (via Nginx)
   (development)            (production)
```

---

## Directory Structure

```
~/apps/
├── repos/
│   ├── aplikasi1/        ← Clone dari GitHub
│   ├── aplikasi2/
│   └── aplikasi3/
├── staging/
│   ├── aplikasi1/        ← Testing environment
│   └── aplikasi2/
├── production/
│   ├── aplikasi1/        ← Live environment
│   └── aplikasi2/
├── nginx-configs/    ← Nginx templates
└── pm2-configs/      ← PM2 ecosystem configs
```

---

## Quick Start

### First Deploy (Staging)

```bash
bash tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --repo git@github.com:bangroy-1167/my-nodejs-app.git \
  --env staging
```

**Prompts:**
- `Edit .env file sekarang?` - Pilih `y` untuk konfigurasi environment
- `Restart?` - Pilih `y` untuk start aplikasi

**Output:**
```
✓ Repository di-clone: ~/apps/repos/aplikasi1
✓ Aplikasi di-copy ke: ~/apps/staging/aplikasi1
✓ Dependencies terinstall
✓ Aplikasi berhasil di-build
✓ Aplikasi started dengan PM2: staging-aplikasi1
✓ Port 3001 is listening
✓ HTTP health check passed
```

### Test di Staging

```bash
# View logs
pm2 logs staging-aplikasi1

# Monitor resource
pm2 monit

# Direct test
curl http://localhost:3001
```

### Deploy to Production (After Staging OK)

```bash
bash tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

**Output:**
```
✓ Repository source ada: ~/apps/repos/aplikasi1
✓ Aplikasi di-copy ke: ~/apps/production/aplikasi1
✓ Dependencies terinstall
✓ Aplikasi berhasil di-build
✓ Aplikasi started dengan PM2: aplikasi1
✓ Port 3001 is listening
```

### Enable in Nginx

```bash
# Pilih satu:

# 1. Path-based
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-path \
           /etc/nginx/sites-enabled/

# 2. Subdomain-based
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-subdomain \
           /etc/nginx/sites-enabled/

# 3. Hybrid (both)
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-hybrid \
           /etc/nginx/sites-enabled/

# Reload Nginx
sudo systemctl reload nginx
```

### Test di Production

```bash
# Via Nginx
curl https://aplikasi1.sv1.thinking.my.id  # subdomain
curl https://sv1.thinking.my.id/aplikasi1  # path

# Direct
curl http://localhost:3001

# Logs
pm2 logs aplikasi1
```

---

## Usage Patterns

### Pattern 1: Fresh Deploy (New Application)

```bash
bash tahap8-deploy-github-app.sh \
  --app aplikasi2 \
  --repo git@github.com:bangroy-1167/app2.git \
  --env production
```

**Alur:**
1. Clone repo ke `repos/aplikasi2/`
2. Copy ke `production/aplikasi2/`
3. Install dependencies
4. Build
5. Start dengan PM2 nama `aplikasi2`

### Pattern 2: Staging to Production (Tested)

```bash
# Step 1: Deploy ke staging
bash tahap8-deploy-github-app.sh --app aplikasi3 \
  --repo git@github.com:user/app3.git --env staging

# Step 2: Test...
pm2 logs staging-aplikasi3

# Step 3: Approve → Deploy to production
bash tahap8-deploy-github-app.sh --app aplikasi3 --env production --update
```

**Catatan:** `--update` flag:
- Tidak clone ulang, pakai existing repo di `repos/`
- Copy ulang dari repo ke target environment
- Reinstall dependencies (fresh)
- Restart PM2 process

### Pattern 3: Update Existing Application

```bash
# Scenario: Code update di GitHub
git -C ~/apps/repos/aplikasi1 pull  # Update source

# Deploy ulang ke production
bash tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

Atau one-liner:

```bash
cd ~/apps/repos/aplikasi1 && git pull && \
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

### Pattern 4: Redeploy Source (Fresh Clone)

```bash
# Kalau repo di server outdated, re-clone
rm -rf ~/apps/repos/aplikasi1

bash tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --repo git@github.com:bangroy-1167/app1.git \
  --env production --update
```

### Pattern 5: Bulk Deploy Multiple Apps

```bash
#!/bin/bash
# bulk-deploy.sh

APPS=("app1:git@github.com:user/app1.git" \
      "app2:git@github.com:user/app2.git" \
      "app3:git@github.com:user/app3.git")

for APP_REPO in "${APPS[@]}"; do
    APP=${APP_REPO%%:*}
    REPO=${APP_REPO#*:}
    
    echo "Deploying $APP..."
    bash ~/tahap8-deploy-github-app.sh \
        --app $APP \
        --repo $REPO \
        --env production
    
    sleep 5  # Jeda antar deploy
done
```

Run:
```bash
bash bulk-deploy.sh
```

---

## Command Reference

### Deploy Fresh (Clone + Setup + Start)

```bash
bash tahap8-deploy-github-app.sh \
  --app <nama> \
  --repo <github-url> \
  --env staging|production
```

### Deploy Update (Skip Clone, Fresh Copy)

```bash
bash tahap8-deploy-github-app.sh \
  --app <nama> \
  --env staging|production \
  --update
```

### Deploy with Skip Install (Faster)

```bash
bash tahap8-deploy-github-app.sh \
  --app <nama> \
  --env production \
  --update \
  --skip-install
```

---

## Environment Variables (.env)

### Staging vs Production

**staging/.env**
```ini
NODE_ENV=staging
PORT=3001
APP_NAME=aplikasi1
DATABASE_URL=staging-db.example.com
LOG_LEVEL=debug
```

**production/.env**
```ini
NODE_ENV=production
PORT=3001
APP_NAME=aplikasi1
DATABASE_URL=prod-db.example.com
LOG_LEVEL=warn
```

### How Script Handles .env

1. Cek `.env` di target directory
2. Kalau tidak ada:
   - Cek `.env.example` di repo → Copy
   - Atau create basic `.env`
3. Prompt untuk edit manual
4. Done

---

## PM2 Management

### View All Processes

```bash
pm2 list
```

Output:
```
│ id  │ name                │ status  │ ↑ │ ↑        │
├───┼──────────────┼──────┼───┼───────────┬─
what the fuck
0  │ staging-aplikasi1   │ online  │ │ 25.7 MB  │
1  │ aplikasi1           │ online  │ │ 28.3 MB  │
2  │ aplikasi2           │ online  │ │ 26.1 MB  │
```

### View Logs

```bash
# Live logs
pm2 logs aplikasi1

# Last 50 lines
pm2 logs aplikasi1 --lines 50

# Filter errors only
pm2 logs aplikasi1 --err
```

### Monitor Resource

```bash
pm2 monit
```

Display real-time CPU, memory, events untuk semua proses.

### Restart/Stop/Delete

```bash
pm2 restart aplikasi1
pm2 stop aplikasi1
pm2 delete aplikasi1

pm2 restart all
pm2 stop all
```

---

## Nginx Integration

### Port Allocation

Setiap aplikasi dapat port unik:
- aplikasi1 → 3001
- aplikasi2 → 3002
- aplikasi30 → 3030

### Routing Strategies

#### Path-Based
```
https://sv1.thinking.my.id/aplikasi1 → localhost:3001
https://sv1.thinking.my.id/aplikasi2 → localhost:3002
```

**Pro:** Single domain, simple DNS
**Con:** Path in URL, app logic complexity

#### Subdomain-Based
```
https://aplikasi1.sv1.thinking.my.id → localhost:3001
https://aplikasi2.sv1.thinking.my.id → localhost:3002
```

**Pro:** Clean URLs, app isolation
**Con:** Wildcard DNS + multiple certificates

#### Hybrid
Support keduanya! Pilih mana saat enable:
```bash
sudo ln -s /etc/nginx/sites-available/app-aplikasi1-hybrid /etc/nginx/sites-enabled/
```

---

## Troubleshooting

### Build Failed

```bash
cd ~/apps/production/aplikasi1
npm run build
```

Lihat error message.

### Port Already in Use

```bash
netstat -tuln | grep 3001

# Kill existing process
kill -9 <PID>

# Atau via PM2
pm2 delete aplikasi1
pm2 start ~/pm2-configs/aplikasi1.js
```

### .env Issues

```bash
# Check .env
cat ~/apps/production/aplikasi1/.env

# Edit
nano ~/apps/production/aplikasi1/.env

# Restart
pm2 restart aplikasi1
```

### GitHub SSH Auth Failed

```bash
# Test SSH
ssh -T git@github.com

# Should output:
# Hi bangroy-1167! You've successfully authenticated...
```

Jika fail, verify SSH key sudah di GitHub:
```bash
cat ~/.ssh/githubssh.pub
# Copy → https://github.com/settings/ssh/new
```

### Health Check Failed

Salah satu:
1. App tidak listening di port yang benar
2. Dependencies incomplete
3. .env configuration salah

Debug:
```bash
pm2 logs aplikasi1
cat ~/apps/production/aplikasi1/.env
netstat -tuln | grep 3001
```

---

## Best Practices

1. **Always test in staging first**
   ```bash
   --env staging → verify → --env production
   ```

2. **Keep repo/ clean**
   - repos/ = source only (read-only perspective)
   - staging/prod/ = working copies

3. **Maintain .env separately**
   - staging/.env ≠ production/.env
   - Use different credentials/databases

4. **Use --update flag wisely**
   - Fresh code from repo
   - Fresh node_modules
   - Rebuild always

5. **Monitor PM2 regularly**
   ```bash
   pm2 monit
   pm2 logs <app> --lines 100
   ```

6. **Backup before major updates**
   ```bash
   cp -r ~/apps/production/aplikasi1 ~/backup/aplikasi1.bak
   ```

---

## Real-World Workflow

### Day 1: Initial Deploy

```bash
# Clone repo, setup staging
bash tahap8-deploy-github-app.sh --app myapp --repo <url> --env staging

# Test...
pm2 logs staging-myapp

# Approved, promote to production
bash tahap8-deploy-github-app.sh --app myapp --env production --update

# Enable Nginx
sudo ln -s /etc/nginx/sites-available/app-myapp-hybrid /etc/nginx/sites-enabled/
sudo systemctl reload nginx

# Live!
curl https://myapp.sv1.thinking.my.id
```

### Day 7: Code Update

```bash
# Pull latest from GitHub
cd ~/apps/repos/myapp
git pull origin main

# Deploy to staging first
bash ~/tahap8-deploy-github-app.sh --app myapp --env staging --update

# Test new features...
pm2 logs staging-myapp

# Looks good, deploy production
bash ~/tahap8-deploy-github-app.sh --app myapp --env production --update

# Already in Nginx, just verify
curl https://myapp.sv1.thinking.my.id
```

### Day 30: Hotfix

```bash
# Fix bug in GitHub
# Immediately deploy production (skip staging)
cd ~/apps/repos/myapp && git pull && \
bash ~/tahap8-deploy-github-app.sh --app myapp --env production --update

# Monitor closely
pm2 logs myapp --follow
pm2 monit
```

---

## Advanced

### Custom Build Commands

Jika aplikasi punya custom build:

```bash
cd ~/apps/production/aplikasi1
npm run build:prod
# or
make build
# or
go build
```

Script hanya trigger `npm run build` otomatis. Untuk custom, edit PM2 config atau run manual sebelum PM2 start.

### Multi-Language Support

Script agnostic, asal ada:
- `package.json` + `npm` (Node.js) ✓
- `requirements.txt` + `pip` (Python) - Perlu custom
- `go.mod` (Go) - Perlu custom

Untuk non-Node.js, modify script atau run deployment manual.

### Chained Deployments

```bash
#!/bin/bash
for i in {1..5}; do
    bash tahap8-deploy-github-app.sh --app aplikasi$i --env production --update --skip-install
done
```

Quick update untuk multiple apps (skip install untuk speed).

---

## Reference

- [PM2 Documentation](https://pm2.keymetrics.io/)
- [Nginx Proxy Configuration](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Node.js Environment Variables](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)
