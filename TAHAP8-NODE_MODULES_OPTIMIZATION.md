# Tahap 8: Deploy GitHub + Node_Modules Optimization

## Gambaran Lengkap

Workflow deployment Anda sekarang mencakup:

1. **GitHub Clone** → `repos/aplikasi1/` (source)
2. **Install Dependencies** di repos (full: dev + prod)
3. **Optimize Node_Modules** dengan hybrid strategy
4. **Copy ke Staging/Production** 
5. **PM2 Management** & Health check

---

## Problem yang Solved: 45GB → 18GB Disk Savings

### Before (Tanpa Optimization)
```
repos/aplikasi1/node_modules        ~500MB (dev + prod)
repos/aplikasi2/node_modules        ~500MB (dev + prod)
...
staging/aplikasi1/node_modules      ~500MB (copy, dev + prod)
staging/aplikasi2/node_modules      ~500MB (copy, dev + prod)
...
production/aplikasi1/node_modules   ~500MB (copy, dev + prod)
production/aplikasi2/node_modules   ~500MB (copy, dev + prod)
...

Total: 30 apps × 1.5GB per app = ~45GB ❌
```

### After (Dengan Optimization)
```
repos/aplikasi1/node_modules              ~500MB (dev + prod)
repos/aplikasi2/node_modules              ~500MB (dev + prod)
...
staging/aplikasi1/node_modules     → symlink ke repos (0MB)
staging/aplikasi2/node_modules     → symlink ke repos (0MB)
...
production/aplikasi1/node_modules         ~100MB (prod only)
production/aplikasi2/node_modules         ~100MB (prod only)
...

Total: (30 × 500MB) + (30 × 100MB) = ~18GB ✅ (60% savings!)
```

---

## Hybrid Strategy Explained

### 1️⃣ Repos Directory (Source)
```
~/apps/repos/aplikasi1/
├── .git/
├── package.json
├── package-lock.json
├── node_modules/          ← Full install (npm ci)
│   ├── dev-dependencies   ✓ Includes
│   └── prod-dependencies  ✓ Includes
└── src/
```

**Why:** Full install needed because developer might test/build with dev tools

---

### 2️⃣ Staging Directory (Symlinked)
```
~/apps/staging/aplikasi1/
├── package.json
├── package-lock.json
├── node_modules/          ← Symlink to repos!
│   └── → ~/apps/repos/aplikasi1/node_modules
└── src/
```

**Why:** 
- Staging = testing environment sebelum production
- Perlu full deps sama seperti development
- Symlink = zero disk space overhead
- Still can test build process, dev tools, etc

**Limitation:** Jangan modify staging/node_modules (affects repos)

---

### 3️⃣ Production Directory (Independent)
```
~/apps/production/aplikasi1/
├── package.json
├── package-lock.json
├── node_modules/          ← Independent install (npm ci --production)
│   └── prod-dependencies only ✓
└── dist/ (atau app files)
```

**Why:**
- Production = production-only, smaller footprint
- Tidak perlu dev dependencies (webpack, babel, typescript, etc)
- Independent copy = tidak tergantung repos
- Safer: even if repos deleted, production still works

---

## Implementation Roadmap

### Step 1: Copy Helper Scripts to VPS

```bash
# On your local machine
scp -P 2222 node_modules-optimizer.sh develme_rf@43.157.201.129:~/apps/
scp -P 2222 disk-usage-report.sh develme_rf@43.157.201.129:~/apps/
scp -P 2222 tahap8-deploy-github-app.sh develme_rf@43.157.201.129:~/
```

### Step 2: Make Executable
```bash
ssh -p 2222 develme_rf@43.157.201.129

cd ~/apps
chmod +x node_modules-optimizer.sh disk-usage-report.sh
chmod +x ~/tahap8-deploy-github-app.sh
```

### Step 3: Deploy First App (aplikasi1)

```bash
# Deploy aplikasi1 ke staging (dengan optimization)
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --repo git@github.com:bangroy-1167/aplikasi1.git \
  --env staging

# Result:
# ✓ repos/aplikasi1/ cloned dari GitHub
# ✓ npm ci di repos (full install)
# ✓ Optimizer creates: staging/aplikasi1/node_modules → symlink
# ✓ Optimizer creates: production/aplikasi1/node_modules (prod-only)
# ✓ Application running on port 3001
```

### Step 4: Verify Optimization

```bash
# Check current status
bash ~/apps/node_modules-optimizer.sh aplikasi1 report

# Output: 
# Repos: ~500MB
# Staging: 0MB (symlink)
# Production: ~100MB
# Total: ~600MB (vs 1.5GB without)
```

