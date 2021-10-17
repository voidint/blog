---
title: "strace简明教程"
date: 2021-10-17T14:01:42+08:00
tags: [strace]
categories: ["工具箱"]
draft: true
---


**strace** 是什么？维基百科给出的定义如下：

> strace 是 Linux 系统下的一个用于诊断、调试和指导用户空间的实用程序。它用于监视和篡改进程与 Linux 内核之间的交互，包括系统调用、信号传递和进程状态的更改。

不管什么编程语言写的程序，只要跑在 Linux 系统下，就必然需要与内核交互。某些高级编程语言，在语言或者标准库层面上或许并没有提供直接与内核交互的接口，但那也仅仅是虚拟机或者解释器之类的运行时屏蔽了这部分内容而已。作为运行在操作系统上的一个进程，与内核交互（也就是系统调用）是不可避免的。既然不可避免，当系统调用返回错误或者阻塞时，如何才能定位其中的原因？编程语言层面返回的错误固然能提供一部分信息，但这也属于是**二手信息**罢了。那怎么获取**一手信息**并快速定位问题的原因呢？答案就是 strace 。

不同的 strace 版本功能上存在不少差异，为了避免鸡同鸭讲的情况发生，我把我所使用的 strace 版本放这：

```shell
# strace -V
strace -- version 5.1
Copyright (c) 1991-2019 The strace developers <https://strace.io>.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Optional features enabled: stack-trace=libdw stack-demangle m32-mpers mx32-mpers
```

# strace 选项


| 类别          | 选项 | 选项值         | 描述                                                         | 示例                                                         |
| ------------- | ---- | -------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Output format | -o   | 目标文件       | 将系统调用跟踪信息输出到文件而非 stderr                      | strace -o trace.log ls /                                     |
|               | -A   | 无             | 与`-o`选项一起使用，会将输出以追加的方式写入文件。           | strace -o trace.log -A ls /                                  |
|               | -i   | 无             | 打印系统调用时的指令指针                                     | strace -i  ls /                                              |
|               | -t   | 无             | 打印系统调用时的时间（时、分、秒）                           | strace -t ls /                                               |
|               | -tt  | 无             | 打印系统调用时的时间（时、分、秒、微秒）                     | strace -tt ls /                                              |
|               | -ttt | 无             | 打印系统调用时的时间（Unix时间戳、微秒）                     | strace -ttt ls /                                             |
|               | -T   | 无             | 打印每个系统调用的耗时                                       | strace -T ls /                                               |
|               | -y   | 无             | 打印文件描述符所对应的文件名                                 | strace -y ls /                                               |
|               | -yy  | 无             | 打印与套接字文件描述符相关的协议特定信息，以及与设备文件描述符相关的块/字符设备号。 | strace -yy -e trace=connect,write ping -c 1 www.baidu.com    |
| Statistics    | -c   | 无             | 统计每个系统调动的耗时、调用次数、失败数                     | strace -c ls /                                               |
| Filtering     | -e   | trace=set      | 跟踪**指定集合中**的系统调用                                 | strace -e trace=read,write ./a.out                           |
|               |      | trace=/regex   | 跟踪**名称与正则表达式匹配**的系统调用                       | strace -e trace=/epoll_ ./a.out                              |
|               |      | trace=%file    | 跟踪**含有文件名参数**的系统调用                             | strace -e trace=%file ls /                                   |
|               |      | trace=%process | 跟踪所有**进程管理相关**的系统调用                           | strace -e trace=%process bash                                |
|               |      | trace=%network | 跟踪所有**网络相关**的系统调用                               | strace -e trace=%network ping -c 1 github.com                |
|               |      | trace=%signal  | 跟踪所有**信号相关**的系统调用                               | strace -e trace=%signal bash                                 |
|               |      | trace=%ipc     | 跟踪所有**进程间通信相关**系统调用                           |                                                              |
|               |      | trace=%desc    | 跟踪所有**文件描述符相关**的系统调用                         | strace -e trace=%desc ls /                                   |
|               |      | trace=%memory  | 跟踪所有**内存相关**的系统调用                               | strace -e trace=%memory ls /                                 |
|               |      | signal=set     | 跟踪**指定信号集合中**的系统调用                             |                                                              |
|               |      | read=set       | 转储从文件描述符集合中读取的内容（**不会过滤并仅保留 read 系统调用**） | strace -e read=3,4,5 -e trace=read ls /                      |
|               |      | write=set      | 转储往文件描述符集合中写入的内容（**不会过滤并仅保留 write 系统调用**） | strace -e write=1,3,5 -e trace=write echo "hello world"      |
|               |      | raw=set        | 不解码**以原生（十六进制）形式显示**系统调用参数值           | strace -e raw=read -e trace=read,write ls -l /               |
|               | -P   | 文件路径       | 跟踪**访问指定路径的系统调用**（可指定多个文件路径）         | strace -P /dev/stdout -P /dev/fd/1 -y ls /                   |
|               | -v   | 无             | 打印详细信息                                                 | strace -v ls /                                               |
| Tracing       | -f   | 无             | 跟踪**由 fork 、vfork、 clone 等系统调用创建的子进程**       | strace -f -e trace=fork,vfork,clone ./a.out                  |
|               | -ff  | 无             | 与`-o`选项一起使用，会将输出写入名为`filename.pid`的文件中（不能与`-c`一同使用）。 | strace -o trace.log -ff -f -e trace=clone ./a.out            |
| Startup       | -E   | 环境变量名=值  | 启动进程时为进程提供额外的**环境变量列表**                   | strace -E NAME=voidint -E AGE=24 -e trace=write sh -c 'echo $NAME;echo $AGE' |
|               | -p   | 进程ID         | 待跟踪的**目标进程ID**（若要跟踪多个进程，可多次指定`-p`选项） | strace -p 1234 -p 5678                                       |
| Miscellaneous | -V   | 无             | 打印 strace 版本信息                                         | strace -V                                                    |


