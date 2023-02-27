#!/bin/bash

set -euo pipefail

pushd $(dirname $(realpath "$0")) >/dev/null

PKI_DIR=../pki

# gold
STATUS='#f6c177'
# green
SUCCESS='#31748f'
# purple
INFO='#c4a7e7'

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
    --name kubernetes --query 'LoadBalancers[0].DNSName' --output text)

gum style --foreground $STATUS "Generating kubeconfigs for workers..."
for i in 0 1 2; do
  instance="worker-${i}"
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority="$PKI_DIR/ca.pem" \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate="$PKI_DIR/${instance}.pem" \
    --client-key="$PKI_DIR/${instance}-key.pem" \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
gum style --foreground $SUCCESS "✅ Generating workers kubeconfigs!"

gum style --foreground $STATUS "Generating 'kube-proxy' kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority="$PKI_DIR/ca.pem" \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate="$PKI_DIR/kube-proxy.pem" \
  --client-key="$PKI_DIR/kube-proxy-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
gum style --foreground $SUCCESS "✅ Generated 'kube-proxy' kubeconfig!"

gum style --foreground $STATUS "Generating 'kube-controller-manager' kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority="$PKI_DIR/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate="$PKI_DIR/kube-controller-manager.pem" \
  --client-key="$PKI_DIR/kube-controller-manager-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
gum style --foreground $SUCCESS "✅ Generated 'kube-controller-manager' kubeconfig!"

gum style --foreground $STATUS "Generating 'kube-scheduler' kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority="$PKI_DIR/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate="$PKI_DIR/kube-scheduler.pem" \
  --client-key="$PKI_DIR/kube-scheduler-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
gum style --foreground $SUCCESS "✅ Generated 'kube-scheduler' kubeconfig!"

gum style --foreground $STATUS "Generating kubeconfig for admin user..."
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority="$PKI_DIR/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate="$PKI_DIR/admin.pem" \
  --client-key="$PKI_DIR/admin-key.pem" \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig
gum style --foreground $SUCCESS "✅ Generated kubeconfig for admin user!"

popd >/dev/null