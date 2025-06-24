#!/bin/bash
# Executable permissions: chmod +x deploy-loadbalancer.sh

# GKE ve ArgoCD ile Flask App Deployment Script
# LoadBalancer ile erişim sağlayan deployment

set -e

# Renkli output için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Değişkenler (bu değerleri kendi projenize göre değiştirin)
PROJECT_ID="YOUR_GCP_PROJECT_ID"
CLUSTER_NAME="flask-gke-cluster"
ZONE="us-central1-a"
REGION="us-central1"
GITHUB_REPO="https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"

echo -e "${CYAN}🚀 Flask App - GKE LoadBalancer Deployment${NC}"
echo -e "${CYAN}=============================================${NC}"

# Gerekli bilgileri kullanıcıdan al
read -p "GCP Project ID: " PROJECT_ID
read -p "GKE Cluster Name (default: flask-gke-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-flask-gke-cluster}
read -p "Zone (default: us-central1-a): " ZONE
ZONE=${ZONE:-us-central1-a}
read -p "GitHub Repo URL: " GITHUB_REPO

echo -e "${BLUE}📝 Konfigürasyon:${NC}"
echo -e "Project ID: ${YELLOW}$PROJECT_ID${NC}"
echo -e "Cluster: ${YELLOW}$CLUSTER_NAME${NC}"
echo -e "Zone: ${YELLOW}$ZONE${NC}"
echo -e "GitHub Repo: ${YELLOW}$GITHUB_REPO${NC}"
echo ""

# 1. GCP Projesi ayarla
echo -e "${BLUE}🔧 GCP Projesi ayarlanıyor...${NC}"
gcloud config set project $PROJECT_ID

# 2. Gerekli API'leri etkinleştir
echo -e "${BLUE}🔌 Gerekli API'ler etkinleştiriliyor...${NC}"
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com

# 3. GKE Cluster'a bağlan
echo -e "${BLUE}🔗 GKE Cluster'a bağlanılıyor...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# 4. ArgoCD kurulumunu kontrol et
echo -e "${BLUE}🔍 ArgoCD kurulumu kontrol ediliyor...${NC}"
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}📦 ArgoCD kuruluyor...${NC}"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo -e "${YELLOW}⏳ ArgoCD'nin hazır olması bekleniyor...${NC}"
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    
    # ArgoCD Server'i LoadBalancer olarak expose et
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
else
    echo -e "${GREEN}✅ ArgoCD zaten kurulu${NC}"
fi

# 5. Docker image'i güncelle
echo -e "${BLUE}🐳 Docker image deployment.yaml'da güncelleniyor...${NC}"
sed -i "s/PROJECT_ID/$PROJECT_ID/g" k8s/deployment.yaml

# 6. ArgoCD Application'da repo URL'yi güncelle
echo -e "${BLUE}📱 ArgoCD Application repo URL'si güncelleniyor...${NC}"
sed -i "s|https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git|$GITHUB_REPO|g" argocd/application.yaml

# 7. ArgoCD Application'ı deploy et
echo -e "${BLUE}🚀 ArgoCD Application deploy ediliyor...${NC}"
kubectl apply -f argocd/application.yaml

# 8. Application'ın sync olmasını bekle
echo -e "${BLUE}⏳ Application sync'i bekleniyor...${NC}"
sleep 10

# 9. Deployment durumunu kontrol et
echo -e "${BLUE}🔍 Deployment durumu kontrol ediliyor...${NC}"
kubectl rollout status deployment/flask-app -n default --timeout=300s

# 10. Service'in External IP'sini bekle
echo -e "${BLUE}🌐 LoadBalancer External IP bekleniyor...${NC}"
echo -e "${YELLOW}Bu işlem birkaç dakika sürebilir...${NC}"

external_ip=""
while [ -z $external_ip ]; do
    echo "LoadBalancer External IP bekleniyor..."
    external_ip=$(kubectl get svc flask-app-service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$external_ip" ] && sleep 10
done

# 11. ArgoCD External IP'sini al
echo -e "${BLUE}🔍 ArgoCD External IP alınıyor...${NC}"
argocd_ip=""
while [ -z $argocd_ip ]; do
    echo "ArgoCD LoadBalancer External IP bekleniyor..."
    argocd_ip=$(kubectl get svc argocd-server -n argocd --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$argocd_ip" ] && sleep 10
done

# 12. ArgoCD admin şifresi
argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${GREEN}🎉 Deployment başarıyla tamamlandı!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${PURPLE}📱 Flask Uygulaması:${NC}"
echo -e "URL: ${CYAN}http://$external_ip${NC}"
echo -e "Health Check: ${CYAN}http://$external_ip/health${NC}"
echo ""
echo -e "${PURPLE}🎯 ArgoCD Dashboard:${NC}"
echo -e "URL: ${CYAN}https://$argocd_ip${NC}"
echo -e "Username: ${YELLOW}admin${NC}"
echo -e "Password: ${YELLOW}$argocd_password${NC}"
echo ""
echo -e "${PURPLE}🔧 Faydalı Komutlar:${NC}"
echo -e "Pods durumu: ${CYAN}kubectl get pods${NC}"
echo -e "Services durumu: ${CYAN}kubectl get svc${NC}"
echo -e "ArgoCD Apps: ${CYAN}kubectl get applications -n argocd${NC}"
echo -e "Logs: ${CYAN}kubectl logs -l app=flask-app${NC}"
echo ""
echo -e "${GREEN}✅ Uygulamanız LoadBalancer IP üzerinden erişilebilir durumda!${NC}"