# 示例
### 1、跟踪程序运行过程中发起的所有的系统调用
```shell
# strace
strace ls
execve("/usr/bin/ls", ["ls"], 0x7ffc202c4e10 /* 29 vars */) = 0
brk(NULL)                               = 0x55c6f9104000
arch_prctl(0x3001 /* ARCH_??? */, 0x7ffc285a5640) = -1 EINVAL (Invalid argument)
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=39762, ...}) = 0
mmap(NULL, 39762, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f72740d5000
close(3)                                = 0
openat(AT_FDCWD, "/lib64/libselinux.so.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200z\0\0\0\0\0\0"..., 832) = 832
lseek(3, 157040, SEEK_SET)              = 157040
......
......
......
openat(AT_FDCWD, "/lib64/libpthread.so.0", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0pn\0\0\0\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0755, st_size=320504, ...}) = 0
mmap(NULL, 2225344, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f727301c000
mprotect(0x7f7273037000, 2093056, PROT_NONE) = 0
mmap(0x7f7273236000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1a000) = 0x7f7273236000
mmap(0x7f7273238000, 13504, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f7273238000
close(3)                                = 0
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f72740d1000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f72740cf000
arch_prctl(ARCH_SET_FS, 0x7f72740d2640) = 0
mprotect(0x7f7273a7d000, 16384, PROT_READ) = 0
mprotect(0x7f7273236000, 4096, PROT_READ) = 0
mprotect(0x7f727343e000, 4096, PROT_READ) = 0
mprotect(0x7f72736c2000, 4096, PROT_READ) = 0
mprotect(0x7f7273c8b000, 4096, PROT_READ) = 0
mprotect(0x7f7273eb3000, 4096, PROT_READ) = 0
mprotect(0x55c6f7c2f000, 8192, PROT_READ) = 0
mprotect(0x7f72740df000, 4096, PROT_READ) = 0
munmap(0x7f72740d5000, 39762)           = 0
set_tid_address(0x7f72740d2910)         = 2351897
set_robust_list(0x7f72740d2920, 24)     = 0
rt_sigaction(SIGRTMIN, {sa_handler=0x7f72730228f0, sa_mask=[], sa_flags=SA_RESTORER|SA_SIGINFO, sa_restorer=0x7f727302eb20}, NULL, 8) = 0
rt_sigaction(SIGRT_1, {sa_handler=0x7f7273022980, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART|SA_SIGINFO, sa_restorer=0x7f727302eb20}, NULL, 8) = 0
rt_sigprocmask(SIG_UNBLOCK, [RTMIN RT_1], NULL, 8) = 0
prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
statfs("/sys/fs/selinux", 0x7ffc285a5590) = -1 ENOENT (No such file or directory)
statfs("/selinux", 0x7ffc285a5590)      = -1 ENOENT (No such file or directory)
brk(NULL)                               = 0x55c6f9104000
brk(0x55c6f9125000)                     = 0x55c6f9125000
openat(AT_FDCWD, "/proc/filesystems", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0444, st_size=0, ...}) = 0
read(3, "nodev\tsysfs\nnodev\trootfs\nnodev\tr"..., 1024) = 327
read(3, "", 1024)                       = 0
close(3)                                = 0
access("/etc/selinux/config", F_OK)     = 0
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/locale.alias", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=2997, ...}) = 0
read(3, "# Locale name alias data base.\n#"..., 4096) = 2997
read(3, "", 4096)                       = 0
close(3)                                = 0
......
......
......
openat(AT_FDCWD, "/usr/lib/locale/en_US.UTF-8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=337024, ...}) = 0
mmap(NULL, 337024, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f7274075000
close(3)                                = 0
ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
ioctl(1, TIOCGWINSZ, {ws_row=48, ws_col=204, ws_xpixel=2856, ws_ypixel=1632}) = 0
openat(AT_FDCWD, ".", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
fstat(3, {st_mode=S_IFDIR|0550, st_size=4096, ...}) = 0
getdents64(3, /* 26 entries */, 32768)  = 800
getdents64(3, /* 0 entries */, 32768)   = 0
close(3)                                = 0
fstat(1, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x1), ...}) = 0
write(1, "bin  check.sh  go  install.sh  l"..., 76bin  check.sh  go  install.sh  linuxc  valgrind  valgrind-3.17.0  workspace
) = 76
close(1)                                = 0
close(2)                                = 0
exit_group(0)                           = ?
+++ exited with 0 +++
```

是不是很惊讶，一个 ls 命令竟然产生了这么多的系统调用（当然其中也包含了一部分 strace 进程 fork 和 execve 目标程序的系统调用）。其中，有不少内容我做了适当省略，的确是输出太多。

### 2、跟踪已运行进程实时发起的系统调用
```shell
# strace -p $(pidof rsyslogd)
strace: Process 994 attached
select(1, NULL, NULL, NULL, {tv_sec=212, tv_usec=794547}
```
此处以守护进程 rsyslogd 为例，尝试去跟踪该进程的系统调用。一般线上问题排查场景也是附加到一个正在运行的进程上，观察该进程的系统调用，看是否有错误发生，看是否某个系统调用执行时间过长等。

