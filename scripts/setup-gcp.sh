#!/bin/bash
set -e

# 🔍 Key kontrolü
if [ ! -f gcp-key.json ]; then
  echo "❌ ERROR: 'gcp-key.json' yok. Lütfen script dizinine koyun."
  exit 1
fi

# 🔐 Auth
gcloud auth activate-service-account --key-file=gcp-key.json

# Değişkenler
PROJECT_ID="new-app-463912"
ZONE="us-central1-a"
CLUSTER_NAME="flask-gke-cluster"

echo "🚀 GKE kurulumu başlıyor…"

# 1️⃣ Proje ayarı
gcloud config set project "$PROJECT_ID"

# 2️⃣ API’ları aç
gcloud services enable container.googleapis.com \
                      artifactregistry.googleapis.com

# 3️⃣ Cluster oluştur
gcloud container clusters create "$CLUSTER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --num-nodes 1 \
  --machine-type e2-small \
  --disk-size 20 \
  --disk-type pd-standard \
  --release-channel stable

# 4️⃣ Credentials al
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE"

echo "✅ Cluster hazır! 🎉"
