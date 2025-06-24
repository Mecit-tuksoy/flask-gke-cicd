Bu rehber, Flask uygulamanızı Google Kubernetes Engine (GKE) üzerinde GitHub Actions ve ArgoCD kullanarak tamamen otomatik bir CI/CD pipeline ile deploy etmeniz için gereken tüm adımları içermektedir.

## 📋 İçindekiler

1. [Ön Hazırlıklar](#ön-hazırlıklar)
2. [Google Cloud Platform Kurulumu](#google-cloud-platform-kurulumu)
3. [GitHub Repository Kurulumu](#github-repository-kurulumu)
4. [GitHub Secrets Konfigürasyonu](#github-secrets-konfigürasyonu)
5. [ArgoCD Kurulumu ve Konfigürasyonu](#argocd-kurulumu-ve-konfigürasyonu)
6. [Deployment Testi](#deployment-testi)
7. [Monitoring ve Observability](#monitoring-ve-observability)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## 🚀 Ön Hazırlıklar.

### Gerekli Araçlar

1. **Google Cloud CLI** - [Kurulum](https://cloud.google.com/sdk/docs/install)
2. **kubectl** - [Kurulum](https://kubernetes.io/docs/tasks/tools/)
3. **ArgoCD CLI** - [Kurulum](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
4. **Docker** - [Kurulum](https://docs.docker.com/get-docker/)
5. **Git** - [Kurulum](https://git-scm.com/downloads)

### Hesap Gereksinimleri

- Google Cloud Platform hesabı (billing etkin)
- GitHub hesabı
- Domain adı (SSL sertifikası için - opsiyonel)

## ☁️ Google Cloud Platform Kurulumu

### 1. Proje Oluşturma ve Temel Ayarlar

```bash
# gcloud CLI ile giriş yapın
gcloud auth login

# Yeni proje oluşturun (veya mevcut projeyi kullanın)
export PROJECT_ID=\"your-unique-project-id\"
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# Billing hesabını projeye bağlayın (GCP Console'dan yapılmalı)
```

### 2. Otomatik Kurulum Scripti Çalıştırma

Proje kök dizininde bulunan setup scriptini çalıştırın:

```bash
chmod +x scripts/setup-gcp.sh
# Script içindeki değişkenleri kendi proje bilgilerinize göre düzenleyin
nano scripts/setup-gcp.sh
./scripts/setup-gcp.sh
```

### 3. Manuel Kurulum (Alternatif)

Otomatik script çalışmazsa, aşağıdaki adımları manuel olarak uygulayın:

```bash
# Değişkenler
export PROJECT_ID=\"your-project-id\"
export CLUSTER_NAME=\"flask-gke-cluster\"
export ZONE=\"us-central1-a\"
export SERVICE_ACCOUNT_NAME=\"gke-github-actions\"

# Gerekli API'ları etkinleştir
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable iam.googleapis.com

# GKE Cluster oluştur
gcloud container clusters create $CLUSTER_NAME \\
    --zone=$ZONE \\
    --machine-type=e2-medium \\
    --num-nodes=3 \\
    --enable-autorepair \\
    --enable-autoupgrade \\
    --enable-autoscaling \\
    --min-nodes=1 \\
    --max-nodes=5 \\
    --enable-network-policy \\
    --enable-ip-alias

# Service Account oluştur
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \\
    --description=\"Service account for GitHub Actions GKE deployment\" \\
    --display-name=\"GKE GitHub Actions\"

# Gerekli rolleri ata
gcloud projects add-iam-policy-binding $PROJECT_ID \\
    --member=\"serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com\" \\
    --role=\"roles/container.developer\"

gcloud projects add-iam-policy-binding $PROJECT_ID \\
    --member=\"serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com\" \\
    --role=\"roles/storage.admin\"

gcloud projects add-iam-policy-binding $PROJECT_ID \\
    --member=\"serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com\" \\
    --role=\"roles/container.clusterAdmin\"

# Service Account key oluştur
gcloud iam service-accounts keys create ./gke-key.json \\
    --iam-account=\"${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com\"

# Static IP oluştur (Ingress için)
gcloud compute addresses create flask-app-ip --global

# Cluster credentials al
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

## 📦 GitHub Repository Kurulumu

### 1. Repository Oluşturma

1. GitHub'da yeni bir repository oluşturun
2. Bu projeyi kendi repository'nize push edin:

```bash
git init
git add .
git commit -m \"Initial commit\"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git branch -M main
git push -u origin main
```

### 2. Gerekli Dosyaları Güncelleme

#### ArgoCD Application Konfigürasyonu

`argocd/application.yaml` dosyasını güncelleyin:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
```

#### Ingress Konfigürasyonu (Domain kullanıyorsanız)

`k8s/ingress.yaml` dosyasını güncelleyin:

```yaml
spec:
  rules:
    - host: your-actual-domain.com
```

## 🔐 GitHub Secrets Konfigürasyonu

GitHub repository'nizde Settings > Secrets and variables > Actions'a gidin ve aşağıdaki secrets'ları ekleyin:

### Gerekli Secrets

| Secret Name      | Value                | Açıklama                           |
| ---------------- | -------------------- | ---------------------------------- |
| `GCP_PROJECT_ID` | your-project-id      | Google Cloud Project ID            |
| `GCP_SA_KEY`     | Service Account JSON | Base64 encoded service account key |

### Service Account Key'i Base64'e Çevirme

```bash
# Linux/macOS
cat gke-key.json | base64 -w 0

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes(\"gke-key.json\"))
```

### Environment Secrets (Opsiyonel)

Production environment için:

1. Settings > Environments > New environment
2. Environment name: `production`
3. Yukarıdaki secrets'ları bu environment'a da ekleyin

## 🎯 ArgoCD Kurulumu ve Konfigürasyonu

### 1. ArgoCD Kurulumu

```bash
chmod +x scripts/setup-argocd.sh
./scripts/setup-argocd.sh
```

### 2. ArgoCD'ye Erişim

#### Port Forward ile (Yerel erişim)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

https://localhost:8080 adresinden erişin.

#### LoadBalancer ile (Harici erişim)

```bash
# External IP'yi kontrol edin
kubectl get svc argocd-server -n argocd
```

### 3. ArgoCD Login

```bash
# Admin şifresini alın
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d

# CLI ile login
argocd login <ARGOCD_SERVER_IP>
# Username: admin
# Password: yukarıda aldığınız şifre
```

### 4. Application Oluşturma

```bash
# Application'ı oluştur
kubectl apply -f argocd/application.yaml

# Sync'i başlat
argocd app sync flask-app
```

## 🚀 Deployment Testi

### GitHub Actions Pipeline Tetikleme

1. Kod değişikliği yapın:

```bash
echo \"# Test deployment\" >> README.md
git add .
git commit -m \"Test deployment\"
git push origin main
```

2. GitHub Actions tab'ından build progress'i takip edin

3. ArgoCD'de application durumunu kontrol edin:

```bash
argocd app get flask-app
kubectl get pods -l app=flask-app
kubectl get svc flask-app-service
```

### Uygulama Erişimi

#### LoadBalancer IP ile:

```bash
kubectl get svc flask-app-service
# External IP'yi not edin ve tarayıcıda açın
```

#### Port Forward ile:

```bash
kubectl port-forward svc/flask-app-service 8080:80
# http://localhost:8080 adresinden erişin
```

## 📊 Monitoring ve Observability

### ArgoCD Monitoring

```bash
# Application durumu
argocd app get flask-app

# Sync history
argocd app history flask-app

# Application logs
argocd app logs flask-app
```

### Kubernetes Monitoring

```bash
# Pod durumları
kubectl get pods -l app=flask-app

# Pod logs
kubectl logs -l app=flask-app

# Service endpoints
kubectl get endpoints flask-app-service

# Ingress durumu
kubectl get ingress flask-app-ingress
```

### Grafana ve Prometheus (Opsiyonel)

Monitoring klasöründeki konfigürasyonları kullanabilirsiniz:

```bash
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana.yaml
```

## 🔧 Troubleshooting

### Yaygın Sorunlar ve Çözümleri

#### 1. GitHub Actions Build Hatası

```bash
# Service account permissions kontrol
gcloud projects get-iam-policy $PROJECT_ID

# Cluster erişimi kontrol
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

#### 2. ArgoCD Sync Hatası

```bash
# Application durumu detayları
argocd app get flask-app --show-operation

# Manual sync
argocd app sync flask-app --prune

# Hard refresh
argocd app sync flask-app --force
```

#### 3. Pod Başlatma Sorunları

```bash
# Pod logs
kubectl logs -l app=flask-app

# Pod describe
kubectl describe pods -l app=flask-app

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### 4. Image Pull Sorunları

```bash
# GCR permissions kontrol
gcloud auth configure-docker

# Image var mı kontrol
gcloud container images list --repository=gcr.io/$PROJECT_ID
```

#### 5. Service Erişim Sorunları

```bash
# Service endpoints
kubectl get endpoints flask-app-service

# Network policies
kubectl get networkpolicies

# DNS resolution
kubectl run debug --image=busybox --rm -it -- nslookup flask-app-service
```

## 🏆 Best Practices

### Güvenlik

1. **Service Account Minimum Permissions**: Sadece gerekli rolleri verin
2. **Secret Management**: Sensitive data'yı asla kod içinde tutmayın
3. **Network Policies**: Pod-to-pod iletişimi kısıtlayın
4. **RBAC**: Kubernetes RBAC'ı düzgün yapılandırın
5. **Image Security**: Container image'larını güvenlik açıklarına karşı tarayın

### Performance

1. **Resource Limits**: Pod'lara CPU/Memory limitleri tanımlayın
2. **Horizontal Pod Autoscaler**: Otomatik scaling kurun
3. **Readiness/Liveness Probes**: Health check'leri düzgün ayarlayın

### Operasyonel

1. **Monitoring**: Comprehensive monitoring ve alerting kurun
2. **Logging**: Centralized logging sistemi kullanın
3. **Backup**: Critical data'yı backup'layın
4. **Documentation**: Deployment process'i dokümante edin

### GitOps

1. **Single Source of Truth**: Tüm konfigürasyonlar Git'te olsun
2. **Separate Repos**: Application code ve infrastructure code'u ayırın
3. **Environment Parity**: Staging/Production ortamları aynı olsun
4. **Rollback Strategy**: Hızlı rollback mekanizması kurun