### 3、统计每个系统调动的耗时、调用次数、失败数
```shell
# strace -c ping -c 1 github.com
PING github.com (10.23.253.91) 56(84) bytes of data.
64 bytes from 10.23.253.91 (10.23.253.91): icmp_seq=1 ttl=63 time=0.845 ms

--- github.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.845/0.845/0.845/0.000 ms
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 16.82    0.000144           2        71           mmap
 15.54    0.000133           2        60        14 openat
 13.43    0.000115           2        42           mprotect
  8.64    0.000074           1        60           read
  7.01    0.000060          60         1           sendmmsg
  6.43    0.000055           1        53           close
  5.72    0.000049           1        47           fstat
  5.49    0.000047           4        11         2 socket
  3.62    0.000031           6         5         2 connect
  2.92    0.000025           6         4           sendto
  2.69    0.000023           5         4           munmap
  2.10    0.000018           0        29           lseek
  1.75    0.000015           1        11           setsockopt
  0.93    0.000008           1         5           poll
  0.82    0.000007           2         3           recvfrom
  0.70    0.000006           1         6           write
  0.70    0.000006           1         5           ioctl
  0.70    0.000006           0         7           capget
  0.47    0.000004           2         2           stat
  0.47    0.000004           0         5           rt_sigaction
  0.47    0.000004           1         3           capset
  0.23    0.000002           0         6           brk
  0.23    0.000002           0         4           rt_sigprocmask
  0.23    0.000002           0         3         2 access
  0.23    0.000002           2         1           setitimer
  0.23    0.000002           0         3           getsockname
  0.23    0.000002           0         5           getsockopt
  0.23    0.000002           1         2           futex
  0.12    0.000001           0         2           getpid
  0.12    0.000001           0        15           recvmsg
  0.12    0.000001           1         1           uname
  0.12    0.000001           1         1           setuid
  0.12    0.000001           1         1           geteuid
  0.12    0.000001           0         2           prctl
  0.12    0.000001           0         2         1 arch_prctl
  0.12    0.000001           1         1           prlimit64
  0.00    0.000000           0         2           bind
  0.00    0.000000           0         1           execve
  0.00    0.000000           0         2           getuid
  0.00    0.000000           0         2         2 statfs
  0.00    0.000000           0         1           set_tid_address
  0.00    0.000000           0         5           ppoll
  0.00    0.000000           0         1           set_robust_list
------ ----------- ----------- --------- --------- ----------------
100.00    0.000856                   497        23 total
```

### 4、跟踪指定名称的系统调用
```shell
# strace -e trace=read,write ls /
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200z\0\0\0\0\0\0"..., 832) = 832
read(3, "\4\0\0\0 \0\0\0\5\0\0\0GNU\0\1\0\0\300\4\0\0\0\30\0\0\0\0\0\0\0"..., 48) = 48
read(3, "\4\0\0\0 \0\0\0\5\0\0\0GNU\0\1\0\0\300\4\0\0\0\30\0\0\0\0\0\0\0"..., 48) = 48
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\30\0\0\0\0\0\0"..., 832) = 832
read(3, "\4\0\0\0\20\0\0\0\5\0\0\0GNU\0\2\0\0\300\4\0\0\0\3\0\0\0\0\0\0\0", 32) = 32
read(3, "\4\0\0\0\20\0\0\0\5\0\0\0GNU\0\2\0\0\300\4\0\0\0\3\0\0\0\0\0\0\0", 32) = 32
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\3008\2\0\0\0\0\0"..., 832) = 832
read(3, "\4\0\0\0\20\0\0\0\5\0\0\0GNU\0\2\0\0\300\4\0\0\0\3\0\0\0\0\0\0\0", 32) = 32
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200#\0\0\0\0\0\0"..., 832) = 832
read(3, "\4\0\0\0\20\0\0\0\5\0\0\0GNU\0\2\0\0\300\4\0\0\0\3\0\0\0\0\0\0\0", 32) = 32
read(3, "\4\0\0\0\20\0\0\0\5\0\0\0GNU\0\2\0\0\300\4\0\0\0\3\0\0\0\0\0\0\0", 32) = 32
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\20\0\0\0\0\0\0"..., 832) = 832
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0pn\0\0\0\0\0\0"..., 832) = 832
read(3, "nodev\tsysfs\nnodev\trootfs\nnodev\tr"..., 1024) = 327
read(3, "", 1024)                       = 0
read(3, "# Locale name alias data base.\n#"..., 4096) = 2997
read(3, "", 4096)                       = 0
write(1, "bin  boot  dev\tetc  home  lib\tli"..., 100bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
) = 100
+++ exited with 0 +++
```

如今这个社会不同于古代社会，信息过载让人眼花缭乱，因此信息的过滤提炼变得尤为重要。而`-e`选项就是 strace 工具提供的最重要的过滤选项。对于想要跟踪特定的某几个系统调用的需求，只需要指定`-e trace=syscall1,syscall2,syscall3`的选项，那么输出的内容将只会保留你所指定的那三个系统调用，其它无关系统调用均不会被展示。

