#!/bin/bash

# Google Cloud Setup Script for GKE with ArgoCD
# Bu script'i çalıştırmadan önce gcloud CLI'ı yükleyin ve giriş yapın

set -e

# Değişkenler - Bu değerleri kendi projenize göre güncelleyin
PROJECT_ID="new-app-463912"
CLUSTER_NAME="flask-gke-cluster"
REGION="us-central1"
ZONE="us-central1-a"
NODE_POOL_NAME="default-pool"
MACHINE_TYPE="e2-medium"
NUM_NODES=1
SERVICE_ACCOUNT_NAME="gke-github-actions"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🚀 Google Cloud GKE kurulumu başlıyor..."

# 1. Projeyi ayarla
echo "📝 Proje ayarlanıyor: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# 2. Gerekli API'ları etkinleştir
echo "🔧 Gerekli API'lar etkinleştiriliyor..."
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable iam.googleapis.com

# 3. GKE Cluster oluştur
echo "🏗️  GKE Cluster oluşturuluyor..."
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --num-nodes=$NUM_NODES \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-network-policy \
    --enable-ip-alias \
    --disk-size=20GB \
    --disk-type=pd-standard

# 4. Cluster credentials'ları al
echo "🔑 Cluster credentials alınıyor..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# 5. Service Account oluştur
echo "👤 Service Account oluşturuluyor..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --description="Service account for GitHub Actions GKE deployment" \
    --display-name="GKE GitHub Actions"

# 6. Service Account'a gerekli roller ver
echo "🔐 Service Account'a roller atanıyor..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/container.clusterAdmin"

# 7. Service Account key oluştur
echo "🗝️  Service Account key oluşturuluyor..."
gcloud iam service-accounts keys create ./gke-key.json \
    --iam-account=$SERVICE_ACCOUNT_EMAIL

# 8. Static IP oluştur (Ingress için)
echo "🌐 Static IP oluşturuluyor..."
gcloud compute addresses create flask-app-ip --global

# 9. ArgoCD'yi kur
echo "🎯 ArgoCD kurulumu başlıyor..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD CLI kurulum talimatları
echo "📥 ArgoCD CLI'ı kurmak için:"
echo "Linux/WSL:"
echo "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
echo ""
echo "macOS:"
echo "brew install argocd"

# 10. ArgoCD admin şifresini al
echo "⏳ ArgoCD'nin hazır olması bekleniyor..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🔑 ArgoCD admin şifresi alınıyor..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "✅ Kurulum tamamlandı!"
echo ""
echo "📋 Önemli Bilgiler:"
echo "==================="
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Zone: $ZONE"
echo "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
echo "Static IP Name: flask-app-ip"
echo ""
echo "🔐 GitHub Secrets'a eklenecek değerler:"
echo "GCP_PROJECT_ID: $PROJECT_ID"
echo "GCP_SA_KEY: $(cat ./gke-key.json | base64 -w 0)"
echo ""
echo "🎯 ArgoCD Bilgileri:"
echo "Namespace: argocd"
echo "Admin Username: admin"
echo "Admin Password: $ARGOCD_PASSWORD"
echo ""
echo "🌐 ArgoCD'ye erişim için port-forward:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Ardından https://localhost:8080 adresine gidin"
echo ""
echo "📝 Sonraki adımlar:"
echo "1. GitHub repository'nizde Secrets'ları ayarlayın"
echo "2. argocd/application.yaml dosyasındaki repo URL'sini güncelleyin"
echo "3. k8s/ingress.yaml dosyasındaki domain'i güncelleyin"
echo "4. ArgoCD'de application'ı oluşturun"

# Güvenlik için key dosyasını sil
echo ""
echo "⚠️  Güvenlik: Service account key dosyası siliniyor..."
rm -f ./gke-key.json

echo ""
echo "🎉 Kurulum başarıyla tamamlandı!"
