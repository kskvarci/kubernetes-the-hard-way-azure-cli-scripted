#!/bin/bash -e

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Configuring kubectl for Remote Access
# ###########################################################

# The Admin Kubernetes Configuration File
# -----------------------------------------------------------
echo "Configuring kubectl for remote access"
KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
  -n "$resourceRootName-pip" --query ipAddress -otsv)
echo $KUBERNETES_PUBLIC_ADDRESS

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem
kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin
kubectl config use-context kubernetes-the-hard-way
echo "DONE!"