### 5、跟踪匹配正则表达式的系统调用
```shell
# strace -e trace=/get ping -c 1 github.com
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, NULL) = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, {effective=1<<CAP_CHOWN|1<<CAP_DAC_OVERRIDE|1<<CAP_DAC_READ_SEARCH|1<<CAP_FOWNER|1<<CAP_FSETID|1<<CAP_KILL|1<<CAP_SETGID|1<<CAP_SETUID|1<<CAP_SETPCAP|1<<CAP_LINUX_IMMUTABLE|1<<CAP_NET_BIND_SERVICE|1<<CAP_NET_BROADCAST|1<<CAP_NET_ADMIN|1<<CAP_NET_RAW|1<<CAP_IPC_LOCK|1<<CAP_IPC_OWNER|1<<CAP_SYS_MODULE|1<<CAP_SYS_RAWIO|1<<CAP_SYS_CHROOT|1<<CAP_SYS_PTRACE|1<<CAP_SYS_PACCT|1<<CAP_SYS_ADMIN|1<<CAP_SYS_BOOT|1<<CAP_SYS_NICE|1<<CAP_SYS_RESOURCE|1<<CAP_SYS_TIME|1<<CAP_SYS_TTY_CONFIG|1<<CAP_MKNOD|1<<CAP_LEASE|1<<CAP_AUDIT_WRITE|1<<CAP_AUDIT_CONTROL|1<<CAP_SETFCAP|1<<CAP_MAC_OVERRIDE|1<<CAP_MAC_ADMIN|1<<CAP_SYSLOG|1<<CAP_WAKE_ALARM|1<<CAP_BLOCK_SUSPEND|1<<CAP_AUDIT_READ, permitted=1<<CAP_CHOWN|1<<CAP_DAC_OVERRIDE|1<<CAP_DAC_READ_SEARCH|1<<CAP_FOWNER|1<<CAP_FSETID|1<<CAP_KILL|1<<CAP_SETGID|1<<CAP_SETUID|1<<CAP_SETPCAP|1<<CAP_LINUX_IMMUTABLE|1<<CAP_NET_BIND_SERVICE|1<<CAP_NET_BROADCAST|1<<CAP_NET_ADMIN|1<<CAP_NET_RAW|1<<CAP_IPC_LOCK|1<<CAP_IPC_OWNER|1<<CAP_SYS_MODULE|1<<CAP_SYS_RAWIO|1<<CAP_SYS_CHROOT|1<<CAP_SYS_PTRACE|1<<CAP_SYS_PACCT|1<<CAP_SYS_ADMIN|1<<CAP_SYS_BOOT|1<<CAP_SYS_NICE|1<<CAP_SYS_RESOURCE|1<<CAP_SYS_TIME|1<<CAP_SYS_TTY_CONFIG|1<<CAP_MKNOD|1<<CAP_LEASE|1<<CAP_AUDIT_WRITE|1<<CAP_AUDIT_CONTROL|1<<CAP_SETFCAP|1<<CAP_MAC_OVERRIDE|1<<CAP_MAC_ADMIN|1<<CAP_SYSLOG|1<<CAP_WAKE_ALARM|1<<CAP_BLOCK_SUSPEND|1<<CAP_AUDIT_READ, inheritable=0}) = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, NULL) = 0
getuid()                                = 0
getuid()                                = 0
geteuid()                               = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, NULL) = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, {effective=0, permitted=1<<CAP_NET_ADMIN|1<<CAP_NET_RAW, inheritable=0}) = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, NULL) = 0
capget({version=_LINUX_CAPABILITY_VERSION_3, pid=0}, {effective=1<<CAP_NET_RAW, permitted=1<<CAP_NET_ADMIN|1<<CAP_NET_RAW, inheritable=0}) = 0
getsockname(5, {sa_family=AF_INET, sin_port=htons(35064), sin_addr=inet_addr("10.23.182.41")}, [16]) = 0
getsockopt(3, SOL_SOCKET, SO_RCVBUF, [131072], [4]) = 0
PING github.com (10.23.253.91) 56(84) bytes of data.
getpid()                                = 2480162
getpid()                                = 2480162
getsockopt(5, SOL_SOCKET, SO_PROTOCOL, [0], [4]) = 0
getsockname(5, {sa_family=AF_NETLINK, nl_pid=2480162, nl_groups=00000000}, [16->12]) = 0
getsockopt(5, SOL_NETLINK, NETLINK_LIST_MEMBERSHIPS, NULL, [0]) = 0
getsockopt(5, SOL_SOCKET, SO_PROTOCOL, [0], [4]) = 0
getsockname(5, {sa_family=AF_NETLINK, nl_pid=2480162, nl_groups=00000000}, [16->12]) = 0
getsockopt(5, SOL_NETLINK, NETLINK_LIST_MEMBERSHIPS, NULL, [0]) = 0
64 bytes from 10.23.253.91 (10.23.253.91): icmp_seq=1 ttl=63 time=0.694 ms

--- github.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.694/0.694/0.694/0.000 ms
+++ exited with 0 +++
```

正则表达式是一个强大的工具，它也可以被用于 strace 工具的信息过滤中，`-e trace=/regex`选项正是为此功能所设计。

### 6、跟踪含有文件名参数的系统调用
```shell
# strace -e trace=%file ls /
execve("/usr/bin/ls", ["ls", "/"], 0x7ffe731b8868 /* 28 vars */) = 0
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libselinux.so.1", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libcap.so.2", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libpcre2-8.so.0", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libdl.so.2", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib64/libpthread.so.0", O_RDONLY|O_CLOEXEC) = 3
statfs("/sys/fs/selinux", 0x7ffe4f0c32a0) = -1 ENOENT (No such file or directory)
statfs("/selinux", 0x7ffe4f0c32a0)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/proc/filesystems", O_RDONLY|O_CLOEXEC) = 3
access("/etc/selinux/config", F_OK)     = 0
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
......
......
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = 3
stat("/", {st_mode=S_IFDIR|0555, st_size=244, ...}) = 0
openat(AT_FDCWD, "/", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
+++ exited with 0 +++
```

