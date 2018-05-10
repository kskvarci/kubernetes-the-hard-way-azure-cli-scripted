#!/bin/bash -e

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Bootstrapping the Kubernetes Control Plane
# ###########################################################

# Provision the Kubernetes Control Plane
# -----------------------------------------------------------
echo "Boostrapping the Kubernetes control plane"
for instance in "$resourceRootName-controller-0" "$resourceRootName-controller-1" "$resourceRootName-controller-2"; do
PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" -n ${instance}-pip --query "ipAddress" -otsv)
echo "- Bootstrapping $instance"
ssh -T $adminUserName@${PUBLIC_IP_ADDRESS} << "EOF"
# Download Kubernetes binaries
wget -q --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kubectl"
# Install the binaries
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
# Configure the API Server
sudo mkdir -p /var/lib/kubernetes/
sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem encryption-config.yaml /var/lib/kubernetes/
INTERNAL_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
# Create systemd init file
echo "[Unit]" > kube-apiserver.service
echo "Description=Kubernetes API Server" >> kube-apiserver.service
echo "Documentation=https://github.com/GoogleCloudPlatform/kubernetes" >> kube-apiserver.service
echo "" >> kube-apiserver.service
echo "[Service]" >> kube-apiserver.service
echo "ExecStart=/usr/local/bin/kube-apiserver \\" >> kube-apiserver.service
echo "  --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\" >> kube-apiserver.service
echo "  --advertise-address=${INTERNAL_IP} \\" >> kube-apiserver.service
echo "  --allow-privileged=true \\" >> kube-apiserver.service
echo "  --apiserver-count=3 \\" >> kube-apiserver.service
echo "  --audit-log-maxage=30 \\" >> kube-apiserver.service
echo "  --audit-log-maxbackup=3 \\" >> kube-apiserver.service
echo "  --audit-log-maxsize=100 \\" >> kube-apiserver.service
echo "  --audit-log-path=/var/log/audit.log \\" >> kube-apiserver.service
echo "  --authorization-mode=Node,RBAC \\" >> kube-apiserver.service
echo "  --bind-address=0.0.0.0 \\" >> kube-apiserver.service
echo "  --client-ca-file=/var/lib/kubernetes/ca.pem \\" >> kube-apiserver.service
echo "  --enable-swagger-ui=true \\" >> kube-apiserver.service
echo "  --etcd-cafile=/var/lib/kubernetes/ca.pem \\" >> kube-apiserver.service
echo "  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\" >> kube-apiserver.service
echo "  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\" >> kube-apiserver.service
echo "  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\" >> kube-apiserver.service
echo "  --event-ttl=1h \\" >> kube-apiserver.service
echo "  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\" >> kube-apiserver.service
echo "  --insecure-bind-address=127.0.0.1 \\" >> kube-apiserver.service
echo "  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\" >> kube-apiserver.service
echo "  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\" >> kube-apiserver.service
echo "  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\" >> kube-apiserver.service
echo "  --kubelet-https=true \\" >> kube-apiserver.service
echo "  --runtime-config=api/all \\" >> kube-apiserver.service
echo "  --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\" >> kube-apiserver.service
echo "  --service-cluster-ip-range=10.32.0.0/24 \\" >> kube-apiserver.service
echo "  --service-node-port-range=30000-32767 \\" >> kube-apiserver.service
echo "  --tls-ca-file=/var/lib/kubernetes/ca.pem \\" >> kube-apiserver.service
echo "  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\" >> kube-apiserver.service
echo "  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\" >> kube-apiserver.service
echo "  --v=2" >> kube-apiserver.service
echo "Restart=on-failure" >> kube-apiserver.service
echo "RestartSec=5" >> kube-apiserver.service
echo "" >> kube-apiserver.service
echo "[Install]" >> kube-apiserver.service
echo "WantedBy=multi-user.target" >> kube-apiserver.service
# Create systemd init file
echo "[Unit]" > kube-controller-manager.service
echo "Description=Kubernetes Controller Manager" >> kube-controller-manager.service
echo "Documentation=https://github.com/GoogleCloudPlatform/kubernetes" >> kube-controller-manager.service
echo "" >> kube-controller-manager.service
echo "[Service]" >> kube-controller-manager.service
echo "ExecStart=/usr/local/bin/kube-controller-manager \\" >> kube-controller-manager.service
echo "  --address=0.0.0.0 \\" >> kube-controller-manager.service
echo "  --cluster-cidr=10.200.0.0/16 \\" >> kube-controller-manager.service
echo "  --cluster-name=kubernetes \\" >> kube-controller-manager.service
echo "  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\" >> kube-controller-manager.service
echo "  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\" >> kube-controller-manager.service
echo "  --leader-elect=true \\" >> kube-controller-manager.service
echo "  --master=http://127.0.0.1:8080 \\" >> kube-controller-manager.service
echo "  --root-ca-file=/var/lib/kubernetes/ca.pem \\" >> kube-controller-manager.service
echo "  --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\" >> kube-controller-manager.service
echo "  --service-cluster-ip-range=10.32.0.0/24 \\" >> kube-controller-manager.service
echo "  --v=2" >> kube-controller-manager.service
echo "Restart=on-failure" >> kube-controller-manager.service
echo "RestartSec=5" >> kube-controller-manager.service
echo "" >> kube-controller-manager.service
echo "[Install]" >> kube-controller-manager.service
echo "WantedBy=multi-user.target" >> kube-controller-manager.service
# Create systemd init file
echo "[Unit]" > kube-scheduler.service
echo "Description=Kubernetes Scheduler" >> kube-scheduler.service
echo "Documentation=https://github.com/GoogleCloudPlatform/kubernetes" >> kube-scheduler.service
echo "" >> kube-scheduler.service
echo "[Service]" >> kube-scheduler.service
echo "ExecStart=/usr/local/bin/kube-scheduler \\" >> kube-scheduler.service
echo "  --leader-elect=true \\" >> kube-scheduler.service
echo "  --master=http://127.0.0.1:8080 \\" >> kube-scheduler.service
echo "  --v=2" >> kube-scheduler.service
echo "Restart=on-failure" >> kube-scheduler.service
echo "RestartSec=5" >> kube-scheduler.service
echo "" >> kube-scheduler.service
echo "[Install]" >> kube-scheduler.service
echo "WantedBy=multi-user.target" >> kube-scheduler.service
# Start the controller services
sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
# Disconnect from SSH session
exit
EOF
done

