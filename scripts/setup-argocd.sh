#!/bin/bash

# ArgoCD Setup Script
# Bu script ArgoCD'yi kurup yapılandırır

set -e

echo "🎯 ArgoCD kurulum ve yapılandırma başlıyor..."

# 1. ArgoCD namespace'ini oluştur
echo "📝 ArgoCD namespace oluşturuluyor..."
kubectl create namespace argocd || echo "Namespace zaten mevcut"

# 2. ArgoCD'yi kur
echo "📦 ArgoCD kurulumu yapılıyor..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. ArgoCD'nin hazır olmasını bekle
echo "⏳ ArgoCD'nin hazır olması bekleniyor..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# 4. ArgoCD admin şifresini al
echo "🔑 ArgoCD admin şifresi alınıyor..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# 5. ArgoCD Service'ini LoadBalancer olarak expose et (isteğe bağlı)
echo "🌐 ArgoCD Service'i yapılandırılıyor..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 6. RBAC yapılandırmasını uygula
echo "🔐 RBAC yapılandırması uygulanıyor..."
kubectl apply -f ../argocd/rbac.yaml

# 7. ArgoCD Application'ı oluştur
echo "📱 ArgoCD Application oluşturuluyor..."
kubectl apply -f ../argocd/application.yaml

echo ""
echo "✅ ArgoCD kurulumu tamamlandı!"
echo ""
echo "🎯 ArgoCD Bilgileri:"
echo "==================="
echo "Namespace: argocd"
echo "Admin Username: admin"
echo "Admin Password: $ARGOCD_PASSWORD"
echo ""
echo "🌐 ArgoCD'ye erişim yöntemleri:"
echo ""
echo "1. Port Forward (Yerel erişim):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Ardından https://localhost:8080 adresine gidin"
echo ""
echo "2. LoadBalancer IP (Harici erişim):"
echo "   kubectl get svc argocd-server -n argocd"
echo "   External IP'yi bekleyin ve o IP'ye erişin"
echo ""
echo "📋 ArgoCD CLI ile bağlantı:"
echo "argocd login <ARGOCD_SERVER_IP>"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "🔄 Application sync'i:"
echo "argocd app sync flask-app"
echo ""
echo "📱 Application durumunu kontrol et:"
echo "argocd app get flask-app"
echo ""
echo "🎉 ArgoCD başarıyla kuruldu ve yapılandırıldı!"