仔细观察上面的示例可以发现，指定`-e trace=%file`选项后，输出的内容拥有一个共同的特点，即均是包含文件名参数的系统调用。

### 7、跟踪进程管理相关的系统调用
```shell
# strace -e trace=%process bash
execve("/usr/bin/bash", ["bash"], 0x7fffbd1b18f0 /* 28 vars */) = 0
arch_prctl(0x3001 /* ARCH_??? */, 0x7fff45b89800) = -1 EINVAL (Invalid argument)
arch_prctl(ARCH_SET_FS, 0x7f213ad03740) = 0
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481772
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 2481772
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481772, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, 0x7fff45b86e50, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481774
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481774, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], WNOHANG, NULL) = 2481774
wait4(-1, 0x7fff45b862d0, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481777
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481777, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], WNOHANG, NULL) = 2481777
wait4(-1, 0x7fff45b866d0, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481779
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 1}], 0, NULL) = 2481779
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481779, si_uid=0, si_status=1, si_utime=0, si_stime=0} ---
wait4(-1, 0x7fff45b86c50, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481780
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 2481780
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481780, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, 0x7fff45b86e50, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481782
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 2481782
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481782, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, 0x7fff45b86e50, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481784
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481784, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], WNOHANG, NULL) = 2481784
wait4(-1, 0x7fff45b869d0, WNOHANG, NULL) = -1 ECHILD (No child processes)
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f213ad03a10) = 2481786
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2481786, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
wait4(-1, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], WNOHANG, NULL) = 2481786
wait4(-1, 0x7fff45b868d0, WNOHANG, NULL) = -1 ECHILD (No child processes)
```

若是想要跟踪进程管理相关的系统调用，那么`-e trace=%process`选项能满足这个需求。具体指代的系统调用主要是创建进程（fork 系列）、执行新程序（exec 系列）、回收子进程（wait 系列）相关的一些列系统调用。

### 8、跟踪所有网络相关的系统调用
```shell
# strace -e trace=%network ping -c 1 github.com
socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP) = -1 EACCES (Permission denied)
socket(AF_INET, SOCK_RAW, IPPROTO_ICMP) = 3
socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6) = -1 EACCES (Permission denied)
socket(AF_INET6, SOCK_RAW, IPPROTO_ICMPV6) = 4
socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5
connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5
connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5
setsockopt(5, SOL_IP, IP_RECVERR, [1], 4) = 0
connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0
sendmmsg(5, [{msg_hdr={msg_name=NULL, msg_namelen=0, msg_iov=[{iov_base="nl\1\0\0\1\0\0\0\0\0\0\6github\3com\0\0\1\0\1", iov_len=28}], msg_iovlen=1, msg_controllen=0, msg_flags=0}, msg_len=28}, {msg_hdr={msg_name=NULL, msg_namelen=0, msg_iov=[{iov_base="\364q\1\0\0\1\0\0\0\0\0\0\6github\3com\0\0\34\0\1", iov_len=28}], msg_iovlen=1, msg_controllen=0, msg_flags=0}, msg_len=28}], 2, MSG_NOSIGNAL) = 2
recvfrom(5, "nl\201\0\0\1\0\1\0\0\0\0\6github\3com\0\0\1\0\1\300\f\0\1"..., 2048, 0, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, [28->16]) = 44
recvfrom(5, "\364q\201\200\0\1\0\0\0\1\0\0\6github\3com\0\0\34\0\1\300\f\0\6"..., 65536, 0, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, [28->16]) = 93
socket(AF_INET, SOCK_DGRAM, IPPROTO_IP) = 5
connect(5, {sa_family=AF_INET, sin_port=htons(1025), sin_addr=inet_addr("10.23.253.91")}, 16) = 0
getsockname(5, {sa_family=AF_INET, sin_port=htons(57426), sin_addr=inet_addr("10.23.182.41")}, [16]) = 0
setsockopt(3, SOL_RAW, ICMP_FILTER, ~(1<<ICMP_ECHOREPLY|1<<ICMP_DEST_UNREACH|1<<ICMP_SOURCE_QUENCH|1<<ICMP_REDIRECT|1<<ICMP_TIME_EXCEEDED|1<<ICMP_PARAMETERPROB), 4) = 0
setsockopt(3, SOL_IP, IP_RECVERR, [1], 4) = 0
setsockopt(3, SOL_SOCKET, SO_SNDBUF, [324], 4) = 0
setsockopt(3, SOL_SOCKET, SO_RCVBUF, [65536], 4) = 0
getsockopt(3, SOL_SOCKET, SO_RCVBUF, [131072], [4]) = 0
PING github.com (10.23.253.91) 56(84) bytes of data.
setsockopt(3, SOL_SOCKET, SO_TIMESTAMP_OLD, [1], 4) = 0
setsockopt(3, SOL_SOCKET, SO_SNDTIMEO_OLD, "\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0", 16) = 0
setsockopt(3, SOL_SOCKET, SO_RCVTIMEO_OLD, "\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0", 16) = 0
sendto(3, "\10\0\2sy\6\0\1)\225ka\0\0\0\0&\274\2\0\0\0\0\0\20\21\22\23\24\25\26\27"..., 64, 0, {sa_family=AF_INET, sin_port=htons(0), sin_addr=inet_addr("10.23.253.91")}, 16) = 64
socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5
setsockopt(5, SOL_IP, IP_RECVERR, [1], 4) = 0
connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0
sendto(5, "\376j\1\0\0\1\0\0\0\0\0\0\291\003253\00223\00210\7in-add"..., 43, MSG_NOSIGNAL, NULL, 0) = 43
recvfrom(5, "\376j\201\203\0\1\0\0\0\1\0\0\291\003253\00223\00210\7in-add"..., 1024, 0, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, [28->16]) = 120
socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5
getsockopt(5, SOL_SOCKET, SO_PROTOCOL, [0], [4]) = 0
setsockopt(5, SOL_NETLINK, NETLINK_PKTINFO, [1], 4) = 0
bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0
getsockname(5, {sa_family=AF_NETLINK, nl_pid=2586886, nl_groups=00000000}, [16->12]) = 0
getsockopt(5, SOL_NETLINK, NETLINK_LIST_MEMBERSHIPS, NULL, [0]) = 0
socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5
getsockopt(5, SOL_SOCKET, SO_PROTOCOL, [0], [4]) = 0
setsockopt(5, SOL_NETLINK, NETLINK_PKTINFO, [1], 4) = 0
bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0
getsockname(5, {sa_family=AF_NETLINK, nl_pid=2586886, nl_groups=00000000}, [16->12]) = 0
getsockopt(5, SOL_NETLINK, NETLINK_LIST_MEMBERSHIPS, NULL, [0]) = 0
64 bytes from 10.23.253.91 (10.23.253.91): icmp_seq=1 ttl=63 time=0.757 ms

--- github.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.757/0.757/0.757/0.000 ms
+++ exited with 0 +++
```

