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
    --role="roles/artifactregistry.writer"

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
