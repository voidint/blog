---
title: "socket编程（一）：一个服务器服务一个客户端"
date: 2021-09-21T10:07:50+08:00
tags: ["socket","bind","listen","accept","connect"]
categories: ["计算机网络"]
draft: true
---

![题图](https://voidint.github.io/socket/socket_api.png)

在这个信息爆炸的时代，有关socket编程的文章多如牛毛，而且还在不断产出，隔三差五就能在各种微信公众号之类的地方看到。我也打算写一个有关 socket 编程的系列文章，不是因为我膨胀到觉得比别人写得好，而是为了加深对这部分知识的印象，查漏补缺（下笔之前总会多查些资料，以免写出来贻笑大方是不是），同时也是为了练习书面表达能力。鉴于本人有限的知识水平和写作水平，错误也在所难免，还望指正。

这个系列的文章主要围绕 Unix/Linux 下的 socket 网络编程，不涉及 Windows （我也不懂）。在形式上，会围绕如何实现一个具体的需求（demo），分析其中需要用到哪些知识点并给出一个可运行的代码实现。虽然 socket 网络编程并不限定于哪种具体的编程语言，可谁让操作系统内核都是C语言实现的呢，所以选用C语言来描述绝对是正确的做法。但是大概率上也不会涉及内核的具体代码实现（因为我不懂），只会涉及到一些基本的函数和系统调用。


# 需求：一个服务器服务一个客户端
具体归纳为以下几条：
- 启动一个进程并在某个端口上监听TCP连接请求。
- 读取客户端请求数据，并将读取到的数据转换成大写后返回给客户端。
- 服务端仅能同时服务一个客户端，期间若有其它客户端尝试连接，则阻塞。


# socket核心API介绍
### 1、socket
由于类 Unix 系统中**一切皆文件**的宗旨，socket 编程需要基于一个文件描述符，即 socket 文件描述符。[socket(2)](https://man7.org/linux/man-pages/man2/socket.2.html) 系统调用就是用来创建 socket 文件描述符。

函数原型如下：

```C
#include <sys/types.h>
#include <sys/socket.h>
int socket(int domain, int type, int protocol);
```

#### 参数列表
- `domain`: 协议族/协议域

| domain           | 描述       |
| ---------------- | ---------- |
| AF_UNIX, AF_LOCAL | Unix域协议 |
| AF_INET          | IPv4协议   |
| AF_INET6         | IPv6协议   |

- `type`: 套接字类型

| type           | 描述           |
| -------------- | -------------- |
| SOCK_STREAM    | 字节流套接字   |
| SOCK_DGRAM     | 数据包套接字   |
| SOCK_SEQPACKET | 有序分组套接字 |
| SOCK_RAW       | 原始套接字     |

- `protocol`: 一般设置为`0`，表示系统会根据 domain 和 type 的值自动选择一个合适的值。

#### 返回值
发生错误返回-1，否则返回socket文件描述符。



### 2、bind 
通过 socket 系统调用创建的文件描述符并不能直接使用，TCP/UDP协议中所涉及的**协议**、**IP**、**端口**等基本要素并未体现，而 [bind(2)](https://man7.org/linux/man-pages/man2/bind.2.html) 系统调用就是将这些要素与文件描述符关联起来。

函数原型如下：

```C
#include <sys/socket.h>
int bind(int socket, const struct sockaddr *address, socklen_t address_len);
```

#### 参数列表
- `socket`: socket 文件描述符。
- `address`: 特定协议的地址结构体指针。

    通常，在实际的编程中并不会直接使用结构体`struct sockaddr`，而是使用对编程更加友好的的`struct sockaddr_in`或者`struct sockaddr_in6`，它为**协议**、**IP**、**端口**等要素分别定义了字段。
- `address_len`: 协议地址结构体长度。

#### 返回值
- `0`: 成功
- `-1`: 失败并设置errno值

#### 错误
- `EADDRINUSE`: 地址重复绑定（正在使用中）错误。

    对于TCP协议而言，首先发起连接关闭的一方会有一段时间处于`TIME_WAIT`状态，而恰巧进程重启依然尝试 bind 相同的地址，那么就会发生 EADDRINUSE 错误。一般的解决方案是地址重用，为 socket 文件描述符设置`SO_REUSEADDR`选项。关于此选项，先按下不表。



### 3、listen
使用 socket 系统调用创建一个套接字时，它被假设是一个主动套接字（客户端套接字），而调用 [listen(2)](https://man7.org/linux/man-pages/man2/listen.2.html) 系统调用就是将这个主动套接字转换成被动套接字，指示内核应接受指向该套接字的连接请求。

listen 还有项重要使命，就是创建**SYN QUEUE**和**ACCEPT QUEUE**，中文译为**未完成连接队列（半连接队列）**和**已完成连接队列（全连接队列）**。内核为每一个监听套接字都维护着这两个队列，未完成三次握手的连接暂时存放在未完成队列，已完成三次握手并且服务端还未调用 accept 系统调用处理的连接均存放在已完成连接队列。

函数原型如下：

```C
#include <sys/socket.h>
int listen(int socket, int backlog);
```

#### 参数列表
- `socket`: socket 监听文件描述符。
- `backlog`: 设置未完成连接队列和已完成连接队列各自的队列长度（注意：不同的系统对该值的解释会存在差异）。

    Linux系统下，SYN QUEUE 队列长度阈值存放在`/proc/sys/net/ipv4/tcp_max_syn_backlog`文件中，ACCEPT QUEUE 队列长度阈值存放在`/proc/sys/net/core/somaxconn`文件中。两个队列长度的计算公式如下：
    - SYN QUEUE 队列的长度：**min(backlog, somaxconn, tcp_max_syn_backlog) + 1 再上取整到 2 的幂次但（最小不能小于16）**
    - ACCEPT QUEUE 队列长度：**min(backlog, somaxconn)**

    对于存在高并发场景的服务端程序，应该将 backlog 适当调大（Nginx和Redis的默认backlog值为511）。

#### 返回值
- `0`: 成功
- `-1`: 失败并设置errno值


### 4、accept
[accept(2)](https://man7.org/linux/man-pages/man2/accept.2.html) 系统调用将尝试从**已完成连接队列**的队头中取出一个连接进行服务，因此产生的队列空缺将从**未完成连接队列**中取出一个进行补充。若此时已完成连接队列为空，且 socket 文件描述符为默认的阻塞模式，那么进程将被挂起。

函数原型如下：

```C
#include <sys/types.h>
#include <sys/socket.h>
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
```

#### 参数列表
- `socket`: socket 监听文件描述符。
- `addr`: 已连接的对端进程的协议地址。

    若不关注对端信息，可设置为NULL。与 bind 系统调用的参数类似，在实际编程中会使用对编程更加友好的的`struct sockaddr_in`或者`struct sockaddr_in6`的指针作为入参。
- `addrlen`: 地址结构体长度的指针。addr 参数设置为 NULL 时，可设置为 NULL 。

#### 返回值
出错返回-1，否则返回已连接套接字文件描述符。

#### 错误
- `EAGAIN/EWOULDBLOCK`: 若**已连接队列为空**且监听文件描述符被设置为**非阻塞模式**，那么 errno 将被设置为`EAGAIN`或者`EWOULDBLOCK`。
- `EINTR`: 若被信号（如`SIGCHLD`）中断，那么 errno 将被设置为`EINTR`。


### 5、connect
创建主动套接字的一方（客户端）调用 [connect(2)](https://man7.org/linux/man-pages/man2/connect.2.html) 系统调用，可建立与被动套接字的一方（服务端）的连接。

不同于被动套接字方在调用 listen 之前必须调用 bind 绑定文件描述符与协议地址，主动套接字方在发起连接前，一般都不会调用 bind 绑定文件描述符和协议地址。因为在未绑定情况下，内核会确定源IP地址，并选择一个临时的未被占用的端口作为源端口。如果进行了绑定，所指定的端口又已经被占用，那么 connect 将返回 EADDRINUSE 错误。

函数原型如下：

```C
#include <sys/types.h>
#include <sys/socket.h>
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
```


#### 参数列表
- `sockfd`: 连接文件描述符。
- `addr`: 特定协议的地址结构体指针。同 bind 系统调用参数。
- `addrlen`: 协议地址结构体长度。同 bind 系统调用参数。

#### 返回值
成功返回0，失败返回-1并设置 errno 值。

#### 错误
- `EADDRINUSE`: 若客户端的连接文件描述符被设置了地址重用选项（SO_REUSEADDR），又调用了 bind 绑定了固定端口，那么重复连接都将返回此错误。一般而言，客户端端口并不会人为指定，而是由内核选择一个未被占用的端口进行连接。
- `ECONNREFUSED`: 若客户端的SYN的响应是RST，则表明指定的地址（IP+端口）上并没有进程在等待连接。
- `ETIMEDOUT`: 若客户端在重试了多次后依然没有收到SYN的响应，那么返回该错误。


### 6、close
[close(2)](https://man7.org/linux/man-pages/man2/close.2.html) 一个TCP套接字的默认行为是把该套接字**标记为关闭**，此后不能再对该文件描述符进行读写操作。TCP协议将尝试发送已排队等待发送到对端的任何数据，发送完毕后发生的是正常的TCP连接终止序列。

close 会对文件描述符进行引用计数减一操作，引用计数不为零，则文件描述符不会真正关闭。若父进程在使用 [fork(2)](https://man7.org/linux/man-pages/man2/fork.2.html) 系统调用前打开了某个文件，那么该文件描述符的引用计数就是2，子进程和父进程在退出前都必须各自调用一次 close 以真正关闭该文件。

函数原型如下：
```C
#include <unistd.h>
int close(int fd);
```

#### 参数列表
- `fd`: 待关闭的文件描述符。

#### 返回值
成功返回0，失败返回-1并设置 errno 值。

#### 错误
- `EINTR`: 若被信号（如`SIGCHLD`）中断，那么 errno 将被设置为`EINTR`。



# 代码实现
### 服务端
```C
// server.c

#include <arpa/inet.h>
#include <ctype.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s port\n", argv[0]);
        return EXIT_FAILURE;
    }
    int port = atoi(argv[1]);

    // 1、创建监听用的文件描述符
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lfd == -1) {
        perror("socket error");
        return EXIT_FAILURE;
    }

    // 2、将监听文件描述符和IP端口信息绑定
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY); // 表示任意可用IP
    addr.sin_port = htons(port);              // 转换成网络字节序（大端字节序）

    int ret = bind(lfd, (struct sockaddr *)&addr, sizeof(addr));
    if (ret == -1) {
        perror("bind error");
        return EXIT_FAILURE;
    }

    // 3、监听文件描述符
    if ((ret = listen(lfd, 128)) == -1) {
        perror("listen error");
        return EXIT_FAILURE;
    }

    printf("[%d]The server is running at %s:%d\n", getpid(), inet_ntoa(addr.sin_addr), port);

    // 4、接受一个socket连接（从已连接队列中获取一个连接进行服务），并返回连接文件描述符。
    struct sockaddr_in clientAddr;                // 输入参数
    socklen_t clientAddrLen = sizeof(clientAddr); // 同时作为输入和输出参数
    int cfd = accept(lfd, (struct sockaddr *)&clientAddr, &clientAddrLen);
    if (cfd == -1) {
        perror("accept error");
        return EXIT_FAILURE;
    }
    char clientIP[16];
    memset(clientIP, 0x00, sizeof(clientIP));
    inet_ntop(AF_INET, &clientAddr.sin_addr, clientIP, sizeof(clientIP)); // 将网络字节序的整数IP转换成主机字节序的点分十进制字符串
    int clientPort = ntohs(clientAddr.sin_port);                          // 将网络字节序转换成主机字节序
    printf("Accept client: %s:%d\n", clientIP, clientPort);

    // 5、读写连接
    char buf[BUFSIZ];
    ssize_t size;
    for (;;) {
        // 初始化buffer
        memset(buf, 0x00, sizeof(buf));
        // 读取客户端信息
        size = read(cfd, buf, sizeof(buf));
        if (size == 0) { // zero indicates end of file
            printf("The client is closed\n");
            break;
        }
        if (size == -1) {
            perror("read error");
            continue;
        }
        printf("read: %s\n", buf);

        for (int i = 0; i < strlen(buf); i++) {
            buf[i] = toupper(buf[i]);
        }

        // 发送信息给客户端
        size = write(cfd, buf, strlen(buf));
        if (size == -1) {
            perror("write error");
            continue;
        }
        printf("write: %s\n", buf);
    }

    close(lfd);
    close(cfd);

    printf("The server is shut down\n");
    return EXIT_SUCCESS;
}
```

### 客户端
```C
// client.c

#include <arpa/inet.h>
#include <ctype.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s host port\n", argv[0]);
        return EXIT_FAILURE;
    }
    char *host = argv[1];
    int port = atoi(argv[2]);

    int cfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (cfd == -1) {
        perror("socket error");
        return EXIT_FAILURE;
    }

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr(host); // 方式一
    // inet_pton(AF_INET, host, &addr.sin_addr.s_addr); // 方式二
    addr.sin_port = htons(port);

    int ret = connect(cfd, (struct sockaddr *)&addr, sizeof(addr));
    if (ret == -1) {
        perror("connect error");
        return EXIT_FAILURE;
    }

    printf("The remote server is connected -> %s:%d\n", host, port);

    char buf[BUFSIZ];
    ssize_t size;
    for (int i = 0; i < 10; i++) {
        printf("Please enter content:\n");
        memset(buf, 0x00, sizeof(buf));
        if ((size = read(STDIN_FILENO, buf, sizeof(buf))) <= 0) {
            continue;
        }

        if ((size = write(cfd, buf, strlen(buf))) == -1) { // 往内核的发送缓冲区中写入数据（由内核决定何时发送数据）
            perror("write error");
            break;
        }

        memset(buf, 0x00, sizeof(buf));
        size = read(cfd, buf, sizeof(buf));
        if (size == -1) {
            perror("read error");
            break;
        }
        if (size == 0) { // zero indicates end of file
            printf("The server is shut down\n");
            break;
        }
        printf("Reply: %s\n", buf);
    }
    close(cfd);
    printf("The client is closed\n");
    return EXIT_SUCCESS;
}
```

### 编译
```shell
$ gcc server.c -o server
$ gcc client.c -o client
```

### 运行
- 终端1中运行server
```shell
$ ./server 8989
[3243777]The server is running at 0.0.0.0:8989
Accept client: 127.0.0.1:56588
read: hello world

write: HELLO WORLD

The client is closed
The server is shut down
```

- 终端2中运行client
```shell
$ ./client 127.0.0.1 8989
The remote server is connected -> 127.0.0.1:8989
Please enter content:
hello world
Reply: HELLO WORLD

Please enter content:
^C
```


# 参考
- UNIX网络编程 卷1：套接字联网API
- 传智播客Linux网络编程课程
- [Linux man pages](https://man7.org/linux/man-pages/)
- [为什么服务端程序都需要先 listen 一下？](https://mp.weixin.qq.com/s/hv2tmtVpxhVxr6X-RNWBsQ)