`-e trace=%network`或者`-e trace=%net`是跟踪网络相关系统调用的选项。实际输出的内容远比这个多，这是做了适当省略后的输出。

### 9、跟踪所有信号相关的系统调用
```shell
# strace -e trace=%signal sh -c echo voidint
rt_sigprocmask(SIG_BLOCK, NULL, [], 8)  = 0
rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigprocmask(SIG_BLOCK, NULL, [], 8)  = 0
rt_sigaction(SIGQUIT, {sa_handler=SIG_IGN, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigaction(SIGCHLD, {sa_handler=0x555e8a87b1b0, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART, sa_restorer=0x7f3ca8e8e880}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTORER|SA_RESTART, sa_restorer=0x7f3ca8e8e880}, 8) = 0
rt_sigprocmask(SIG_BLOCK, NULL, [], 8)  = 0
rt_sigprocmask(SIG_BLOCK, NULL, [], 8)  = 0

rt_sigprocmask(SIG_BLOCK, [CHLD], [], 8) = 0
rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0
+++ exited with 0 +++
```


### 10、跟踪所有文件描述符相关的系统调用
```shell
# strace -e trace=%desc ls /
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=39762, ...}) = 0
mmap(NULL, 39762, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7fec70e79000
close(3)                                = 0
openat(AT_FDCWD, "/lib64/libselinux.so.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200z\0\0\0\0\0\0"..., 832) = 832
lseek(3, 157040, SEEK_SET)              = 157040
read(3, "\4\0\0\0 \0\0\0\5\0\0\0GNU\0\1\0\0\300\4\0\0\0\30\0\0\0\0\0\0\0"..., 48) = 48
fstat(3, {st_mode=S_IFREG|0755, st_size=168568, ...}) = 0
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fec70e77000
lseek(3, 157040, SEEK_SET)              = 157040
read(3, "\4\0\0\0 \0\0\0\5\0\0\0GNU\0\1\0\0\300\4\0\0\0\30\0\0\0\0\0\0\0"..., 48) = 48
mmap(NULL, 2266608, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7fec70a31000
mmap(0x7fec70c57000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x26000) = 0x7fec70c57000
mmap(0x7fec70c59000, 5616, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7fec70c59000
......
......
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fec70e75000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fec70e73000
openat(AT_FDCWD, "/proc/filesystems", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0444, st_size=0, ...}) = 0
read(3, "nodev\tsysfs\nnodev\trootfs\nnodev\tr"..., 1024) = 327
read(3, "", 1024)                       = 0
close(3)                                = 0
......
......
openat(AT_FDCWD, "/usr/lib/locale/en_US.UTF-8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=337024, ...}) = 0
mmap(NULL, 337024, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7fec70e19000
close(3)                                = 0
ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
ioctl(1, TIOCGWINSZ, {ws_row=48, ws_col=204, ws_xpixel=2856, ws_ypixel=1632}) = 0
openat(AT_FDCWD, "/", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
fstat(3, {st_mode=S_IFDIR|0555, st_size=244, ...}) = 0
getdents64(3, /* 22 entries */, 32768)  = 552
getdents64(3, /* 0 entries */, 32768)   = 0
close(3)                                = 0
fstat(1, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0), ...}) = 0
write(1, "bin  boot  dev\tetc  home  lib\tli"..., 100bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
) = 100
close(1)                                = 0
close(2)                                = 0
+++ exited with 0 +++
```

许多系统调用的参数中都包含了文件描述符，要想过滤出这类系统调用，只要加上`-e trace=%desc`选项。

