#!/bin/bash

# 当前文件为安装k8s相关的操作，使用时需要将文件路径当作参数进行传递
root_dir=$1
source ${root_dir}/system/core.sh

# 进行初始化安装操作
print_title "关闭swap(交换)"
swapoff -a
# 检查是否存在已注释的swap条目
# -i.bak.$(date +%s) 直接编辑文件并在操作前基于当前时间戳(秒数)创建一个备份
# /swap/s/^/#/ 查找到所有包含swap的行，并在开头添加 #
grep '^#.*swap' /etc/fstab > /dev/null || sed -i.bak.$(date +%s) '/swap/s/^/#/' /etc/fstab
print_blank

if which ufw > /dev/null 2>&1; then
  print_title "关闭防火墙"
  systemctl stop ufw && systemctl disable ufw
  print_blank
fi

# 使用iptables检查交换流量
print_title "配置iptables"
# 显示加载 br_netfilter
modprobe br_netfilter
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

# 启动ipv6
# net.ipv4.ip_forward ipv4数据包转发
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
print_blank

# 设置时区为上海并同步时区，因为虚拟机快照还原时时间和现在时间不同步
# 使用apt update 时会有docker安装包查询失败
timedatectl set-timezone Asia/Shanghai
systemctl restart systemd-timedated
systemctl restart systemd-timesyncd
echo "正在同步时间，请稍等"
sleep 3
date

print_title "docker 和 k8s 软件安装"
apt update
apt install -y apt-transport-https ca-certificates curl gpg gnupg

# 公钥存放路径
if [ ! -d /etc/apt/keyrings ]; then
  mkdir -p -m 755 /etc/apt/keyrings
fi

if which docker > /dev/null 2>&1; then
   echo "卸载docker"
   apt remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
   # 卸载Docker Engine、CLI、containerd 和 Docker Compose
   apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
   # 删除所有镜像、容器和卷
   rm -rf /var/lib/docker
   rm -rf /var/lib/containerd
   # 删除源列表和密钥环
   rm /etc/apt/sources.list.d/docker.list
   rm /etc/apt/keyrings/docker.asc
   # 删除docker服务
   rm -rf /etc/systemd/system/docker.service
   rm -rf /etc/systemd/system/docker.service.d
fi

echo "配置docker阿里云镜像源信息"
docker_version="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
curl -fsSL ${docker_version}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${docker_version} \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "配置k8s阿里云镜像源信息"
# 添加阿里云源 请查看 https://developer.aliyun.com/mirror/kubernetes/?spm=a2c6h.25603864.0.0.71132529Js0emC 新版配置方法
k8s_version="https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/deb"
curl -fsSL ${k8s_version}/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${k8s_version}/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt update
echo "安装docker"
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 使用当前文件中修改好的配置文件覆盖默认文件, 并配置镜像加速
cp ${root_dir}/system/containerd_config.tomi /etc/containerd/config.toml
cp -r ${root_dir}/system/certs.d /etc/containerd
systemctl enable containerd && systemctl restart containerd

# 添加 crictl 配置文件
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF


echo "安装k8s，锁定版本并启动kubelet服务"
apt install -y kubectl kubeadm kubelet
# 锁定版本，避免意外升级
apt-mark hold kubelet kubeadm kubectl
print_end


# 因为flannel网络插件镜像下载缓慢，所以使用镜像导入加快速度
# 导入时需要指定命名空间， 默认空间为default， 与crictl使用不同
echo "导入k8s镜像"
ctr -n=k8s.io i import ${root_dir}/images/coredns_v1.11.3.tar
ctr -n=k8s.io i import ${root_dir}/images/etcd_3.5.16-0.tar
ctr -n=k8s.io i import ${root_dir}/images/kube-apiserver_v1.32.0.tar
ctr -n=k8s.io i import ${root_dir}/images/kube-controller-manager_v1.32.0.tar
ctr -n=k8s.io i import ${root_dir}/images/kube-proxy_v1.32.0.tar
ctr -n=k8s.io i import ${root_dir}/images/kube-scheduler_v1.32.0.tar
ctr -n=k8s.io i import ${root_dir}/images/pause_3.10.tar
ctr -n=k8s.io i import ${root_dir}/images/flannel-cni-plugin_v1.6.2-flannel1.tar
ctr -n=k8s.io i import ${root_dir}/images/flannel_v0.26.4.tar
