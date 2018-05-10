#!/bin/bash -ex

#Run this from a new directory called TLS

#include parameters file
source ../params.sh

# Bootstrapping the Kubernetes Worker Nodes
# ###########################################################

# Provisioning a Kubernetes Worker Node
# -----------------------------------------------------------
echo "Bootstrapping the Kubernetes Worker Nodes"
for instance in "$resourceRootName-worker-0" "$resourceRootName-worker-1" "$resourceRootName-worker-2"; do
PodCIDR=$(az vm show -g "$resourceRootName-Rg" --name $instance --query "tags" -o tsv)
echo "Pid CICR for $instance : $PodCIDR"
PUBLIC_IP_ADDRESS=$(az network public-ip show -g "$resourceRootName-Rg" -n ${instance}-pip --query "ipAddress" -otsv)
echo "- Boostrapping $instance"
ssh -T $adminUserName@${PUBLIC_IP_ADDRESS} << "EOF"
sudo apt-get -y install socat
wget -q --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.7.0/cni-plugins-amd64-v0.7.0.tgz \
  https://github.com/containerd/cri/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kubelet
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
sudo tar -xvf cni-plugins-amd64-v0.7.0.tgz -C /opt/cni/bin/
sudo tar -xvf cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -C /
chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/local/bin/
POD_CIDR="$(echo $(curl --silent -H Metadata:true "http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text") | cut -d : -f2)"
# Configure CNI Networking
echo "{" > 10-bridge.conf
echo "    \"cniVersion\": \"0.3.1\"," >> 10-bridge.conf
echo "    \"name\": \"bridge\"," >> 10-bridge.conf
echo "    \"type\": \"bridge\"," >> 10-bridge.conf
echo "    \"bridge\": \"cnio0\"," >> 10-bridge.conf
echo "    \"isGateway\": true," >> 10-bridge.conf
echo "    \"ipMasq\": true," >> 10-bridge.conf
echo "    \"ipam\": {" >> 10-bridge.conf
echo "        \"type\": \"host-local\"," >> 10-bridge.conf
echo "        \"ranges\": [" >> 10-bridge.conf
echo "          [{\"subnet\": \"${POD_CIDR}\"}]" >> 10-bridge.conf
echo "        ]," >> 10-bridge.conf
echo "        \"routes\": [{\"dst\": \"0.0.0.0/0\"}]" >> 10-bridge.conf
echo "    }" >> 10-bridge.conf
echo "}" >> 10-bridge.conf
# Create a loopback config file
echo "{" > 99-loopback.conf
echo "    \"cniVersion\": \"0.3.1\"," >> 99-loopback.conf
echo "    \"type\": \"loopback\"" >> 99-loopback.conf
echo "}" >> 99-loopback.conf
# Move network config files to the CNI config directory
sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
# Configure the Kubelet
sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
# Create the Kubelet systemd file
echo "[Unit]" > kubelet.service
echo "Description=Kubernetes Kubelet" >> kubelet.service
echo "Documentation=https://github.com/GoogleCloudPlatform/kubernetes" >> kubelet.service
echo "After=cri-containerd.service" >> kubelet.service
echo "Requires=cri-containerd.service" >> kubelet.service
echo "" >> kubelet.service
echo "[Service]" >> kubelet.service
echo "ExecStart=/usr/local/bin/kubelet \\" >> kubelet.service
echo "  --allow-privileged=true \\" >> kubelet.service
echo "  --anonymous-auth=false \\" >> kubelet.service
echo "  --authorization-mode=Webhook \\" >> kubelet.service
echo "  --client-ca-file=/var/lib/kubernetes/ca.pem \\" >> kubelet.service
echo "  --cluster-dns=10.32.0.10 \\" >> kubelet.service
echo "  --cluster-domain=cluster.local \\" >> kubelet.service
echo "  --container-runtime=remote \\" >> kubelet.service
echo "  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\" >> kubelet.service
echo "  --image-pull-progress-deadline=2m \\" >> kubelet.service
echo "  --kubeconfig=/var/lib/kubelet/kubeconfig \\" >> kubelet.service
echo "  --network-plugin=cni \\" >> kubelet.service
echo "  --pod-cidr=${POD_CIDR} \\" >> kubelet.service
echo "  --register-node=true \\" >> kubelet.service
echo "  --require-kubeconfig \\" >> kubelet.service
echo "  --runtime-request-timeout=15m \\" >> kubelet.service
echo "  --tls-cert-file=/var/lib/kubelet/${HOSTNAME}.pem \\" >> kubelet.service
echo "  --tls-private-key-file=/var/lib/kubelet/${HOSTNAME}-key.pem \\" >> kubelet.service
echo "  --v=2" >> kubelet.service
echo "Restart=on-failure" >> kubelet.service
echo "RestartSec=5" >> kubelet.service
echo "" >> kubelet.service
echo "[Install]" >> kubelet.service
echo "WantedBy=multi-user.target" >> kubelet.service
# Configure the Kubernetes Proxy
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
# Create the systemd unit file
echo "[Unit]" > kube-proxy.service
echo "Description=Kubernetes Kube Proxy" >> kube-proxy.service
echo "Documentation=https://github.com/GoogleCloudPlatform/kubernetes" >> kube-proxy.service
echo "" >> kube-proxy.service
echo "[Service]" >> kube-proxy.service
echo "ExecStart=/usr/local/bin/kube-proxy \\" >> kube-proxy.service
echo "  --cluster-cidr=10.200.0.0/16 \\" >> kube-proxy.service
echo "  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\" >> kube-proxy.service
echo "  --proxy-mode=iptables \\" >> kube-proxy.service
echo "  --v=2" >> kube-proxy.service
echo "Restart=on-failure" >> kube-proxy.service
echo "RestartSec=5" >> kube-proxy.service
echo "" >> kube-proxy.service
echo "[Install]" >> kube-proxy.service
echo "WantedBy=multi-user.target" >> kube-proxy.service
sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable containerd cri-containerd kubelet kube-proxy
sudo systemctl start containerd cri-containerd kubelet kube-proxy
# Disconnect from SSH session
exit
EOF
done
echo "DONE!"