# 安装要求
本脚本是在ubuntu 24.04.01中进行安装, 使用root用户执行 install.sh 脚本
部署的k8s版本为1.32.1

```shell
bash install.sh

# 将当前文件夹下所有内容上传到服务器
scp -r ./* master@192.168.83.101:/home/master/k8s-init

# 切换root用户
sudo su -

# 进入到对应的目录并执行
cd /home/master/k8s-init
bash install.sh

# 或者 
#chmod +x install.sh
#./install.sh
```

# 拉取服务器文件
scp master@192.168.83.101:/home/master/k8s-init/* ./images

# 打包并下载镜像
> 查看命名空间 ctr namespaces list

ctr -n=k8s.io image pull registry.aliyuncs.com/google_containers/coredns:v1.11.3 \
                        registry.aliyuncs.com/google_containers/etcd:3.5.16-0 \
                        registry.aliyuncs.com/google_containers/kube-apiserver:v1.32.0 \
                        registry.aliyuncs.com/google_containers/kube-controller-manager:v1.32.0 \
                        registry.aliyuncs.com/google_containers/kube-proxy:v1.32.0 \
                        registry.aliyuncs.com/google_containers/kube-scheduler:v1.32.0 \
                        registry.aliyuncs.com/google_containers/pause:3.10 \
                        ghcr.io/flannel-io/flannel-cni-plugin:v1.6.2-flannel1 \
                        ghcr.io/flannel-io/flannel:v0.26.4
ctr -n=k8s.io image export coredns_v1.11.3.tar registry.aliyuncs.com/google_containers/coredns:v1.11.3
ctr -n=k8s.io image export etcd_3.5.16-0.tar registry.aliyuncs.com/google_containers/etcd:3.5.16-0
ctr -n=k8s.io image export kube-apiserver_v1.32.0.tar registry.aliyuncs.com/google_containers/kube-apiserver:v1.32.0
ctr -n=k8s.io image export kube-controller-manager_v1.32.0.tar registry.aliyuncs.com/google_containers/kube-controller-manager:v1.32.0
ctr -n=k8s.io image export kube-proxy_v1.32.0.tar registry.aliyuncs.com/google_containers/kube-proxy:v1.32.0
ctr -n=k8s.io image export kube-scheduler_v1.32.0.tar registry.aliyuncs.com/google_containers/kube-scheduler:v1.32.0
ctr -n=k8s.io image export pause_3.10.tar registry.aliyuncs.com/google_containers/pause:3.10
ctr -n=k8s.io image export flannel-cni-plugin_v1.6.2-flannel1.tar ghcr.io/flannel-io/flannel-cni-plugin:v1.6.2-flannel1
ctr -n=k8s.io image export flannel_v0.26.4.tar ghcr.io/flannel-io/flannel:v0.26.4

镜像导入
ctr -n=k8s.io i import ./images/redis_7_4.tar

> 因为docker镜像源被关闭， 部署服务节点时无法正常部署， 需要使用docker将相关镜像拉取到本地，使用docker导出后上传导入
> 以redis:7.4为例
> docker pull docker.io/bitnami/redis:7.4
> docker save -o redis_7_4.tar bitnami/redis:7.4
> scp redis_7_4.tar master@192.168.83.101:/home/master/k8s-init/images
> ctr -n=k8s.io i import home/master/k8s-init/images/redis_7_4.tar
> crictl images