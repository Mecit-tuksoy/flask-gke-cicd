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

echo "⚠️  $CLUSTER_NAME adlı cluster siliniyor…"

# 🔧 Proje ayarı
gcloud config set project "$PROJECT_ID"

# 🗑️ Cluster silme
gcloud container clusters delete "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --quiet

echo "✅ Cluster '$CLUSTER_NAME' başarıyla silindi."
