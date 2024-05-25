---
title: "APT软件包管理"
date: 2024-05-19T11:34:09+08:00
tags: ["apt","apt-get","apt-cache","包管理","Debian","Ubuntu"]
categories: ["工具箱"]
draft: true
---

![题图](https://voidint.github.io/tool/apt.jpeg)

`APT`是高级包管理工具（`Advanced Package Tool`），是`Debian`包管理系统的一个高级界面，提供了`apt-get` 程序。它提供了可以搜索和管理软件包，以及查询软件包信息的命令行工具，以及访问`libapt-pkg` 库的所有功能的底层接口。

从`Debian Jessie`开始，一些常用的`apt-get`和`apt-cache`命令在新的`apt`程序中有一个等价的形式。这意味着某些流行的命令，例如 apt-get update、apt-get install、apt-get remove、apt-cache search 和 apt-cache show 可以简单地通过 apt 进行调用，比如 apt update、apt install、apt remove、apt search 和 apt show。

## 命令行
### update：更新包索引
实际上是根据`/etc/apt/sources.list`更新`/var/lib/apt/lists`软件包列表。

```shell
$ sudo apt update
Hit:1 http://mirrors.aliyun.com/ubuntu jammy InRelease
Get:2 http://mirrors.aliyun.com/ubuntu jammy-security InRelease [110 kB]
Get:3 http://mirrors.aliyun.com/ubuntu jammy-updates InRelease [119 kB]
Get:4 http://mirrors.aliyun.com/ubuntu jammy-proposed InRelease [270 kB]
Hit:5 http://mirrors.aliyun.com/ubuntu jammy-backports InRelease
Hit:6 https://download.docker.com/linux/ubuntu jammy InRelease
Fetched 499 kB in 1s (681 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
108 packages can be upgraded. Run 'apt list --upgradable' to see them.
```
	
### upgrade：升级软件包
实际上是根据`/var/lib/apt/lists`中的软件包信息来升级软件。

```shell
# 升级指定软件包
$ sudo apt upgrade -y update-manager-core
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
Get more security updates through Ubuntu Pro with 'esm-apps' enabled:
  gsasl-common libgsasl7
Learn more about Ubuntu Pro at https://ubuntu.com/pro
The following packages will be upgraded:
  python3-update-manager update-manager-core
2 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Need to get 50.7 kB of archives.
After this operation, 6,144 B of additional disk space will be used.
Get:1 http://mirrors.aliyun.com/ubuntu jammy-updates/main amd64 python3-update-manager all 1:22.04.20 [39.1 kB]
Get:2 http://mirrors.aliyun.com/ubuntu jammy-updates/main amd64 update-manager-core all 1:22.04.20 [11.5 kB]
Fetched 50.7 kB in 0s (455 kB/s)
(Reading database ... 83869 files and directories currently installed.)
Preparing to unpack .../python3-update-manager_1%3a22.04.20_all.deb ...
Unpacking python3-update-manager (1:22.04.20) over (1:22.04.10) ...
Preparing to unpack .../update-manager-core_1%3a22.04.20_all.deb ...
Unpacking update-manager-core (1:22.04.20) over (1:22.04.10) ...
Setting up python3-update-manager (1:22.04.20) ...
Setting up update-manager-core (1:22.04.20) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...
Service restarts being deferred:
 systemctl restart aliyun.service
 /etc/needrestart/restart.d/dbus.service
 systemctl restart getty@tty1.service
 systemctl restart k3s.service
 systemctl restart networkd-dispatcher.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service
 systemctl restart user@1000.service

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.


# 升级系统中所有软件包（但不安装额外的软件包或卸载软件包）
$ sudo apt upgrade
```

### full-upgrade：升级所有软件包

```shell
# 升级系统中所有软件包（并且在必要的时候安装额外的软件包或卸载软件包）
# 使用 upgrade 命令升级时，如果为了满足新的依赖关系需要安装额外的软件包，则会保留软件包的旧版本。full-upgrade 命令则没有那么保守。
$ sudo apt full-upgrade
```

### list：列出软件包
- `--installed`选项：列出当前已安装软件包

    ```shell
    # 查看已安装的某个软件包
    $ apt list --installed squid 
    Listing... Done
    squid/jammy-proposed,now 5.9-0ubuntu0.22.04.1 amd64 [installed]
    N: There are 2 additional versions. Please use the '-a' switch to see them.
    ```


- `--upgradeable`选项：列出可升级的软件包

    ```shell
    apt list --upgradable
    Listing... Done
    docker-ce-cli/jammy 5:26.1.3-1~ubuntu.22.04~jammy amd64 [upgradable from: 5:26.1.2-1~ubuntu.22.04~jammy]
    docker-ce-rootless-extras/jammy 5:26.1.3-1~ubuntu.22.04~jammy amd64 [upgradable from: 5:26.1.2-1~ubuntu.22.04~jammy]
    docker-ce/jammy 5:26.1.3-1~ubuntu.22.04~jammy amd64 [upgradable from: 5:26.1.2-1~ubuntu.22.04~jammy]
    ```


- `--all-versions`选项：列出软件包的所有版本

    ```shell
    # 查找已安装软件包的所有版本
    $ apt list --all-versions
    略

    # 查找指定软件包的所有版本
    $ apt list --all-versions squid
    Listing... Done
    squid/jammy-proposed,now 5.9-0ubuntu0.22.04.1 amd64 [installed]
    squid/jammy-security,jammy-updates 5.7-0ubuntu0.22.04.4 amd64
    squid/jammy 5.2-1ubuntu4 amd64
    ``` 


### search：列出匹配关键词的软件包
```shell
$ apt search upx
Sorting... Done
Full Text Search... Done
clamav/jammy-security,jammy-updates 0.103.11+dfsg-0ubuntu0.22.04.1 amd64
  anti-virus utility for Unix - command-line interface

golang-debian-mdosch-xmppsrv-dev/jammy 0.1.1-1 all
  Look up XMPP SRV records (library)

upx-ucl/jammy,now 3.96-3 amd64 [installed]
  efficient live-compressor for executables
```


### show：查看软件包元信息

```shell
$ apt show squid
Package: squid
Version: 5.9-0ubuntu0.22.04.1
Priority: optional
Section: web
Origin: Ubuntu
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Original-Maintainer: Luigi Gangitano <luigi@debian.org>
Bugs: https://bugs.launchpad.net/ubuntu/+filebug
Installed-Size: 8,142 kB
Pre-Depends: init-system-helpers (>= 1.54~), adduser
Depends: libc6 (>= 2.34), libcap2 (>= 1:2.10), libcom-err2 (>= 1.43.9), libcrypt1 (>= 1:4.1.0), libecap3 (>= 1.0.1), libexpat1 (>= 2.0.1), libgcc-s1 (>= 3.4), libgnutls30 (>= 3.7.3), libgssapi-krb5-2 (>= 1.17), libkrb5-3 (>= 1.10+dfsg~), libldap-2.5-0 (>= 2.5.4), libltdl7 (>= 2.4.6), libnetfilter-conntrack3 (>= 1.0.1), libnettle8, libpam0g (>= 0.99.7.1), libsasl2-2 (>= 2.1.27+dfsg2), libstdc++6 (>= 11), libsystemd0, libtdb1 (>= 1.2.7+git20101214), libxml2 (>= 2.7.4), netbase, logrotate (>= 3.5.4-1), squid-common (>= 5.9-0ubuntu0.22.04.1), lsb-base, libdbi-perl, ssl-cert
Recommends: libcap2-bin, ca-certificates
Suggests: squidclient, squid-cgi, squid-purge, resolvconf (>= 0.40), smbclient, ufw, winbind, apparmor
Conflicts: squid-openssl
Homepage: http://www.squid-cache.org
Download-Size: 2,678 kB
APT-Sources: http://mirrors.aliyun.com/ubuntu jammy-proposed/main amd64 Packages
Description: Full featured Web Proxy cache (HTTP proxy GnuTLS flavour)
 Squid is a high-performance proxy caching server for web clients, supporting
 FTP, gopher, ICY and HTTP data objects.

N: There are 2 additional records. Please use the '-a' switch to see them.
```

### install：安装软件包
- `-y`选项：静默安装

```shell
# 安装一个或多个指定软件包
$ sudo apt install -y curl wget

# 安装软件包指定版本
$ sudo apt install squid=5.2-1ubuntu4
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Suggested packages:
  squidclient squid-cgi squid-purge smbclient winbind
The following NEW packages will be installed:
  squid
0 upgraded, 1 newly installed, 0 to remove and 108 not upgraded.
Need to get 2,799 kB of archives.
After this operation, 8,539 kB of additional disk space will be used.
Get:1 http://mirrors.aliyun.com/ubuntu jammy/main amd64 squid amd64 5.2-1ubuntu4 [2,799 kB]
Fetched 2,799 kB in 1s (5,456 kB/s)
Selecting previously unselected package squid.
(Reading database ... 83676 files and directories currently installed.)
Preparing to unpack .../squid_5.2-1ubuntu4_amd64.deb ...
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
Unpacking squid (5.2-1ubuntu4) ...
Setting up squid (5.2-1ubuntu4) ...
Installing new version of config file /etc/squid/errorpage.css ...
Installing new version of config file /etc/squid/squid.conf ...
Setcap worked! /usr/lib/squid/pinger is not suid!
Skipping profile in /etc/apparmor.d/disable: usr.sbin.squid
Processing triggers for man-db (2.10.2-1) ...
Processing triggers for ufw (0.36.1-4build1) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...
Service restarts being deferred:
 systemctl restart aliyun.service
 /etc/needrestart/restart.d/dbus.service
 systemctl restart getty@tty1.service
 systemctl restart k3s.service
 systemctl restart networkd-dispatcher.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.

# 安装本地.deb软件包
$ sudo apt install ./package.deb
```

### reinstall：重新安装软件包

```shell
$ sudo apt reinstall squid
```
	
### remove： 移除软件包（可能会遗留配置文件）

```shell
$ sudo apt remove squid
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages were automatically installed and are no longer required:
  libdbi-perl libecap3 libtdb1 squid-common squid-langpack ssl-cert
Use 'sudo apt autoremove' to remove them.
The following packages will be REMOVED:
  squid
0 upgraded, 0 newly installed, 1 to remove and 108 not upgraded.
After this operation, 8,142 kB disk space will be freed.
Do you want to continue? [Y/n] y
(Reading database ... 83742 files and directories currently installed.)
Removing squid (5.9-0ubuntu0.22.04.1) ...
Processing triggers for man-db (2.10.2-1) ...
```

### purge：移除软件包（软件和配置文件一并删除）

```shell
$ sudo apt purge squid
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages were automatically installed and are no longer required:
  libdbi-perl libecap3 libtdb1 squid-common squid-langpack ssl-cert
Use 'sudo apt autoremove' to remove them.
The following packages will be REMOVED:
  squid*
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
After this operation, 0 B of additional disk space will be used.
Do you want to continue? [Y/n] y
(Reading database ... 83801 files and directories currently installed.)
Purging configuration files for squid (5.9-0ubuntu0.22.04.1) ...
Log and cache files are not automatically removed.
These files are used by squid and squid-openssl flavours.
Remove logs (/var/log/squid) and cache (/var/spool/squid) yourself
if you no longer need them.
dpkg: warning: while removing squid, directory '/var/spool/squid' not empty so not removed
dpkg: warning: while removing squid, directory '/var/log/squid' not empty so not removed
Processing triggers for ufw (0.36.1-4ubuntu0.1) ...
```

### autoremove：自动删除依赖软件包
每当在系统安装软件包时依赖的软件包也将被安装。删除软件包后，软件包依赖的软件将保留在系统。这些被其它软件依赖软件包不再被其它程序使用，可以运行命令`sudo apt autoremove`删除。

```shell
$ sudo apt autoremove
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages will be REMOVED:
  libdbi-perl libecap3 libtdb1 squid-common squid-langpack ssl-cert
0 upgraded, 0 newly installed, 6 to remove and 0 not upgraded.
After this operation, 6,945 kB disk space will be freed.
Do you want to continue? [Y/n] y
(Reading database ... 83788 files and directories currently installed.)
Removing libdbi-perl:amd64 (1.643-3build3) ...
Removing libecap3:amd64 (1.0.1-3.2ubuntu4) ...
Removing libtdb1:amd64 (1.4.5-2build1) ...
Removing squid-common (5.9-0ubuntu0.22.04.1) ...
Removing squid-langpack (20200403-1) ...
Removing ssl-cert (1.1.2) ...
Processing triggers for man-db (2.10.2-1) ...
Processing triggers for libc-bin (2.35-0ubuntu3.7) ...
```

### edit-sources：编辑镜像源文件

关于镜像源文件，详见下文。


## 镜像源
- `/etc/apt/sources.list`：镜像源配置文件
- `/var/lib/apt/lists`：该目录存放的是已经下载的各软件源的元数据，这些数据是系统更新和软件包查找工具的基础。对于基于`Ubuntu`系统为基础构建容器镜像的场景，建议在`RUN`指令的最后删除该目录以缩小容器镜像。

    ```dockerfile
    FROM ubuntu:22.04

    RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "Asia/Shanghai" > /etc/timezone && \
        apt-get update && \
        apt-get install --no-install-recommends -y ca-certificates && \
        update-ca-certificates && \
        rm -rf /var/lib/apt/lists/*
    ```

### 常用镜像源
- Ubuntu 22.04 阿里云镜像源

    ```
    $ cat /etc/apt/sources.list
    deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
    deb-src http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
    deb-src http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
    deb-src http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
    deb-src http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
    deb-src http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
    ```

- Ubuntu 22.04 网易镜像源

    ```
    $ cat /etc/apt/sources.list
    deb http://mirrors.163.com/ubuntu/ jammy main restricted universe multiverse
    deb http://mirrors.163.com/ubuntu/ jammy-security main restricted universe multiverse
    deb http://mirrors.163.com/ubuntu/ jammy-updates main restricted universe multiverse
    deb http://mirrors.163.com/ubuntu/ jammy-proposed main restricted universe multiverse
    deb http://mirrors.163.com/ubuntu/ jammy-backports main restricted universe multiverse
    deb-src http://mirrors.163.com/ubuntu/ jammy main restricted universe multiverse
    deb-src http://mirrors.163.com/ubuntu/ jammy-security main restricted universe multiverse
    deb-src http://mirrors.163.com/ubuntu/ jammy-updates main restricted universe multiverse
    deb-src http://mirrors.163.com/ubuntu/ jammy-proposed main restricted universe multiverse
    deb-src http://mirrors.163.com/ubuntu/ jammy-backports main restricted universe multiverse
    ```


## 参考
- man apt
- [apt及yum包管理工具](https://doc.embedfire.com/linux/imx6/linux_base/zh/latest/linux_basis/software_package/software_package.html)
- [网易Ubuntu镜像使用帮助](https://mirrors.163.com/.help/ubuntu.html)
- [Ubuntu更换阿里云软件源](https://developer.aliyun.com/article/704603)
- [/etc/apt/sources.list 详解](https://zzz.buzz/zh/2016/03/09/etc-apt-sources-list/)