### Step 5: Monitor Disk Usage

```bash
# Summary view
bash ~/apps/disk-usage-report.sh

# Detailed view
bash ~/apps/disk-usage-report.sh --detailed

# Sorted by size
bash ~/apps/disk-usage-report.sh --sort

# Save report to file
bash ~/apps/disk-usage-report.sh --detailed --save-report
```

---

## Command Reference

### Deploy New Application

```bash
# Deploy ke production dengan optimization (default)
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --repo git@github.com:user/aplikasi1.git \
  --env production

# Deploy ke staging dulu
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi2 \
  --repo git@github.com:user/aplikasi2.git \
  --env staging

# Deploy tanpa optimization (jika ada masalah)
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi3 \
  --repo git@github.com:user/aplikasi3.git \
  --env production \
  --no-optimize
```

### Update Existing Application

```bash
# Pull latest dari GitHub dan deploy
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --env production \
  --update

# Update + re-optimize
bash ~/tahap8-deploy-github-app.sh \
  --app aplikasi1 \
  --env production \
  --update
# (optimization runs automatically unless --no-optimize)
```

### Node Modules Optimizer

```bash
# Setup optimization untuk satu app
bash ~/apps/node_modules-optimizer.sh aplikasi1 init

# Setup untuk semua apps sekaligus
bash ~/apps/node_modules-optimizer.sh all init

# Lihat status
bash ~/apps/node_modules-optimizer.sh aplikasi1 report
bash ~/apps/node_modules-optimizer.sh all report

# Revert symlinks (restore independent installs)
bash ~/apps/node_modules-optimizer.sh aplikasi1 revert
```

### Disk Usage Report

```bash
# Summary
bash ~/apps/disk-usage-report.sh

# Detailed breakdown
bash ~/apps/disk-usage-report.sh --detailed

# Sorted by size (largest first)
bash ~/apps/disk-usage-report.sh --sort

# Save detailed report
bash ~/apps/disk-usage-report.sh --detailed --save-report
# File saved to: ~/apps/.disk-usage-report-YYYYMMDD-HHMMSS.txt
```

### PM2 Management

```bash
# View all apps
pm2 list

# Logs untuk satu app
pm2 logs aplikasi1

# Logs untuk staging app
pm2 logs staging-aplikasi1

# Monitor realtime
pm2 monit

# Restart app
pm2 restart aplikasi1

# Stop app
pm2 stop aplikasi1

# Delete app
pm2 delete aplikasi1
```

---

## Workflow Examples

### Scenario 1: Deploy 3 Apps dari Awal

```bash
# App 1
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --repo git@github.com:user/app1.git --env staging
# Test staging
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update

# App 2
bash ~/tahap8-deploy-github-app.sh --app aplikasi2 --repo git@github.com:user/app2.git --env production

# App 3
bash ~/tahap8-deploy-github-app.sh --app aplikasi3 --repo git@github.com:user/app3.git --env production

# Check disk savings
bash ~/apps/disk-usage-report.sh --summary
```

### Scenario 2: Update Single App & Check

```bash
# Pull latest
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update

# Verify health
pm2 logs aplikasi1 --lines 20

# Check disk impact
bash ~/apps/node_modules-optimizer.sh aplikasi1 report
```

### Scenario 3: Bulk Deploy Multiple Apps

```bash
#!/bin/bash
# bulk-deploy.sh

APPS=("aplikasi1" "aplikasi2" "aplikasi3" "aplikasi4" "aplikasi5")

for app in "${APPS[@]}"; do
    echo "Deploying $app..."
    bash ~/tahap8-deploy-github-app.sh \
        --app "$app" \
        --repo git@github.com:user/"$app".git \
        --env production
    
    sleep 5  # Wait between deploys
done

# Report final disk usage
bash ~/apps/disk-usage-report.sh --summary
```

---

## Troubleshooting

### Problem: Staging Modified, Repos Affected

**Cause:** Staging is symlinked to repos, any changes affect both

**Solution:**
```bash
# Remove symlink and restore independent copy
bash ~/apps/node_modules-optimizer.sh aplikasi1 revert

# Now staging has independent node_modules
# Changes to staging/node_modules won't affect repos
```

### Problem: High Disk Usage Despite Optimization

**Diagnosis:**
```bash
# Check current status
bash ~/apps/disk-usage-report.sh --detailed

# Check which apps aren't optimized
bash ~/apps/node_modules-optimizer.sh all report
```

