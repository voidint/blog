---
title: "Linux Namespaces初体验"
date: 2020-02-25 17:45:51
tags: [Linux,Namespace,《自己动手写docker》]
categories: ["容器"]
draft: true
---

# 简介

下面是[酷壳](https://coolshell.cn/articles/17010.html)给出的关于Linux Namespaces的介绍：

>Linux Namespace是Linux提供的一种内核级别环境隔离的方法。不知道你是否还记得很早以前的Unix有一个叫chroot的系统调用（通过修改根目录把用户jail到一个特定目录下），chroot提供了一种简单的隔离模式：chroot内部的文件系统无法访问外部的内容。Linux Namespace在此基础上，提供了对UTS、IPC、mount、PID、network、User等的隔离机制。

当前Linux一共实现了6种不同类型的Namespace

| Namespace类型     | **系统调用参数** | **内核版本** | **隔离内容**               |
| ----------------- | ---------------- | ------------ | -------------------------- |
| Mount Namespace   | CLONE_NEWNS      | 2.4.19       | 挂载点（文件系统）         |
| UTS Namespace     | CLONE_NEWUTS     | 2.6.19       | 主机名与域名               |
| IPC Namespacce    | CLONE_NEWIPC     | 2.6.19       | 信号量、消息队列和共享内存 |
| PID Namespace     | CLONE_NEWPID     | 2.6.24       | 进程编号                   |
| Network Namespace | CLONE_NEWNET     | 2.6.29       | 网络设备、网络栈、端口等等 |
| User Namespace    | CLONE_NEWUSER    | 3.8          | 用户和用户组               |

Namespace的API主要使用如下3个系统调用：
- clone(): 创建新进程。
- unshare(): 将进程移出某个Namespace。
- setns(): 将进程加入到Namespace中。

# 体验
## UTS Namespace
UTS Namespace用于隔离nodename和domainname两个系统标识，即在不同的Namespace中允许拥有各自的hostname。

```go
// 在GOPATH下新建一个名为mydocker的目录，并在该目录下新建文件main.go。

package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	cmd := exec.Command("bash")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS,
	}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(cmd.Env, `PS1=\[\e[32;1m\][\u@\h \W]$>\[\e[0m\]`)

	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```

以上代码通过exec.Command("bash")方式fork了一个bash子进程，并且使用了CLONE_NEWUTS标识符去创建了一个Namespace。下面验证下bash子进程与mydocker父进程是否处于不同的的UTS Namespace中。

```shell
// 查看最初的系统hostname
$ hostname
ubuntu14.04

// 以root身份运行mydocker程序
$ sudo ./mydocker

// 在隔离的UTS Namespace下修改hostname为hello
root@ubuntu14:/home/voidint# hostname -b hello
root@ubuntu14:/home/voidint# hostname
hello

// 退出bash子进程并查看hostname是否发生变化
root@ubuntu14:/home/voidint# exit
exit

// 可以看到hostname并未发生变化
$ hostname
ubuntu14.04
```

## PID Namespace
PID Namespace用于隔离进程ID，同一个进程在不同的PID Namespace中可以拥有不同的PID。以docker容器为例，每个容器对于宿主机而言都是一个进程，若在容器内部查看到该进程的PID为1，但在宿主机上查看到的PID并非为1，这就是由于容器内拥有独立的PID Namespace的缘故。

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	cmd := exec.Command("bash")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWIPC | syscall.CLONE_NEWPID,
	}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(cmd.Env, `PS1=\[\e[32;1m\][\u@\h \W]$>\[\e[0m\]`)

	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```

编译并运行以上程序，查看当前Namespace的PID，PID为1。

```shell
$ echo $$
1
```

在宿主机上新开一个shell，并通过pstree -pl查看mydocker的PID为2692。注意，这里不能使用ps命令去查看，因为ps、top之类的命令会读取/proc目录下内容，由于此处并未进行Mount Namespace的隔离，查看到的/proc目录下内容并不真实和准确。

## Mount Namespace
Mount Namespace用来隔离各个进程看到的挂载点视图。在Mount Namespace中调用mount()或者umount()都仅仅只是影响当前Namespace内的文件系统，对于全局的文件系统并没有影响。

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	cmd := exec.Command("bash")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS |
			syscall.CLONE_NEWIPC |
			syscall.CLONE_NEWPID |
			syscall.CLONE_NEWNS,
	}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(cmd.Env, `PS1=\[\e[32;1m\][\u@\h \W]$>\[\e[0m\]`)

	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```

运行以上程序，在启动的bash子进程中执行ps -ef，依然可以看到宿主机上的所有进程，这是由于proc文件系统是继承自宿主机。下面重新挂载proc文件系统，并再次查看ps -ef的输出。

```shell
$ mount -t proc proc /proc

$ ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 18:11 pts/1    00:00:00 bash
root        14     1  0 18:16 pts/1    00:00:00 ps -ef
```

可以看到，重新挂载proc文件系统后，ps命令仅能看到容器内的进程了，符合预期。

# 参考
- [《自己动手写Docker》](https://www.amazon.cn/dp/B072ZDHK9S/ref=sr_1_1?ie=UTF8&qid=1535615095&sr=8-1&keywords=%E8%87%AA%E5%B7%B1%E5%8A%A8%E6%89%8B%E5%86%99docker)
- [Namespaces](http://man7.org/linux/man-pages/man7/namespaces.7.html)
- [DOCKER基础技术：LINUX NAMESPACE（上）](https://coolshell.cn/articles/17010.html)
- [DOCKER基础技术：LINUX NAMESPACE（下）](https://coolshell.cn/articles/17029.html)
- [Docker背后的内核知识——Namespace资源隔离](http://www.infoq.com/cn/articles/docker-kernel-knowledge-namespace-resource-isolation)