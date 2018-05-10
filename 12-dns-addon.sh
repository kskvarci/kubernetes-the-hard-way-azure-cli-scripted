#!/bin/bash -ex

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Deploying the DNS Cluster Add-on
# ###########################################################

# The DNS Cluster Add-on
# -----------------------------------------------------------
echo "Deploy the DNS cluster Add On"
kubectl create -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
kubectl get pods -l k8s-app=kube-dns -n kube-system
echo "DONE!"