### 11、跟踪所有内存相关的系统调用
```shell
# strace -e trace=%memory ls /
brk(NULL)                               = 0x565257b60000
mmap(NULL, 39762, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb2a000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f475eb28000
mmap(NULL, 2266608, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475e6e2000
mprotect(0x7f475e709000, 2093056, PROT_NONE) = 0
mmap(0x7f475e908000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x26000) = 0x7f475e908000
mmap(0x7f475e90a000, 5616, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f475e90a000
mmap(NULL, 2117944, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475e4dc000
mprotect(0x7f475e4e0000, 2097152, PROT_NONE) = 0
mmap(0x7f475e6e0000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x4000) = 0x7f475e6e0000
mmap(NULL, 3942144, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475e119000
mprotect(0x7f475e2d2000, 2097152, PROT_NONE) = 0
mmap(0x7f475e4d2000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1b9000) = 0x7f475e4d2000
mmap(0x7f475e4d8000, 14080, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f475e4d8000
mmap(NULL, 2634280, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475de95000
mprotect(0x7f475df18000, 2093056, PROT_NONE) = 0
mmap(0x7f475e117000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x82000) = 0x7f475e117000
mmap(NULL, 2109744, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475dc91000
mprotect(0x7f475dc94000, 2093056, PROT_NONE) = 0
mmap(0x7f475de93000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x2000) = 0x7f475de93000
mmap(NULL, 2225344, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f475da71000
mprotect(0x7f475da8c000, 2093056, PROT_NONE) = 0
mmap(0x7f475dc8b000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1a000) = 0x7f475dc8b000
mmap(0x7f475dc8d000, 13504, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f475dc8d000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f475eb26000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f475eb24000
mprotect(0x7f475e4d2000, 16384, PROT_READ) = 0
mprotect(0x7f475dc8b000, 4096, PROT_READ) = 0
mprotect(0x7f475de93000, 4096, PROT_READ) = 0
mprotect(0x7f475e117000, 4096, PROT_READ) = 0
mprotect(0x7f475e6e0000, 4096, PROT_READ) = 0
mprotect(0x7f475e908000, 4096, PROT_READ) = 0
mprotect(0x56525713d000, 8192, PROT_READ) = 0
mprotect(0x7f475eb34000, 4096, PROT_READ) = 0
munmap(0x7f475eb2a000, 39762)           = 0
brk(NULL)                               = 0x565257b60000
brk(0x565257b81000)                     = 0x565257b81000
mmap(NULL, 368, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb33000
mmap(NULL, 26998, PROT_READ, MAP_SHARED, 3, 0) = 0x7f475eb2c000
mmap(NULL, 23, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb2b000
mmap(NULL, 59, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb2a000
mmap(NULL, 167, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb23000
mmap(NULL, 77, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb22000
mmap(NULL, 34, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb21000
mmap(NULL, 57, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb20000
mmap(NULL, 286, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb1f000
mmap(NULL, 2586930, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475d7f9000
mmap(NULL, 3316, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb1e000
mmap(NULL, 54, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eb1d000
mmap(NULL, 337024, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f475eaca000
bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
+++ exited with 0 +++
```

`-e trace=%memory`选项用于过滤出内存相关的系统调用。


### 12、跟踪访问指定路径的系统调用
```shell
# strace -P /dev/stdout -P /dev/fd/1  ls /
strace: Requested path '/dev/stdout' resolved into '/dev/pts/1'
strace: Requested path '/dev/fd/1' resolved into '/dev/pts/1'
ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
ioctl(1, TIOCGWINSZ, {ws_row=48, ws_col=204, ws_xpixel=2856, ws_ypixel=1632}) = 0
fstat(1, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x1), ...}) = 0
write(1, "bin  boot  dev\tetc  home  lib\tli"..., 100bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
) = 100
close(1)                                = 0
close(2)                                = 0
+++ exited with 0 +++
```

想要确定有哪些系统调用访问了某个或者某些文件路径，用`-P`选项就能达到过滤效果。示例中用`-P`选项指定了标准输出的两个文件路径，最终输出的内容中也的确如此。

### 13、跟踪子进程的系统调用
为演示创建子进程的系统调用，准备了以下C语言程序：

```C
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main() {
    printf("[%d]before fork\n", getpid());
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork error");
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        printf("Parent process: pid=%d ppid=%d\n", getpid(), getppid());
        sleep(1); // 为了保证父进程后退出
    } else if (pid == 0) {
        printf("Child process: pid=%d ppid=%d\n", getpid(), getppid());
    }
    printf("[%d]after fork\n", getpid());
    return EXIT_SUCCESS;
}
```

加上`-f`选项后，会跟踪子进程中的系统调用，形如`[pid 2600409] xxxxx`。

```shell
# # strace -f -e trace=clone,write,getpid ./a.out
getpid()                                = 2600408
write(1, "[2600408]before fork\n", 21[2600408]before fork
)  = 21
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f2cd60217d0) = 2600409
getpid()                                = 2600408
write(1, "Parent process: pid=2600408 ppid"..., 41Parent process: pid=2600408 ppid=2600405
) = 41
strace: Process 2600409 attached
[pid 2600409] getpid()                  = 2600409
[pid 2600409] write(1, "Child process: pid=2600409 ppid="..., 40Child process: pid=2600409 ppid=2600408
) = 40
[pid 2600409] getpid()                  = 2600409
[pid 2600409] write(1, "[2600409]after fork\n", 20[2600409]after fork
) = 20
[pid 2600409] +++ exited with 0 +++
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=2600409, si_uid=0, si_status=0, si_utime=0, si_stime=0} ---
getpid()                                = 2600408
write(1, "[2600408]after fork\n", 20[2600408]after fork
)   = 20
+++ exited with 0 +++
```


