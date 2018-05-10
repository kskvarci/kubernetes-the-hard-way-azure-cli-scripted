#!/bin/bash -e

# Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Bootstrapping the etcd Cluster
# ###########################################################

# Bootstrapping an etcd Cluster Member
# -----------------------------------------------------------
echo "Bootstrapping etcd"
for instance in "$resourceRootName-controller-0" "$resourceRootName-controller-1" "$resourceRootName-controller-2"; do
PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" -n ${instance}-pip --query "ipAddress" -otsv)
echo "- Bootstrapping $instance"
ssh -T $adminUserName@${PUBLIC_IP_ADDRESS} <<EOF
wget -q --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.3.2/etcd-v3.3.2-linux-amd64.tar.gz"
tar -xvf etcd-v3.3.2-linux-amd64.tar.gz
sudo mv etcd-v3.3.2-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
INTERNAL_IP=\$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
ETCD_NAME=\$(hostname -s)
# Create etcd service unit file
echo "[Unit]" > etcd.service
echo "Description=etcd" >> etcd.service
echo "Documentation=https://github.com/coreos" >> etcd.service
echo "" >> etcd.service
echo "[Service]" >> etcd.service
echo "ExecStart=/usr/local/bin/etcd \\\" >> etcd.service
echo "  --name \${ETCD_NAME} \\\" >> etcd.service
echo "  --cert-file=/etc/etcd/kubernetes.pem \\\" >> etcd.service
echo "  --key-file=/etc/etcd/kubernetes-key.pem \\\" >> etcd.service
echo "  --peer-cert-file=/etc/etcd/kubernetes.pem \\\" >> etcd.service
echo "  --peer-key-file=/etc/etcd/kubernetes-key.pem \\\" >> etcd.service
echo "  --trusted-ca-file=/etc/etcd/ca.pem \\\" >> etcd.service
echo "  --peer-trusted-ca-file=/etc/etcd/ca.pem \\\" >> etcd.service
echo "  --peer-client-cert-auth \\\" >> etcd.service
echo "  --client-cert-auth \\\" >> etcd.service
echo "  --initial-advertise-peer-urls https://\${INTERNAL_IP}:2380 \\\" >> etcd.service
echo "  --listen-peer-urls https://\${INTERNAL_IP}:2380" \\\>> etcd.service
echo "  --listen-client-urls https://\${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\\" >> etcd.service
echo "  --advertise-client-urls https://\${INTERNAL_IP}:2379 \\\" >> etcd.service
echo "  --initial-cluster-token etcd-cluster-0 \\\" >> etcd.service
echo "  --initial-cluster $resourceRootName-controller-0=https://10.240.0.10:2380,$resourceRootName-controller-1=https://10.240.0.11:2380,$resourceRootName-controller-2=https://10.240.0.12:2380 \\\" >> etcd.service
echo "  --initial-cluster-state new \\\" >> etcd.service
echo "  --data-dir=/var/lib/etcd" >> etcd.service
echo "Restart=on-failure" >> etcd.service
echo "RestartSec=5" >> etcd.service
echo "" >> etcd.service
echo "[Install]" >> etcd.service
echo "WantedBy=multi-user.target" >> etcd.service
sudo mv etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
#ETCDCTL_API=3 etcdctl member list
exit
EOF
done
echo "DONE!"