# RBAC for Kubelet Authorization
# -----------------------------------------------------------
for instance in "$resourceRootName-controller-0"; do
PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" -n ${instance}-pip --query "ipAddress" -otsv)
echo "Connecting to $instance to configure RBC for Kubelet Authorization"
ssh -T $adminUserName@${PUBLIC_IP_ADDRESS} << "RBAC"
echo "apiVersion: rbac.authorization.k8s.io/v1beta1" > rbac.conf
echo "kind: ClusterRole" >> rbac.conf
echo "metadata:" >> rbac.conf
echo "  annotations:" >> rbac.conf
echo '    rbac.authorization.kubernetes.io/autoupdate: "true"' >> rbac.conf
echo "  labels:" >> rbac.conf
echo "    kubernetes.io/bootstrapping: rbac-defaults" >> rbac.conf
echo "  name: system:kube-apiserver-to-kubelet" >> rbac.conf
echo "rules:" >> rbac.conf
echo "  - apiGroups:" >> rbac.conf
echo '      - ""' >> rbac.conf
echo "    resources:" >> rbac.conf
echo "      - nodes/proxy" >> rbac.conf
echo "      - nodes/stats" >> rbac.conf
echo "      - nodes/log" >> rbac.conf
echo "      - nodes/spec" >> rbac.conf
echo "      - nodes/metrics" >> rbac.conf
echo "    verbs:" >> rbac.conf
echo '      - "*"' >> rbac.conf
# Apply RBAC
kubectl apply -f ./rbac.conf
# New RBAC CONF
echo " apiVersion: rbac.authorization.k8s.io/v1beta1" > rbac2.conf
echo " kind: ClusterRoleBinding" >> rbac2.conf
echo " metadata:" >> rbac2.conf
echo "   name: system:kube-apiserver" >> rbac2.conf
echo "   namespace: """ >> rbac2.conf
echo " roleRef:" >> rbac2.conf
echo "   apiGroup: rbac.authorization.k8s.io" >> rbac2.conf
echo "   kind: ClusterRole" >> rbac2.conf
echo "   name: system:kube-apiserver-to-kubelet" >> rbac2.conf
echo " subjects:" >> rbac2.conf
echo "   - apiGroup: rbac.authorization.k8s.io" >> rbac2.conf
echo "     kind: User" >> rbac2.conf
echo "     name: kubernetes" >> rbac2.conf
# Apply RBAC
kubectl apply -f ./rbac2.conf
echo " Disconnect from SSH session"
exit
RBAC
done

# The Kubernetes Frontend Load Balancer
# -----------------------------------------------------------
echo "Creating a front end Azure Load Balancer"
# Frontent Load Balancer
az network lb rule create -g "$resourceRootName-Rg" \
   -n kubernetes-apiserver-rule \
   --protocol tcp \
   --lb-name "$resourceRootName-lb" \
   --frontend-ip-name LoadBalancerFrontEnd \
   --frontend-port 6443 \
   --backend-pool-name "$resourceRootName-lb-pool" \
   --backend-port 6443

# Check to see that the Frontend is available
KUBERNETES_PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" \
  -n "$resourceRootName-pip" --query ipAddress -otsv)
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_IP_ADDRESS}:6443/version
echo "DONE!"