**Solution:**
```bash
# Optimize remaining apps
bash ~/apps/node_modules-optimizer.sh all init

# Or optimize per-app
bash ~/apps/node_modules-optimizer.sh aplikasi1 init
bash ~/apps/node_modules-optimizer.sh aplikasi2 init
```

### Problem: npm install Failures

**Cause:** Network issues, missing package.json, bad credentials

**Solution:**
```bash
# Retry with --skip-install for existing node_modules
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --skip-install

# Or manually fix in production directory
cd ~/apps/production/aplikasi1
npm ci
```

### Problem: PM2 App Not Starting

**Diagnosis:**
```bash
# Check PM2 logs
pm2 logs aplikasi1

# Check if port is in use
sudo netstat -tulnp | grep :3001

# Check application logs
cat /var/log/pm2/aplikasi1.error.log
cat /var/log/pm2/aplikasi1.out.log
```

**Solution:**
```bash
# Restart app
pm2 restart aplikasi1

# Or rebuild from scratch
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

---

## Best Practices

### 1. Always Test in Staging First
```bash
# Deploy to staging
bash ~/tahap8-deploy-github-app.sh --app app --repo <url> --env staging

# Test thoroughly
curl http://localhost:3001/health
pm2 logs staging-app

# Then promote to production
bash ~/tahap8-deploy-github-app.sh --app app --env production --update
```

### 2. Monitor Disk Weekly
```bash
# Add to crontab (run weekly)
0 0 * * 0 bash /home/develme_rf/apps/disk-usage-report.sh --detailed --save-report
```

### 3. Keep Repos Updated
```bash
# Before deployment, pull latest
cd ~/apps/repos/aplikasi1
git pull origin main

# Or let script handle it automatically
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

### 4. Archive Old Deployments
```bash
# Before deploying new version, backup old
cp -r ~/apps/production/aplikasi1 ~/apps/production/aplikasi1-backup-2026-07-08

# Then deploy new version
bash ~/tahap8-deploy-github-app.sh --app aplikasi1 --env production --update
```

### 5. Regular Health Checks
```bash
# Add to crontab (run daily)
0 2 * * * bash /home/develme_rf/health-check.sh

# Or run manually
bash ~/health-check.sh
```

---

## Performance Impact

### Before Optimization (45 apps scenario)
- Disk: ~67.5GB (45 × 1.5GB)
- Install time: ~45 minutes (1 min per app)
- npm ci: 45 full installs
- Storage cost: Significant

### After Optimization (45 apps scenario)
- Disk: ~27GB (45 × 600MB) - **60% reduction**
- Install time: ~30 minutes
  - Repos only: 45 apps × 1min = 45min
  - Production: 45 apps × 0.3min = 13.5min
  - Total: ~58min, but parallel possible
- npm ci: 45 repos + 45 productions (90 installs, but prod faster)
- Storage cost: Much lower

### Staging Benefit
- Zero disk overhead
- Zero install time
- Access to dev dependencies for testing
- Symlink-safe for read-only operations

---

## Migration Path (Jika Sudah Deploy)

Jika Anda sudah deploy aplikasi tanpa optimization:

```bash
# 1. Check current status
bash ~/apps/disk-usage-report.sh

# 2. Optimize satu per satu
bash ~/apps/node_modules-optimizer.sh aplikasi1 init
bash ~/apps/node_modules-optimizer.sh aplikasi2 init
# ... dst

# Atau batch
bash ~/apps/node_modules-optimizer.sh all init

# 3. Verify
bash ~/apps/disk-usage-report.sh

# 4. Cleanup (optional, if symlinks worked)
# Done! Old node_modules removed during optimization
```

---

## Summary

| Aspek | Tanpa Optimization | Dengan Optimization |
|-------|-------------------|---------------------|
| **Disk per app** | 1.5GB | 600MB |
| **30 apps total** | 45GB | 18GB |
| **Staging strategy** | Independent copy | Symlink |
| **Production strategy** | Full install | Prod-only |
| **Deploy time** | Long | Medium |
| **Maintenance** | Simple | Simple |
| **Disk savings** | - | **60%** ✅ |

---

## Next Steps

1. ✅ Copy scripts to VPS
2. ✅ Deploy aplikasi1 dengan Tahap 8 updated
3. ✅ Verify optimization dengan disk-usage-report.sh
4. ✅ Deploy aplikasi2-5
5. ✅ Monitor disk weekly
6. 🔄 Return to Tahap 5 untuk SSL setup (wildcard + DNS plugin)
7. 🔄 Create full-setup.sh untuk all-in-one automation
