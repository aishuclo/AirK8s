#!/bin/bash
# Copyright (c) 2026 [aishu](艾叔 aishuc@126.com)
# SPDX-License-Identifier: GPL-3.0-only

echo "air-k8s-server" > /etc/hostname
hostname air-k8s-server

mount /dev/sr0 /media/

cat > /etc/yum.repos.d/openEuler-dvd.repo <<EOF
[DVD]
name=DVD
baseurl=file:///media/
enabled=1
gpgcheck=1
gpgkey=file:///media/RPM-GPG-KEY-openEuler
EOF

yum list 2>/dev/null | grep "DVD" > /dev/null
if [ $? -ne 0 ]; then
	echo "DVD本地源配置失败。"
	exit
fi

yum -y install httpd
systemctl enable httpd
systemctl start httpd

mkdir -p /var/www/html/dvd
grep -q "^/dev/sr0.*/var/www/html/dvd" /etc/fstab || echo "/dev/sr0 /var/www/html/dvd iso9660 defaults,nofail 0 0" | tee -a /etc/fstab


systemctl stop firewalld
systemctl disable firewalld

yum -y install wget 
WWW_DIR="/var/www/html/"
mkdir -p $WWW_DIR/k8s
cd $WWW_DIR/k8s
NERDCTL_VERSION=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
wget -nc --tries=3 --timeout=30 https://github.com/containerd/nerdctl/releases/download/${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION#v}-linux-amd64.tar.gz  -O nerdctl-linux-amd64.tar.gz
if [ ! -s nerdctl-linux-amd64.tar.gz ]; then
    echo "Error: Downloaded nerdctl-linux-amd64.tar.gz is empty or download failed."
    rm -f nerdctl-linux-amd64.tar.gz
    exit 1
fi


CNI_VERSION="v1.3.0"  # 替换为最新版本
# 动态生成架构和文件名
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
FILE="cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz"
# 如果文件不存在，则下载
if [ ! -f "$FILE" ]; then
    curl -L -o "$FILE" "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/${FILE}"
else
    echo "文件 $FILE 已存在，跳过下载。"
fi

cd -

yum -y install python3-devel python3 gcc
yum -y install python3-createrepo_c
yum -y install python3-libdnf
yum -y install python3-libmodulemd
yum -y install git

if [ ! -d modulemd-tools ]; then
    git clone https://github.com/rpm-software-management/modulemd-tools.git
fi

cd modulemd-tools/
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple Cython
yum -y install krb5*
python3 setup.py install --user
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pyyaml
cd -
if [[ ":$PATH:" != *":/root/.local/bin:"* ]]; then
    export PATH="$PATH:/root/.local/bin"
fi


DOWNLOAD_DIR="$WWW_DIR/mysoft"
mkdir -p "$DOWNLOAD_DIR"

yumdownloader --resolve --destdir=$DOWNLOAD_DIR systemd-pam
#yumdownloader --resolve --destdir=$DOWNLOAD_DIR containerd.io.x86_64 

wget -nc --tries=3 --timeout=30 https://download.docker.com/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
if [ ! -s /etc/yum.repos.d/docker-ce.repo ]; then
    echo "Error: Downloaded docker-ce.repo is empty or download failed."
    rm -f /etc/yum.repos.d/docker-ce.repo 
    exit 1
fi

sed -i 's+$releasever+8+'  /etc/yum.repos.d/docker-ce.repo
yumdownloader --resolve --destdir=$DOWNLOAD_DIR docker-ce-3:26.1.3-1.el8 

cat > /etc/yum.repos.d/k8s.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/rpm/repodata/repomd.xml.key
EOF
yumdownloader --resolve --destdir=$DOWNLOAD_DIR --archlist=x86_64 kubelet-1.32.0-150500.1.1 kubeadm-1.32.0-150500.1.1 kubectl-1.32.0-150500.1.1 

cd $DOWNLOAD_DIR
echo "create repo"
createrepo_c .
echo "create modules.yaml"
repo2module -s stable . modules.yaml
echo "modify repo"
modifyrepo_c --mdtype=modules modules.yaml repodata/

cd -

yum -y install docker-ce-3:26.1.3-1.el8

cat > /etc/docker/daemon.json <<EOF
{
  "insecure-registries":["127.0.0.1:5000"]
}
EOF

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

systemctl enable docker
systemctl restart docker
useradd -m user
passwd user
usermod -a -G docker user

sudo -u user -i /bin/bash -c "docker pull docker.m.daocloud.io/registry"