### 14、查看进程发起系统调用的时间戳
```shell
# strace -tt -e trace=socket,bind,connect ping -c 1 github.com
12:46:14.276448 socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP) = -1 EACCES (Permission denied)
12:46:14.276622 socket(AF_INET, SOCK_RAW, IPPROTO_ICMP) = 3
12:46:14.276678 socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6) = -1 EACCES (Permission denied)
12:46:14.276724 socket(AF_INET6, SOCK_RAW, IPPROTO_ICMPV6) = 4
12:46:14.276788 socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5
12:46:14.276824 connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
12:46:14.276878 socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5
12:46:14.276910 connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
12:46:14.277477 socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5
12:46:14.277567 connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0
12:46:14.279023 socket(AF_INET, SOCK_DGRAM, IPPROTO_IP) = 5
12:46:14.279089 connect(5, {sa_family=AF_INET, sin_port=htons(1025), sin_addr=inet_addr("10.23.253.91")}, 16) = 0
PING github.com (10.23.253.91) 56(84) bytes of data.
12:46:14.280138 socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5
12:46:14.280192 connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0
12:46:14.287007 socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5
12:46:14.287131 bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0
12:46:14.287324 socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5
12:46:14.287374 bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0
64 bytes from 10.23.253.91 (10.23.253.91): icmp_seq=1 ttl=63 time=0.725 ms

--- github.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.725/0.725/0.725/0.000 ms
12:46:14.288061 +++ exited with 0 +++
```

`-tt`选项可以显示每个系统调用的时间信息

### 15、查看进程系统调用的耗时
```shell
# strace -tt -T -e trace=socket,bind,connect ping -c 1 github.com
12:48:18.669272 socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP) = -1 EACCES (Permission denied) <0.000076>
12:48:18.669449 socket(AF_INET, SOCK_RAW, IPPROTO_ICMP) = 3 <0.000024>
12:48:18.669506 socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6) = -1 EACCES (Permission denied) <0.000023>
12:48:18.669564 socket(AF_INET6, SOCK_RAW, IPPROTO_ICMPV6) = 4 <0.000014>
12:48:18.669630 socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5 <0.000013>
12:48:18.669663 connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory) <0.000018>
12:48:18.669716 socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 5 <0.000011>
12:48:18.669745 connect(5, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory) <0.000012>
12:48:18.670314 socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5 <0.000029>
12:48:18.670377 connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0 <0.000019>
12:48:18.671929 socket(AF_INET, SOCK_DGRAM, IPPROTO_IP) = 5 <0.000035>
12:48:18.672017 connect(5, {sa_family=AF_INET, sin_port=htons(1025), sin_addr=inet_addr("10.23.253.91")}, 16) = 0 <0.000015>
PING github.com (10.23.253.91) 56(84) bytes of data.
12:48:18.673281 socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, IPPROTO_IP) = 5 <0.000034>
12:48:18.673357 connect(5, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.23.255.1")}, 16) = 0 <0.000015>
12:48:18.677557 socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5 <0.000031>
12:48:18.677648 bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0 <0.000012>
12:48:18.677810 socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK, NETLINK_ROUTE) = 5 <0.000013>
12:48:18.677855 bind(5, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 16) = 0 <0.000011>
64 bytes from 10.23.253.91 (10.23.253.91): icmp_seq=1 ttl=63 time=0.898 ms

--- github.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.898/0.898/0.898/0.000 ms
12:48:18.678538 +++ exited with 0 +++
```

加上`-T`选项后，每行系统调用信息的最右侧会标识出该系统调用的耗时，如`<0.000076>`。

### 16、查看进程系统调用中文件描述符所关联的文件名
细心的你是否发现示例`跟踪访问指定路径的系统调用`中倒数第二行输出的`close(2)`颇为奇怪，效果上应该仅显示有关标准输出的系统调用，为什么会显示`fd=2`的系统调用？下面我们增加一个选项`-y`或者`-yy`试试。

```shell
# strace -P /dev/stdout -P /dev/fd/1 -y ls /
strace: Requested path '/dev/stdout' resolved into '/dev/pts/1'
strace: Requested path '/dev/fd/1' resolved into '/dev/pts/1'
ioctl(1</dev/pts/1>, TCGETS, {B38400 opost isig icanon echo ...}) = 0
ioctl(1</dev/pts/1>, TIOCGWINSZ, {ws_row=48, ws_col=204, ws_xpixel=2856, ws_ypixel=1632}) = 0
fstat(1</dev/pts/1>, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x1), ...}) = 0
write(1</dev/pts/1>, "bin  boot  dev\tetc  home  lib\tli"..., 100bin  boot  dev	etc  home  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
) = 100
close(1</dev/pts/1>)                    = 0
close(2</dev/pts/1>)                    = 0
+++ exited with 0 +++
```

看到这个输出，是否就能明白为什么了呢？看来文件描述符`1`和`2`都指向了标准输出。

# 参考

- strace(1) — Linux manual page
- [strace 跟踪进程中的系统调用](https://linuxtools-rst.readthedocs.io/zh_CN/latest/tool/strace.html)


