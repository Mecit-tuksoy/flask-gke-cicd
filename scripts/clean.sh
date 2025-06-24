#!/bin/bash

set -euo pipefail

echo "🧹 GCP kaynak temizleme scripti başlatıldı."

# 🔍 Gerekli parametreler
PROJECT_ID="weather-app-463611"
REGION="us-central1"
CLUSTER_NAME="weather-app-cluster"
KEY_FILE="gcp-key.json"

# ⚠️ Emniyet kontrolü: gerçekten silmek istediğinizden emin misiniz?
read -p "✅ [$PROJECT_ID] projesindeki '$CLUSTER_NAME' kümesini ve servisleri silmek istediğinize emin misiniz? (yes/[no]) " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ İşlem iptal edildi."
  exit 0
fi

# 🔐 Hizmet hesabıyla kimlik doğrulama (eğer henüz yapılmadıysa)
if [[ -f "$KEY_FILE" ]]; then
  gcloud auth activate-service-account --key-file="$KEY_FILE"
else
  echo "⚠️ '$KEY_FILE' bulunamadı; mevcut kullanıcıyla devam ediliyor."
fi

# 📌 Proje ayarı
gcloud config set project "$PROJECT_ID"

# 1️⃣ GKE kümesini sil
echo "⏳ GKE kümesi siliniyor: $CLUSTER_NAME ($REGION)"
gcloud container clusters delete "$CLUSTER_NAME" \
  --region "$REGION" \
  --quiet
echo "✅ Kümeyle ilgili kaynaklar silindi."

# 2️⃣ GCP servislerini devre dışı bırak (isteğe bağlı)
echo "⏳ İlgili API servisleri devre dışı bırakılıyor..."
gcloud services disable \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  --quiet
echo "✅ API servisleri devre dışı bırakıldı."

# 3️⃣ Hizmet hesabı kimliğini geri çek
if [[ -f "$KEY_FILE" ]]; then
  echo "🔐 Hizmet hesabı kimliği geri çekiliyor..."
  gcloud auth revoke --all
  echo "✅ Hizmet hesabı erişimi kaldırıldı."
fi

# 4️⃣ Yerel dosyaları temizle
echo "🗑️ Yerel konfigürasyon ve anahtar dosyaları temizleniyor..."
kubectl config delete-context "gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}" || true
kubectl config unset users.gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME} || true
kubectl config unset clusters.gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME} || true
rm -f "$KEY_FILE"
echo "✅ Yerel konfigürasyon ve anahtar dosyaları silindi."

echo "🎉 Tüm kaynaklar başarıyla temizlendi."
