#!/bin/bash
# Copyright (c) 2026 [aishu](艾叔 aishuc@126.com)
# SPDX-License-Identifier: GPL-3.0-only

NODE_NAME=node01
NODE_IP=192.168.229.132
NODE_IP_MASK=24
GATE_WAY=192.168.229.1
DNS=192.168.229.1
DOCKER_REGISTRY=192.168.229.128
YUM_SERVER=192.168.229.129
SOFT_SERVER=$YUM_SERVER
MASTER_IP=192.168.229.130

# 1. 设置主机名
hostnamectl set-hostname $NODE_NAME 
sed -i '/^127.0.1.1/d' /etc/hosts 
echo "127.0.1.1 $NODE_NAME" >> /etc/hosts


# 2. 设置静态网络（重启不会改变IP）
nmcli connection modify ens33 ipv4.method manual ipv4.address $NODE_IP/$NODE_IP_MASK  ipv4.gateway $GATE_WAY ipv4.dns $DNS 
nmcli connection up ens33

# 3. 增加yum-server和docker-registry的映射
sed -i '/yum-server\|docker-registry/d' /etc/hosts
echo "$YUM_SERVER yum-server" >> /etc/hosts
echo "$DOCKER_REGISTRY docker-registry" >> /etc/hosts
echo "$MASTER_IP master" >> /etc/hosts

# 4. 配置离线yum仓库
rm -rf /etc/yum.repos.d/openEuler.repo
rm -rf /etc/yum.repos.d/openEuler-dvd.repo
cat >> /etc/yum.repos.d/openEuler-dvd.repo <<EOF
[DVD]
name=DVD
baseurl=http://yum-server/dvd/
gpgcheck=1
enabled=1
gpgkey=http://yum-server/dvd/RPM-GPG-KEY-openEuler
EOF

rm -rf /etc/yum.repos.d/openEuler-mysoft.repo
touch /etc/yum.repos.d/openEuler-mysoft.repo
cat >> /etc/yum.repos.d/openEuler-mysoft.repo <<EOF
[MySoft]
name=MySoft
baseurl=http://${YUM_SERVER}/mysoft/
gpgcheck=0
enabled=1
EOF

yum clean all
yum makecache
yum repolist

# 5. 创建普通用户，并使得普通用户可以执行su
id -u user &>/dev/null || useradd -m user && passwd user
usermod -G wheel user
passwd user


# 6. 安装containerd
yum -y install containerd
systemctl enable containerd
systemctl start containerd
usermod -aG root user

# 7. 安装nerdctl
mkdir -p ~/nerdctl
wget http://${SOFT_SERVER}/k8s/nerdctl-2.1.3-linux-amd64.tar.gz -O ~/nerdctl/nerdctl-2.1.3-linux-amd64.tar.gz
tar -xzf ~/nerdctl/nerdctl-2.1.3-linux-amd64.tar.gz -C ~/nerdctl/ && chmod +x ~/nerdctl/nerdctl
echo 'export PATH=$PATH:~/nerdctl' >> /etc/profile 
source /etc/profile
#nerdctl --help

# 9. 禁用防火墙
systemctl stop firewalld
systemctl disable firewalld

# 10. 设置iptables
cat >> /etc/rc.d/rc.local <<EOF
iptables -P FORWARD ACCEPT
echo "1" > /proc/sys/net/ipv4/ip_forward
EOF
iptables -P FORWARD ACCEPT
echo "1" > /proc/sys/net/ipv4/ip_forward


# 11. 安装kubeadm
yum install -y kubelet-1.32.0-150500.1.1 kubeadm-1.32.0-150500.1.1 kubectl-1.32.0-150500.1.1
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' | sudo tee /etc/default/kubelet
systemctl enable kubelet

# 12. 禁用swap
cp /etc/fstab /etc/fstab.bak 
#/^UUID=.*[[:space:]]swap[[:space:]] - 匹配：以 UUID= 开头的行,包含 swap 字段（前后有空白字符）
#.*defaults[[:space:]]/ - 继续匹配包含 defaults 的行
#s/defaults/defaults,noauto/ - 将 defaults 替换为 defaults,noauto
sed -i '/^UUID=.*[[:space:]]swap[[:space:]].*defaults[[:space:]]/s/defaults/defaults,noauto/' /etc/fstab
swapoff -a

# 13. 下载k8s集群所需要的镜像
IMG_STR=$DOCKER_REGISTRY:5000
function pull_and_retag_image() {
    local IMAGE=$1

    # 从指定镜像仓库拉取镜像
    nerdctl -n=k8s.io --insecure-registry pull $IMG_STR/$IMAGE

    # 重新打标签为原始镜像名称
    nerdctl -n=k8s.io tag $IMG_STR/$IMAGE $IMAGE

    # 删除旧的镜像引用
    nerdctl -n=k8s.io rmi $IMG_STR/$IMAGE
}

pull_and_retag_image "registry.k8s.io/kube-apiserver:v1.32.0"
pull_and_retag_image "registry.k8s.io/kube-controller-manager:v1.32.0"
pull_and_retag_image "registry.k8s.io/kube-scheduler:v1.32.0"
pull_and_retag_image "registry.k8s.io/kube-proxy:v1.32.0"
pull_and_retag_image "registry.k8s.io/coredns/coredns:v1.11.3"
pull_and_retag_image "registry.k8s.io/pause:3.10"
pull_and_retag_image "registry.k8s.io/etcd:3.5.16-0"

pull_and_retag_image "registry.k8s.io/pause:3.6"
nerdctl -n=k8s.io image prune

# 14. 修改containerd配置 
# 去掉cni，设置SystemdCgroup = true
containerd config default > /etc/containerd/config.toml.bk
containerd config default > /etc/containerd/config.toml
sed -i -e 's/disabled_plugins = \["cri"\]/disabled_plugins = \[""\]/' \
	-e '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/,/^\[.*\]/ s/SystemdCgroup = false/SystemdCgroup = true/' \
            /etc/containerd/config.toml

systemctl restart containerd


# 15. 初始化k8s集群
kubeadm reset
rm -rf /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/manifests/etcd.yaml
systemctl stop kubelet
kubeadm reset
JOIN_CMD=$(ssh $MASTER_IP "kubeadm token create --print-join-command")
echo $JOIN_CMD
$JOIN_CMD

# 16. 设置普通用户使用k8s
mkdir -p /home/user/.kube
chown -R user:user /home/user/.kube/
scp $MASTER_IP:/etc/kubernetes/admin.conf /home/user/.kube/config
chown user:user /home/user/.kube/config

# 17. 创建calico网络
pull_and_retag_image "registry.k8s.io/coredns/coredns:v1.11.3"
pull_and_retag_image "docker.io/calico/apiserver:v3.28.2"
pull_and_retag_image "docker.io/calico/node:v3.28.2"
pull_and_retag_image "docker.io/calico/cni:v3.28.2"
pull_and_retag_image "docker.io/calico/pod2daemon-flexvol:v3.28.2"
pull_and_retag_image "docker.io/calico/kube-controllers:v3.28.2"
pull_and_retag_image "docker.io/calico/csi:v3.28.2"
pull_and_retag_image "docker.io/calico/node-driver-registrar:v3.28.2"
pull_and_retag_image "docker.io/calico/typha:v3.28.2"
pull_and_retag_image "docker.io/calico/csi:v3.28.2"
pull_and_retag_image "docker.io/calico/node-driver-registrar:v3.28.2"
pull_and_retag_image "quay.io/tigera/operator:v1.34.5"

nerdctl -n=k8s.io image prune
