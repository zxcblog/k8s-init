#!/bin/bash

root_dir=$(pwd)
source ${root_dir}/system/core.sh

# 检查操作脚本用户是否为root用户
if [ $(whoami) != "root" ]; then

  echo ""
  echo -e " \033[31m 此脚本需要以root权限运行，以便能够执行所有必要的操作。请在root用户下执行 \033[0m"
  exit
fi

# 检查服务器版本
os_version=""
if [ -f "/etc/issue" ]; then

  os_version=$(cat /etc/issue | cut -d " " -f 1,2)
fi

if [ "$os_version" != "Ubuntu 24.04.1" ]; then

  echo "当前脚本只在 Ubuntu 24.04.1 最小安装服务器上进行过尝试，当前服务器信息与脚本所安装服务不同"
  read -p "继续安装请按y键进行确认，其他键退出安装: " input
  if [ "$(echo $input | tr 'A-Z' 'a-z')" != "y" ]; then
    exit 1
  fi
fi

# 安装k8s containerd docker
bash ${root_dir}/system/install_k8s.sh ${root_dir}


read -p "是否使用kubeadm启动master节点: y/n, 默认不启动" input
if [ "$(echo $input | tr 'A-Z' 'a-z')" != "y" ]; then
  exit 1
fi

# master节点使用kubeadm创建集群
echo "初始化k8s主节点"
kubeadm init --config ${root_dir}/system/kubeadm-init.yaml | tee init.log

# 获取到kubeadm join命令
kubeadm_join=$(cat init.log | grep "kubeadm join" -A1)
if [ -z $kubeadm_join ]; then
  echo -e " \033[31m 初始化操作失败 \033[0m"
  exit
fi

# kubectl 是使用 ~/.kube/config 来确定如何连接集群的，
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf
print_blank

# 安装网络插件
echo "安装网络插件 flannel"
kubectl apply -f ${root_dir}/system/kube-flannel.yaml


echo " "
echo "===================== K8S 安装程序 v1.0 测试版====================="
echo " "
echo " "
echo "k8s相关程序已安装完毕, 从节点加入集群请进行已下操作："
echo " "
echo "从节点上执行下方命令"
echo "$kubeadm_join"
echo ""
echo ""
echo "将 $HOME/.kube/config 文件复制到从节点相同的路径中"
echo "执行: chown $(id -u):$(id -g) $HOME/.kube/config"
echo ""
echo "在从节点执行 kubectl get nodes 能查到对应的结果说明执行成功"
