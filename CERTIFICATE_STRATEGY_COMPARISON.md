# Certificate Strategy Comparison untuk Multi-App Deployment

## Ringkasan Cepat

| Aspek | Single Cert | Per-Subdomain | Wildcard |
|-------|------------|-----------------|----------|
| **Setup** | Paling mudah | Medium | Paling rumit |
| **Maintenance** | Minimal | Medium | Minimal |
| **Cost** | $0 (Let's Encrypt) | $0 (Let's Encrypt) | $0 (Let's Encrypt) |
| **Disk** | 1 cert | 30 certs | 1 cert |
| **Renewal** | 1x renewal | 30x renewal | 1x renewal |
| **Skalabilitas** | Terbatas | Sedang | Terbaik |
| **Kompleksitas DNS** | Simple | Simple | **Medium** (DNS challenge) |

---

## Strategi 1: Single Certificate (Paling Sederhana)

### Deskripsi
Satu certificate untuk main domain + www.domain saja. Semua subdomain (aplikasi1, aplikasi2, dll) tidak ter-cover HTTPS.

```
Certificate covers:
  ✓ sv1.thinking.my.id
  ✓ www.sv1.thinking.my.id
  ✗ aplikasi1.sv1.thinking.my.id  ← SSL ERROR
  ✗ aplikasi2.sv1.thinking.my.id  ← SSL ERROR
```

### Implementasi
```bash
certbot certonly \
  --agree-tos \
  --email admin@sv1.thinking.my.id \
  --nginx \
  --non-interactive \
  -d sv1.thinking.my.id \
  -d www.sv1.thinking.my.id
```

### ✅ Pros
1. **Setup tercepat** - Hanya 1 command, hanya 1 cert
2. **Renewal paling simpel** - Certbot hanya renew 1 cert
3. **Monitoring sederhana** - 1 cert = 1 expiry date to watch
4. **HTTP → HTTPS redirect mudah** di Nginx
5. **Ideal untuk testing** - Setup & forget

### ❌ Cons
1. **Subdomain tanpa SSL** - Browser warning untuk aplikasi1.sv1.thinking.my.id, aplikasi2, dll
2. **Mixed content issues** - Jika main domain HTTPS tapi subdomain HTTP
3. **Trust/Perception** - User lihat warning "Not Secure" di subdomain
4. **Single point of failure** - Kalau 1 cert expired, semua HTTPS mati (termasuk main domain)
5. **Tidak suitable untuk production** - Khususnya jika user langsung akses subdomain

### Use Case
- Development/Testing environment
- Internal tools (diakses via main domain saja)
- Prototype sebelum full deployment

---

## Strategi 2: Per-Subdomain Certificate (Medium Complexity)

### Deskripsi
Satu certificate untuk setiap aplikasi. Total 30 certs (1 main + 29 apps).

```
Certificates:
  sv1.thinking.my.id          → /etc/letsencrypt/live/sv1.thinking.my.id/
  aplikasi1.sv1.thinking.my.id → /etc/letsencrypt/live/aplikasi1.sv1.thinking.my.id/
  aplikasi2.sv1.thinking.my.id → /etc/letsencrypt/live/aplikasi2.sv1.thinking.my.id/
  ... (28 more)
```

### Implementasi
```bash
# Main domain
certbot certonly --agree-tos --email admin@sv1.thinking.my.id \
  --nginx --non-interactive \
  -d sv1.thinking.my.id -d www.sv1.thinking.my.id

# Setiap subdomain
for app in {1..30}; do
  certbot certonly --agree-tos --email admin@sv1.thinking.my.id \
    --webroot --webroot-path /var/www/certbot \
    --non-interactive \
    -d aplikasi${app}.sv1.thinking.my.id
done
```

### ✅ Pros
1. **Full HTTPS coverage** - Semua domain + subdomain HTTPS, zero warnings
2. **Granular control** - Bisa set expiry notification per app
3. **Production-ready** - User bisa akses via subdomain dengan secure
4. **Isolated failures** - Jika cert app1 expired, app2 masih OK
5. **Better analytics** - Bisa track SSL metrics per app

### ❌ Cons (Berat!)
1. **30x renewal complexity** - Certbot harus check & renew 30 certs setiap bulan
   - 30x validation process
   - 30x ACME challenges (jika webroot/http, masih OK; jika DNS → nightmare)
   - Risk: 1 renewal gagal = 1 app down

2. **Disk space bloat** - `/etc/letsencrypt/live/` berisi 30 direktori dengan cert + chain + key
   ```
   ~50MB per 30 certificates
   ```

3. **Nginx config kompleks** - Perlu 30 server blocks terpisah atau complex regex
   ```nginx
   # 30 upstream blocks
   # 30 ssl_certificate directives
   # Complex conditional logic
   ```

4. **Renewal hook complexity** - Perlu script untuk reload nginx setelah renewal
   ```bash
   # Harus handle: cert A renewed → reload nginx
   # Harus handle: cert B renewed → reload nginx
   # Risk: Race conditions jika 2 renewal sekaligus
   ```

5. **Monitoring burden** - Script harus monitor 30 expiry dates
   ```bash
   for i in {1..30}; do
     openssl x509 -in /etc/letsencrypt/live/aplikasi${i}.sv1.thinking.my.id/fullchain.pem \
       -noout -enddate
   done
   ```

6. **Harder scaling** - Jika tambah aplikasi31 → perlu generate cert baru, update Nginx, restart

### Saat Terbaik Dipakai
- **Medium apps** (3-5 subdomain)
- **Jika budget infinite** (paid certificates memang begini)
- **Jika WAJIB isolated monitoring** per app

### Tidak Cocok Untuk:
- **30 aplikasi** - Terlalu banyak cert untuk di-maintain
- **Dynamic deployment** - Tambah/remove app frequent

---

## Strategi 3: Wildcard Certificate (Ideal tapi Kompleks Setup)

### Deskripsi
Satu certificate untuk `*.sv1.thinking.my.id` yang cover semua subdomain apapun.

```
Certificate covers:
  ✓ sv1.thinking.my.id
  ✓ www.sv1.thinking.my.id
  ✓ aplikasi1.sv1.thinking.my.id    ← Covered!
  ✓ aplikasi2.sv1.thinking.my.id    ← Covered!
  ✓ randomnewapp.sv1.thinking.my.id ← Covered! (bisa langsung tanpa renewal)
```

### Implementasi

**Setara dengan yang gagal di script Tahap 5 Anda:**
```bash
certbot certonly \
  --agree-tos \
  --email admin@sv1.thinking.my.id \
  --preferred-challenges=dns \
  --manual-public-ip-logging-ok \
  --manual \
  -d sv1.thinking.my.id \
  -d "*.sv1.thinking.my.id"

# Akan minta: Add TXT record ke DNS untuk challenge
# TXT record: _acme-challenge.sv1.thinking.my.id = <token>
```

**Automated dengan DNS plugin (Recommended):**
```bash
# Install Tencent Cloud DNS plugin
pip install certbot-dns-tencentcloud

certbot certonly \
  --agree-tos \
  --email admin@sv1.thinking.my.id \
  --authenticator dns-tencentcloud \
  --dns-tencentcloud-credentials ~/.dns-creds \
  --dns-tencentcloud-propagation-seconds 10 \
  -d sv1.thinking.my.id \
  -d "*.sv1.thinking.my.id"
```

### ✅ Pros (Sangat Banyak)
1. **Sempurna untuk scaling** - Tambah aplikasi31, 32, 33 → HTTPS langsung, tanpa renewal
2. **1 cert = 1 renewal** - Certbot hanya perlu renew 1 kali per tahun
3. **Nginx config paling simple** - Bisa 1 server block dengan regex
   ```nginx
   server {
       listen 443 ssl http2;
       server_name ~^(?<app>.+)\.sv1\.thinking\.my\.id$;
       
       ssl_certificate /etc/letsencrypt/live/sv1.thinking.my.id/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/sv1.thinking.my.id/privkey.pem;
       
       location / {
           proxy_pass http://localhost:$app_port;
       }
   }
   ```

4. **Minimal disk** - Hanya 1 cert
5. **Monitoring trivial** - 1 expiry date
6. **Production ideal** - Full HTTPS, zero warnings, scalable

### ❌ Cons (Setup only)
1. **DNS challenge required** - Certbot harus modify TXT record di DNS
   - **Manual process** (one-time per cert): Certbot print token → user add DNS record → press enter
   - **Automated** (recommended): Install plugin, set credentials, auto-renew

2. **Initial setup lebih kompleks** - Butuh:
   - Tencent Cloud API credentials (untuk plugin)
   - `/root/.dns-creds` file configuration
   - Plugin installation

3. **Delay validation** - DNS propagation takes 10-60 seconds per validation

### Saat Terbaik Dipakai
- **30+ aplikasi** ← **YOUR CASE** ✅
- **Dynamic deployment** (sering add/remove apps)
- **Scalable infrastructure**
- **Production-grade**

---

## REKOMENDASI UNTUK KASUS ANDA

### Situasi Anda:
- 30 aplikasi (aplikasi1 s/d aplikasi30)
- Setiap app = subdomain (aplikasi1.sv1.thinking.my.id, dll)
- Rencana future scaling
- Ingin minimize maintenance

### ✅ **RECOMMENDED: Wildcard + DNS Plugin**

**Why:**
1. **Setup** mungkin lebih kompleks, tapi **SATU KALI SAJA** (setup is painful, maintenance is painless)
2. **Renewal** otomatis & trivial (1x per tahun)
3. **Add aplikasi baru** → instant HTTPS, zero effort
4. **Scaling limitless** - bisa 50, 100, 300 apps
5. **Production-ready** - user experience terbaik

**Effort breakdown:**
- Setup: 30 menit (including Tencent Cloud API setup)
- Maintenance: ~5 menit per year (renewal auto-runs)

---

### Alternatif (Jika DNS Plugin Bermasalah):

**2nd Choice: Single Certificate (sementara)**
- Setup cepat (5 menit)
- Main domain + www protected
- Subdomain akan warning tapi functional
- Later: upgrade ke wildcard setelah get used to system

**3rd Choice: Per-subdomain** 
- **DO NOT RECOMMEND** untuk 30 apps
- Hanya jika absolutely need isolated certs

---

## Implementasi Roadmap

### Phase 1 (Now): Use Single Certificate
```bash
# Cepat, testing dulu
certbot certonly --nginx \
  -d sv1.thinking.my.id \
  -d www.sv1.thinking.my.id
```

### Phase 2 (Later): Upgrade ke Wildcard
```bash
# Setelah comfortable dengan sistem
pip install certbot-dns-tencentcloud
# Setup DNS credentials
# Deploy wildcard cert
```

### Phase 3 (Future): Full automation
- Auto-renewal every 60 days
- Auto-deploy ke all 30 apps (zero downtime)

---

## Script Checklist

**Untuk Phase 1 (Single Cert) - Butuh:**
```bash
tahap5-ssl-https-setup-simple.sh
  └─ Input: domain, email
  └─ Generate: 1 cert (main + www)
  └─ Update: Nginx config (all apps HTTP redirect ke main)
  └─ Result: Main domain HTTPS, subdomain HTTPS warning
```

**Untuk Phase 2 (Wildcard) - Butuh:**
```bash
tahap5b-ssl-wildcard-dns-plugin.sh
  └─ Install: certbot DNS plugin
  └─ Setup: Tencent Cloud credentials
  └─ Generate: wildcard cert
  └─ Update: Nginx config (full HTTPS everywhere)
```

---

## Summary Table - Untuk Keputusan Cepat

| Keputusan | Waktu Setup | Maintenance | Scaling | Recommendation |
|-----------|-------------|-------------|---------|-----------------|
| **Single** | ⚡ 5 min | ✓ Easy | ✗ Limited | ✓ Start here |
| **Per-Sub** | ⏱ 30 min | ✗✗ Nightmare | ✗ Bad | ✗ Avoid |
| **Wildcard** | ⏱ 30 min | ✓ Easy | ✓✓ Excellent | ✓✓ End goal |

**Best Path:** Single (testing) → Wildcard (production)