sudo -u user -i /bin/bash -c "mkdir -p ~/data"
sudo -u user -i /bin/bash -c "docker stop $(docker ps -a -q)"
sudo -u user -i /bin/bash -c "docker rm $(docker ps -a -q)"

sudo -u user -i /bin/bash -c "docker run -d -p 5000:5000 -v /home/user/data/:/var/lib/registry -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 docker.m.daocloud.io/registry"

function push_to_registry() {
    local IMAGE=$1
    local REPLACE_ADDR=${2:-"m.daocloud.io"}  # 默认镜像替换地址
    local IP=${3:-"127.0.0.1:5000"}          # 默认私有仓库地址

    local source_image="$REPLACE_ADDR/$IMAGE"
    local target_image="$IP/$IMAGE"

    # 解析镜像标签（tag），若未指定则默认为 latest
    local tag="latest"
    local repo_name="$IMAGE"
    if [[ "$IMAGE" == *:* ]]; then
        tag="${IMAGE##*:}"
        repo_name="${IMAGE%:*}"
    fi

    # 构建私有仓库 API URL（用于检查镜像是否存在）
    local registry_url="http://$IP/v2/$repo_name/manifests/$tag"

    # 1. 检查私有仓库是否已存在目标镜像
    echo "Checking if target image $target_image already exists in private registry..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        --head "$registry_url" 2>/dev/null)

    if [[ "$http_code" == "200" ]]; then
        echo "Target image $target_image already exists in private registry. Skipping push."
        return 0
    fi

    # 2. 检查本地是否已存在源镜像
    if docker image inspect "$source_image" &>/dev/null; then
        echo "Source image $source_image already exists locally. Skipping pull."
    else
        echo "Pulling image: $source_image"
        docker pull "$source_image" || {
            echo "Error: Failed to pull $source_image"
            return 1
        }
    fi

    # 3. 打标签
    echo "Tagging image: $source_image → $target_image"
    docker tag "$source_image" "$target_image" || {
        echo "Error: Failed to tag $source_image → $target_image"
        return 1
    }

    # 4. 推送到私有仓库
    echo "Pushing image: $target_image"
    docker push "$target_image" || {
        echo "Error: Failed to push $target_image"
        return 1
    }

    echo "Successfully mirrored $IMAGE to $IP"
    return 0
}

push_to_registry "registry.k8s.io/coredns/coredns:v1.11.3"
push_to_registry "docker.io/calico/apiserver:v3.28.2"
push_to_registry "docker.io/calico/node:v3.28.2"
push_to_registry "docker.io/calico/cni:v3.28.2"
push_to_registry "docker.io/calico/pod2daemon-flexvol:v3.28.2"

push_to_registry "docker.io/calico/kube-controllers:v3.28.2"
push_to_registry "docker.io/calico/csi:v3.28.2"
push_to_registry "docker.io/calico/node-driver-registrar:v3.28.2"
push_to_registry "docker.io/calico/typha:v3.28.2"
push_to_registry "docker.io/calico/csi:v3.28.2"
push_to_registry "docker.io/calico/node-driver-registrar:v3.28.2"

push_to_registry "registry.k8s.io/pause:3.6"

push_to_registry "registry.k8s.io/kube-controller-manager:v1.32.0"
push_to_registry "registry.k8s.io/kube-scheduler:v1.32.0"
push_to_registry "registry.k8s.io/kube-proxy:v1.32.0"
push_to_registry "registry.k8s.io/kube-apiserver:v1.32.0"
push_to_registry "registry.k8s.io/coredns/coredns:v1.11.3"
push_to_registry "registry.k8s.io/pause:3.10"
push_to_registry "registry.k8s.io/etcd:3.5.16-0"

push_to_registry "quay.io/tigera/operator:v1.34.5"

wget -nc --tries=3 --timeout=30 https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml -O /home/user/custom-resources.yaml
if [ ! -s /home/user/custom-resources.yaml ]; then
    echo "Error: Downloaded custom-resources.yaml is empty or download failed."
    rm -f /home/user/custom-resources.yaml
    exit 1
fi

wget -nc --tries=3 --timeout=30 https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml -O /home/user/tigera-operator.yaml
if [ ! -s /home/user/tigera-operator.yaml ]; then
    echo "Error: Downloaded tigera-operator.yaml is empty or download failed."
    rm -f /home/user/tigera-operator.yaml
    exit 1
fi

chown user:user /home/user/*.yaml
