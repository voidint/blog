---
title: "goproxy.io内部私有化部署"
date: 2020-03-14 17:58:28
tags: [goproxy.io,golang]
categories: ["Golang"]
draft: true
---

![题图](https://voidint.github.io/golang/goproxyio.jpg)


最近在公司内部搭建了一个[goproxy.io](https://goproxy.io/zh/)的服务，总结并记录一下备忘。

goproxy.io本身已经比较成熟，对部署也非常友好，按照官方的文档一步一步搭建应该都会比较顺利。当然我也不是对官方文档的无意义复制粘贴，我将从以下三个方面进行阐述：

# goproxy.io服务的搭建
- 安装go环境(要求1.13及以上版本)

```shell
$ yum install golang -y
```

- 安装git
```shell
$ yum install git -y
```

- 安装goproxy
```shell
$ mkdir -p /opt/goproxy && cd /opt/goproxy
$ git clone https://github.com/goproxyio/goproxy.git
$ cd goproxy
$ make
$ mv ./bin/goproxy /usr/local/bin/goproxy
```

- 启动goproxy服务（监听8080端口）
```shell
$ mkdir -p /opt/goproxy/go_cache
$ goproxy -cacheDir /opt/goproxy/go_cache -exclude example.io -proxy https://goproxy.io -listen 0.0.0.0:8080
```

# 解决go get方式拉取私有库问题
明确下目标。所谓的go get方式拉取私有库，指的是能通过`go get -u -v -insecure example.io/xxx/yyy`方式拉取到内部私有仓库中的go代码。example.io指的是内部的私有域名。

假设已经按照以上步骤在10.0.1.2安装了goproxy.io服务。

安装govanityurls服务（监听80端口）
tonybai在其[博文](https://tonybai.com/2017/06/28/set-custom-go-get-import-path-for-go-package/)中说的很清楚了，我也就不重复了。贴一张他博文中的配图，一图胜千言。

将内部私有域名example.io解析到安装了以上服务的10.0.1.2。

# 开发人员本地环境配置
临时开启Go Module
```shell
$ export GO111MODULE=on
```

永久开启Go Module
```shell
$ go env -w GO111MODULE=on
```

设置go源代码库拉取的代理地址（http://10.0.1.2:8080）
```shell
$ go env -w GOPROXY="http://10.0.1.2:8080,https://goproxy.cn,direct"
```

可选：设置私有库（10.0.1.2上的goproxy服务本身也会将私有库重定向至gitlab.example.com）
```shell
$ go env -w GOPRIVATE="example.io" 
```

追加~/.gitconfig配置（修改为通过git下载源代码）
```shell
$ git config --global url."ssh://git@gitlab.example.com".insteadOf "http://gitlab.example.com"
```

测试拉取外网的公开库
```shell
$ go get -u -v github.com/go-xorm/xorm 
```

测试拉取内网的私有库（默认拉取master分支的最近一次提交）
```shell
$ go get -u -v -insecure example.io/voidint/tsdump
```

测试拉取内网的私有库的指定版本（强烈建议为每个版本打上tag）
```shell
$ go get -u -v -insecure example.io/voidint/tsdump@v1.0.0
```

# 参考
- [部署公司内部自己的 goproxy.io 服务](https://goproxy.io/zh/docs/enterprise.html)
- [定制Go Package的Go Get导入路径](https://tonybai.com/2017/06/28/set-custom-go-get-import-path-for-go-package/)
- [使用govanityurls让私有代码仓库中的go包支持go get](https://tonybai.com/2017/06/30/go-get-go-packages-in-private-code-repo-by-govanityurls/)
- [如何使用 go get 下载 gitlab 私有项目](http://holys.im/2016/09/20/go-get-in-gitlab/)
