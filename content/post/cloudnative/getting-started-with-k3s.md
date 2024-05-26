---
title: "K3S入门"
date: 2024-05-26T08:02:29+08:00
tags: ["k3s","Kubernetes","K8s"]
categories: ["cloudnative"]
draft: true
---

![题图](https://voidint.github.io/cloudnative/how-it-works-k3s-revised.jpg)

## 什么是 K3s
`K3s`是轻量级的`Kubernetes`，且完全兼容 Kubernetes 发行版。K3s 易于安装，仅需要 Kubernetes 内存的一半，所有组件都在一个小于 100 MB 的二进制文件中。

适用场景：
- Edge
- IoT
- CI
- Development
- ARM
- 嵌入 K8S

K3s 设计目标是，希望能与 Kubernetes 在功能上保持一致的前提下，**内**存消耗仅一半**。Kubernetes 是一个10个字母的单词，简写为 K8s。Kubernetes 的一半就是一个5个字母的单词，因此简写为 K3s。K3s 没有全称，也没有官方的发音。


## 架构

- 单节点架构
在这种配置中，每个 agent 节点都注册到同一个 server 节点。K3s 用户可以通过调用 server 节点上的 K3s API 来操作 Kubernetes 资源。

    ![单节点架构图](https://voidint.github.io/cloudnative/k3s-architecture-single-server.jpg)

- 高可用架构
一个高可用 K3s 集群由以下几个部分组成：
  - K3s Server 节点：两个或更多的server节点将为 Kubernetes API 提供服务并运行其他 control-plane 服务
  - 外部数据库：与单节点 k3s 设置中使用的嵌入式 SQLite 数据存储相反，高可用 K3s 需要挂载一个external database外部数据库作为数据存储的媒介。
  
    ![高可用架构图](https://voidint.github.io/cloudnative/k3s-architecture-ha-embedded.jpg)


## 安装和卸载
K3s server 是运行k3s server命令的机器（裸机或虚拟机），而 K3s worker 节点是运行k3s agent命令的机器。

- 使用脚本快速安装 k3s server

    ```shell
    # kubeconfig文件写入 /etc/rancher/k3s/k3s.yaml
    $ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
    ```

- 使用脚本快速安装 K3s Agent

    ```shell
    # myserver 表示 master 节点的IP
    # mynodetoken 表示 master 节点的 /var/lib/rancher/k3s/server/node-token
    $ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn K3S_URL=https://myserver:6443 K3S_TOKEN=mynodetoken sh -
    ```

安装时可以通过命令行选项或者环境变量进行自定义配置，这部分内容不在此进行赘述，请读者自行阅读[相关文档](https://docs.rancher.cn/docs/k3s/installation/install-options/_index)。

- 卸载 K3s Server

    ```shell
    $ sh /usr/local/bin/k3s-uninstall.sh # agent 节点无此脚本
    ```

- 卸载 K3s Agent

    ```shell
    $ sh /usr/local/bin/k3s-agent-uninstall.sh # server 节点无此脚本
    ```

- 杀死 K3s 下所有容器

    ```shell
    $ sh /usr/local/bin/k3s-killall.sh
    ```

## 私有镜像仓库配置

启动时，K3s 会检查`/etc/rancher/k3s/registries.yaml`是否存在，并指示 containerd 使用文件中定义的镜像仓库。如果你想使用一个私有的镜像仓库，那么你需要在每个使用镜像仓库的节点上以 root 身份创建这个文件。

```shell
$ mkdir -p /etc/rancher/k3s && cat >> /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "registry.cn-hangzhou.aliyuncs.com":
    endpoint:
      - "https://registry.xxxx.yyyy.zzzz" # 请自行修改
  "docker.io":
    endpoint:
      - "https://registry-1.docker.io"
configs:
  "registry.xxxx.yyyy.zzzz":
    auth:
      username: 'hello' # this is the registry username
      password: 'world' # this is the registry password
  "docker.io":
    auth:
      username: '' # this is the registry username
      password: '' # this is the registry password
    tls:
      cert_file: '' # path to the cert file used in the registry
      key_file: '' # path to the key file used in the registry
      ca_file: '' # path to the ca file used in the registry
EOF

# 重启k3s server
$ systemctl restart k3s

# 或者重启k3s agent
$ systemctl restart k3s-agent
```

## K3s 网络端口

| 协议 | 端口 | 源 | 描述 |
| --- | --- | --- | --- |
| TCP | 6443 | K3s agent 节点 | Kubernetes API Server |
| UDP | 8472 | K3s server 和 agent 节点 | 仅对 Flannel VXLAN 需要 |
| UDP | 51820 | K3s server 和 agent 节点 | 只有 Flannel Wireguard 后端需要 |
| UDP | 51821 | K3s server 和 agent 节点	 | 只有使用 IPv6 的 Flannel Wireguard 后端才需要 |
| TCP | 10250 | K3s server 和 agent 节点	 | Kubelet metrics |
| TCP | 2379-2380 | K3s server 节点 | 只有嵌入式 etcd 高可用才需要 |



## 查看本地镜像
```shell
$ k3s crictl images
```

## 清理无用镜像
```shell
$ k3s crictl rmi --prune
```

## 查看 K3s 日志
- 当使用`openrc`运行时，日志将在`/var/log/k3s.log`中创建。
- 当使用`systemd`运行时，日志将在`/var/log/syslog`中创建，并使用`journalctl -u k3s`查看。
  


## 集群访问
```shell
# KUBECONFIG 环境变量指定集群配置文件
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml 
kubectl get pods --all-namespaces

# --kubeconfig 命令行选项指定集群配置文件
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get pods --all-namespaces
```

## 参考
- [K3s文档](https://docs.rancher.cn/docs/k3s/_index)
- [docs.k3s.io](https://docs.k3s.io/zh/)