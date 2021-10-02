---
title: "基于JuiceFS搭建个人网盘"
date: 2021-03-09T16:51:43+08:00
draft: true
tags: ["juicefs", "网盘"]
categories: ["工具箱"]
---

![题图](https://voidint.github.io/tool/juicefs.png)

# 什么是JuiceFS
> JuiceFS 是为云端设计的共享文件系统。
>     云端：采用云服务中的对象存储作为后端，综合性价比极高。
>     共享：上千台机器同时挂载，高性能并发读写，共享数据。
>     易用：POSIX、HDFS、NFS 兼容，无门槛对接现有应用。

以上是[JuiceFS](https://juicefs.com/)的官方定义。简单来说，JuiceFS就是一个基于对象存储的分布式文件系统。


# 目标
基于JuiceFS搭建一个存储在阿里云OSS之上的个人网盘。主机A、B上挂载该网盘后，能做到互通有无，即可读可写。

# 前期准备
1、申请一个阿里云账号，将AccessKey ID导出到环境变量`ACCESS_KEY`，将AccessKey Secret导出到环境变量`SECRET_KEY`。
2、购买阿里云OSS服务并创建bucket。bucket的名字暂时定为`voidint`。
3、准备两台主机。此次实验我准备了一台公有云上的虚拟机以及一台MacBook Pro。
4、准备一台Redis服务器，且以上的两台主机均可以访问此Redis服务。本次实验中我将Redis服务部署在了公有云虚拟机之上。
5、为Redis设置一个强密码并导出到环境变量`REDIS_PASSWORD`。

# 搭建过程
## 构建juicefs二进制程序
```shell
$ git clone https://github.com/juicedata/juicefs.git
$ cd juicefs 
$ make
```

建议使用源代码构建，千万不要按照[上手指南](https://juicefs.com/docs/zh/getting_started.html)中所说通过`curl`下载juicefs。也许是文档未及时更新，官方文档上所描述的均为Python所写的juicefs客户端程序，而**本次实验所用到的是go语言所编写的juicefs客户端程序**。

## 格式化网盘
```shell
$ juicefs help format
NAME:
   juicefs format - format a volume

USAGE:
   juicefs format [command options] REDIS-URL NAME

OPTIONS:
   --block-size value       size of block in KiB (default: 4096)
   --compress value         compression algorithm (lz4, zstd, none) (default: "lz4")
   --storage value          Object storage type (e.g. s3, gcs, oss, cos) (default: "file")
   --bucket value           A bucket URL to store data (default: "/Users/voidint/.juicefs/local")
   --access-key value       Access key for object storage (env ACCESS_KEY)
   --secret-key value       Secret key for object storage (env SECRET_KEY)
   --encrypt-rsa-key value  A path to RSA private key (PEM)
   --force                  overwrite existing format (default: false)
```

格式化的命令及选项如上所示，需要关注的选项分别为`--storage`和`--bucket`。由于本次实验使用的是阿里云OSS，因此将storage选项设置为`oss`。按照[文档](https://github.com/juicedata/juicefs/blob/main/docs/en/how_to_setup_object_storage.md#alibaba-cloud-object-storage-service)所述，将bucket选项值设置为`https://voidint`。

另外，由于阿里云的操作凭证信息已经导出到了`ACCESS_KEY`和`SECRET_KEY`这两个环境变量，因此无需再重复设置format子命令中相关的选项值。

由于网盘中的文件元数据会被存储到Redis，还需要指定一个Redis的URL（[格式](https://pkg.go.dev/github.com/go-redis/redis#ParseURL)），这里指定公有云上主机的IP地址，如`113.31.11.123`。

还需要给网盘取一个显式的名字，如`alicloud`（此处暂不支持中文字符）。


```shell
# 两台主机上分别执行以下命令：
$ ./juicefs format --storage oss --bucket http://voidint 113.31.11.123 alicloud
```


## 挂载网盘
```shell
$ juicefs help mount
NAME:
   juicefs mount - mount a volume

USAGE:
   juicefs mount [command options] REDIS-URL MOUNTPOINT

OPTIONS:
   --metrics value           address to export metrics (default: ":9567")
   --no-usage-report         do not send usage report (default: false)
   -d, --background          run in background (default: false)
   --no-syslog               disable syslog (default: false)
   -o value                  other FUSE options
   --attr-cache value        attributes cache timeout in seconds (default: 1)
   --entry-cache value       file entry cache timeout in seconds (default: 1)
   --dir-entry-cache value   dir entry cache timeout in seconds (default: 1)
   --enable-xattr            enable extended attributes (xattr) (default: false)
   --get-timeout value       the max number of seconds to download an object (default: 60)
   --put-timeout value       the max number of seconds to upload an object (default: 60)
   --io-retries value        number of retries after network failure (default: 30)
   --max-uploads value       number of connections to upload (default: 20)
   --buffer-size value       total read/write buffering in MB (default: 300)
   --prefetch value          prefetch N blocks in parallel (default: 3)
   --writeback               upload objects in background (default: false)
   --cache-dir value         directory paths of local cache, use colon to separate multiple paths (default: "/Users/voidint/.juicefs/cache")
   --cache-size value        size of cached objects in MiB (default: 1024)
   --free-space-ratio value  min free space (ratio) (default: 0.1)
   --cache-partial-only      cache only random/small read (default: false)
```

挂载命令需要设置的选项和参数很少，`-d`可以使其以守护进程方式运行，`REDIS-URL`参数用于指定Redis服务地址，`MOUNTPOINT`用于指定目录挂载点。

```shell
# 两台主机上分别执行以下命令：
$ ./juicefs mount -d 113.31.11.123 ~/jfs

# 查看下文件系统挂载是否成功
$ mount
......
JuiceFS:alicloud on /Users/voidint/jfs (macfuse, nodev, nosuid, synchronous, mounted by voidint)
```

## 测试网盘读写
在等待挂载完毕后，便可以开始对网盘进行读写测试。

```shell
# 两台主机上分别执行以下命令：
$ echo $(hostname) >> ~/jfs/hostname.txt
$ cat ~/jfs/hostname.txt
voidint
113-31-11-123
```

从输出可知，两台主机已经挂载了同一块网盘。

## 卸载网盘
```shell
$ juicefs help umount
NAME:
   juicefs umount - unmount a volume

USAGE:
   juicefs umount [command options] MOUNTPOINT

OPTIONS:
   --force, -f  unmount a busy mount point by force (default: false)
```

卸载网盘的方式也极为简单，只需要指定挂载目录即可。

```shell
# 两台主机上分别执行以下命令：
$ j umount ~/jfs
```

## 再次挂载网盘
为了验证卸载后重新挂载依然能够读写之前的文件，下面重新挂载该网盘。

```shell
# 两台主机上分别执行以下命令：
$ ./juicefs mount -d 113.31.11.123 ~/jfs
$ ls -lh ~/jfs
-rw-r--r--  1 voidint  staff    21B  3  9 18:47 hostname.txt
```

可以看到hostname.txt文件依然还存在。大功告成！


# 参考
- [JuiceFS文档](https://juicefs.com/docs/zh/intro.html)
- [JuiceFS GitHub](https://github.com/juicedata/juicefs)
