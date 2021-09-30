---
title: "socket编程（二）：每个进程服务一个连接"
date: 2021-09-26T20:11:22+08:00
tags: ["socket","fork","waitpid","signal"]
categories: ["计算机网络"]
draft: true
---


> 原文链接：https://voidint.github.io/post/socket/one_process_per_connection/

![题图](https://voidint.github.io/socket/fork-exec-wait.png)

在前一篇文章中，我们实现了一个[仅能服务一个客户端连接的版本](https://voidint.github.io/post/socket/one_server_one_client/)。很明显，它的局限性非常大，仅能服务一个连接的程序在现实中几乎不可能存在。本篇中，我们将对其稍作改进，实现一个**用多个进程服务多个客户端连接的增强型版本**。

# 需求：每个进程服务一个连接
- 由一个专门的进程监听是否有新的客户端连接。
- 若有新的客户端连接，则由监听进程创建一个子进程来专门服务此连接。
- 客户端主动断开连接时，为该客户端连接服务的子进程自动退出。
- 监听进程为父进程，由其为子进程进行资源回收，避免子进程变为僵尸进程。

# 前置知识点
### 1、getpid、getppid
每个进程都会有一个非负整数表示的唯一进程ID，称为`pid`。

在任意时刻，进程ID在一个操作系统内都是全局唯一的，但是进程ID是允许复用的，进程退出后，原本被其占用的进程ID也将被回收再利用。大多数的 UNIX 操作系统使用了一种称之为**延迟重用**的算法，即新创建进程的进程ID不与最近退出进程的进程ID重复。这个意图很容易理解，为的就是防止将新创建的进程误以为是已退出的那个进程（毕竟它俩的进程ID是一样的）。

[getpid(2)](https://man7.org/linux/man-pages/man2/getpid.2.html) 系统调用用于获取当前进程ID，而[getppid(2)](https://man7.org/linux/man-pages/man2/getppid.2.html)用于获取当前进程的父进程ID。

函数原型如下：

```C
#include <sys/types.h>
#include <unistd.h>
pid_t getpid(void);
pid_t getppid(void);
```

#### 参数列表
无

#### 返回值
进程ID号

#### 错误
该系统调用总是成功

### 2、fork
[fork(2)](https://man7.org/linux/man-pages/man2/fork.2.html) 系统调用用于创建新的进程。具体说，是以当前进程为模板复刻了一个新的进程。当前进程称为**父进程**，而把新进程称为**子进程**。

fork 系统调用比较特别，**父子进程分别返回一次**，都是从 fork 返回处继续执行。通常，我们会依据返回值判断当前是父进程还是子进程。返回值大于0，表示父进程返回；返回值等于0，表示子进程返回；返回值等于-1，则意味着 fork 调用失败了。这样设计的意图也不难理解。子进程可以随时随地调用 getpid 与 getppid 获得自身进程ID、父进程ID，因此无需以 fork 返回值的方式传递子进程ID这个信息，否则就是多此一举。反过来，如果不通过 fork 返回值的方式告诉父进程刚刚创建的子进程ID，那么父进程将无法获知刚才创建的子进程ID。


函数原型如下：
```C
#include <sys/types.h>
#include <unistd.h>
pid_t fork(void);
```

#### 参数列表
无

#### 返回值
- `>0`：表示是父进程返回，且返回值就是新创建的子进程ID。
- `0`：表示是子进程返回。
- `-1`：表示调用失败且设置了 errno 值。

#### 错误
- `EAGAIN`: 进程数量已超过当前用户所能创建的进程数上限，或者是进程数量已超过系统设定的全局进程数量上限。
- `ENOMEM`：内存不足

### 3、waitpid
进程有生必有死，进程生命周期完结退出后，内核会释放其绝大部分资源，以便供其他进程重新使用。**但进程ID、终止状态、资源使用数据等信息并未直接释放**，这部分资源需要进程的父进程调用 [waitpid(2)](https://man7.org/linux/man-pages/man2/waitpid.2.html) 系统调用来回收。若父进程未回收子进程的这部分资源，那么子进程将变成僵尸进程。

那僵尸进程危害大吗？由于僵尸进程已经不是一个真正的进程，仅仅是内核中残留的一个数据结构，它无法也不会对信号进行处理，因此`kill -9`对它也毫无作用。而系统的进程数是有上限的，大量的僵尸进程就会导致这部分资源的紧张，很可能无法再创建进程。

那如何将其消灭？如果僵尸进程已经产生，那么消灭它的最好方法就是杀死其父进程，让1号进程成为其父进程，1号进程会尽职尽责地调用 wait 释放其剩余的资源。如果是为了预防僵尸进程的产生，那么只要保证父进程能及时调用 wait、waitpid、waitid 就行了。

既然僵尸进程有不少危害，那为什么要设计僵尸进程这种机制？子进程退出后直接回收释放所有资源不香吗？为什么非得让父进程 wait 一次？实际上，子进程退出后未释放的资源是给父进程提供一些重要信息用的，比如进程为何退出，是收到信号退出还是正常退出，进程退出码是多少，进程一共消耗了多少系统CPU时间，多少用户 CPU 时间，收到了多少信号，发生了多少次上下文切换，最大内存驻留集是多少，产生多少缺页中断等等。


函数原型如下：
```C
#include <sys/types.h>
#include <sys/wait.h>
pid_t waitpid(pid_t pid, int *status, int options);
```

#### 参数列表
- `pid`：表示需要等待的具体子进程
  
| pid  | 描述                                                 |
| ---- | ---------------------------------------------------- |
| >0   | 表示等待进程ID为pid的子进程                          |
| 0    | 表示等待与调用进程（父进程）同一个进程组的所有子进程 |
| -1   | 表示等待任意子进程                                   |
| <-1  | 等待进程组标识符与pid绝对值相等相等的所有子进程      |

- `status`：获取目标进程状态改变信息的指针。若父进程并不关心子进程的状态改变，可设置为 NULL。若未设置为 NULL，则该系统调用返回后可通过以下的宏来获取进程的状态改变信息。

| 宏                   | 描述                                                         |
| -------------------- | ------------------------------------------------------------ |
| WIFEXITED(status)    | 若子进程通过调用exit(3)或者_exit(2)等方式终止了进程，则返回true，否则为false。通过宏 **WEXITSTATUS(status)** 获得具体的进程退出码。 |
| WIFSIGNALED(status)  | 若子进程是接收到了某个信号而终止了进程，则返回true，否则返回false。通过宏 **WTERMSIG(status)** 获得具体的信号值。通过宏 **WCOREDUMP(status)** 获得是否已经产生内核转储文件的布尔值。 |
| WIFSTOPPED(status)   | 在设置了 **WUNTRACED** 标志位的前提下，若子进程并未终止，但是其状态变成了**停止**（还有机会继续运行），则返回true，否则返回false。通过宏 **WSTOPSIG(status)** 获得导致进程停止的具体信号值。 |
| WIFCONTINUED(status) | 在设置了 **WCONTINUED** 标志位的前提下，若处于停止状态的子进程接收到 SIGCONT 信号，则返回true，否则返回false。**Linux 2.6.10及以上版本有效。** |

- `options`：是一个位掩码，可以包含（按位或操作）0个或者多个如下的标志。

| 标志       | 描述                                                         |
| ---------- | ------------------------------------------------------------ |
| 0          | 阻塞，直到子进程有状态发生改变后才返回。                     |
| WNOHANG    | 不阻塞，若子进程未发生任何状态改变，则立刻返回（返回值为0）。  |
| WUNTRACED  | 设置该标识位后，子进程因收到SIGTTIN、SIGTTOU、SIGTSTP、SIGSTOP等信号后状态变为**停止**，该系统调用将立刻返回。 |
| WCONTINUED | 设置该标识位后，子进程收到 SIGCONT 信号后状态从停止变成运行，该系统调用将立刻返回。**Linux 2.6.10及以上版本有效。** |



#### 返回值
- `>0`：发生了状态改变的子进程ID。
- `0`：当且仅当设置了 WNOHANG 标志且当前并无任何发生进程状态变化的子进程时返回该值。
- `-1`：发生了某个错误并设置 errno 值。

### 错误
- `ECHILD`：子进程不存在。
- `EINTR`: 未设置 WNOHANG 标志位情况下，被信号所中断。
- `EINVAL`: options 标志位设置错误。

### 4、signal
信号本质上是一种进程间通信方式。如上文所述，父进程在调用 fork 系统调用创建子进程后，需要 waitpid 回收子进程资源。子进程在退出时，内核会向其父进程发送 SIGCHLD 信号。若父进程事先注册了 SIGCHLD 信号的处理函数（在该函数内调用 waitpid），那么内核就会调用该信号处理函数，也就可以完成对子进程资源的回收了。C标准库提供了 [signal(3)](https://man7.org/linux/man-pages/man3/signal.3p.html) 函数，用于注册信号处理函数。

实际上，UNIX/Linux系统同时提供了 signal 和 [sigaction(2)](https://man7.org/linux/man-pages/man2/sigaction.2.html)两个函数。signal 使用更加简单，但是它的行为在不同的 UNIX 系统之间存在差异，而且功能也远不及 sigaction 丰富，因此普遍更推荐后者。只是由于信号相关内容太多，不宜在本篇中过分展开，因此本篇中使用功能简单的 signal 函数来完成 SIGCHLD 信号对应处理函数的注册。

函数原型如下：
```C
#include <signal.h>
void (*signal(int sig, void (*func)(int)))(int);
// 或者
typedef void (*sig_t) (int);
sig_t signal(int sig, sig_t func);
```

#### 参数列表
- `sig`：信号（通过`kill -l`查看系统支持的信号种类）。
- `func`：有一个 int 类型入参且无返回值的函数指针。
#### 返回值
成功返回前一个注册的信号处理动作，失败返回 SIG_ERR 并设置 errno 值。
### 错误
- `EINVAL`: 信号错误，或者尝试捕获一个不能捕获的信号，亦或者尝试忽略一个不能忽略的信号。

# 示例
```C
// server.c

#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

void handle_sigchld(int signo) {
    pid_t wpid = 0;
    int status = 0;
    int options = WNOHANG | WUNTRACED;

#ifdef WCONTINUED // Linux 2.6.10及以上版本
    options |= WCONTINUED;
#endif

    for (;;) {
        wpid = waitpid(-1, &status, options);
        if (wpid == 0) {
            continue;
        }
        if (wpid == -1) {
            if (errno == EINTR) { // 系统调用被信号中断，重新调用一次。
                continue;
            }
            if (errno != ECHILD) { // ECHILD表示已无子进程，这属于'正常'情况。
                perror("waitpid error");
            }
            break;
        }
        if (WIFEXITED(status)) {
            printf("[%d]子进程%d主动调用exit或者_exit退出（退出码为%d）\n", getpid(), wpid, WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            printf("[%d]子进程%d接收到信号后退出（信号为%d）%s产生内核转储文件\n", getpid(), wpid, WTERMSIG(status), WCOREDUMP(status) ? "且已" : "但未");
        } else if (WIFSTOPPED(status)) {
            printf("[%d]子进程%d接收到信号后停止（信号为%d）\n", getpid(), wpid, WSTOPSIG(status));
        }
#ifdef WIFCONTINUED // Linux 2.6.10及以上版本
        else if (WIFCONTINUED(status)) {
            printf("[%d]子进程%d接收到 SIGCONT 信号后继续\n", getpid(), wpid);
        }
#endif
    }
}

// 父进程负责监听客户端连接，每个连接都通过fork一个子进程的方式进行服务。
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s port\n", argv[0]);
        return EXIT_FAILURE;
    }

    int port = atoi(argv[1]);

    int lfd = socket(AF_INET, SOCK_STREAM, 0); // 监听文件描述符
    if (lfd == -1) {
        perror("socket error");
        return EXIT_FAILURE;
    }

    int reuseaddr = 1;
    setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &reuseaddr, sizeof(reuseaddr)); // 支持重复绑定

    struct sockaddr_in addr;
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    int ret = 0;
    if ((bind(lfd, (struct sockaddr *)&addr, sizeof(addr))) == -1) {
        perror("bind error");
        return EXIT_FAILURE;
    }

    if ((ret = listen(lfd, 128)) == -1) {
        perror("listen error");
        return EXIT_FAILURE;
    }

    printf("[%d]The server is running at %s:%d\n", getpid(), inet_ntoa(addr.sin_addr), port);

    signal(SIGCHLD, SIG_IGN); // 注册SIGCHLD信号回收子进程资源

    int cfd; // 连接文件描述符
    pid_t pid;
    for (;;) {
        cfd = accept(lfd, NULL, NULL);
        if (cfd == -1) {
            if (errno == EINTR) { // 注意：被信号所中断，这类错误不是真的"错误"。
                continue;
            }
            perror("accept error");
            return EXIT_FAILURE;
        }

        pid = fork();
        if (pid < 0) {
            perror("fork error");
            return EXIT_FAILURE;
        }
        if (pid > 0) {
            // 父进程
            close(cfd); // 父进程中用不到cfd，关闭（cfd的引用计数减一）。
        } else if (pid == 0) {
            // 子进程
            close(lfd); // 子进程中用不到lfd，关闭（lfd的引用计数减一）。

            // 循环读取客户端连接文件描述符将读取的内容转换成大写后返回给客户端
            printf("[%d]Start servicing connection %d\n", getpid(), cfd);
            char buf[32];
            ssize_t size = 0;
            for (;;) {
                memset(buf, 0x00, sizeof(buf));
                size = read(cfd, buf, sizeof(buf));
                if (size < 0) {
                    close(cfd); // cfd的引用计数减一
                    perror("read error");
                    _exit(EXIT_FAILURE); // 直接退出当前进程，避免子进程再次创建子进程。
                }
                if (size == 0) { // 客户端关闭连接（EOF）
                    close(cfd);  // cfd的引用计数减一
                    printf("[%d]Connection %d is closed\n", getpid(), cfd);
                    _exit(EXIT_SUCCESS); // 直接退出当前进程，避免子进程再次创建子进程。
                }
                printf("[%d]Read: %s", getpid(), buf);

                for (int i = 0; i < size; i++) {
                    buf[i] = toupper(buf[i]);
                }
                write(cfd, buf, strlen(buf));
                printf("[%d]Write: %s", getpid(), buf);
            }
        }
    }

    close(lfd); // lfd的引用计数减一
    printf("[%d]The server is shut down\n", getpid());
    return EXIT_SUCCESS;
}
```

### 验证步骤
- 终端1：启动服务

    ```shell
    $ gcc ./server.c -o a.out
    $ ./a.out 8989
    [36567]The server is running at 0.0.0.0:8989
    ```

- 终端2：通过 nc 或者 telnet 尝试连接服务端
    ```shell
    $ nc 127.0.0.1 8989
    hello # 输入
    HELLO # 服务端将字符串转成大写后返回
    world # 输入
    WORLD # 服务端将字符串转成大写后返回
    ```

- 查看终端1的服务端输出

    ```shell
    $ ./a.out 8989
    [36567]The server is running at 0.0.0.0:8989 # 父进程ID为36567
    [36620]Start servicing connection 4          # 子进程ID为36620
    [36620]Read: hello 
    [36620]Write: HELLO 
    [36620]Read: world
    [36620]Write: WORLD
    ```

- 终端3：向子进程36620依次发送SIGSTOP、SIGCONT、SIGTERM信号

    ```shell
    $ kill -SIGSTOP 36620
    $ kill -SIGCONT 36620
    $ kill -SIGTERM 36620
    ```

- 再次查看终端1的服务端输出

    ```shell
    $ ./a.out 8989
    [36567]The server is running at 0.0.0.0:8989
    [36620]Start servicing connection 4
    [36620]Read: hello 
    [36620]Write: HELLO 
    [36620]Read: world
    [36620]Write: WORLD
    [36567]子进程36620接收到信号后停止（信号为17）                  # 子进程接收到SIGSTOP信号导致进程停止
    [36567]子进程36620接收到 SIGCONT 信号后继续                   # 子进程接收到SIGCONT信号导致进程重新运行
    [36567]子进程36620接收到信号后退出（信号为15）但未产生内核转储文件 # 子进程接收到SIGTERM信号导致进程正常退出
    ```

- 终端4：通过 nc 连接服务端并在输入字符串后按下`Ctrl+c`

    ```shell
    $ nc 127.0.0.1 8989
    voidint
    VOIDINT
    ^C
    ```

- 再次查看终端1的服务端输出

    ```shell
    $ ./a.out 8989
    [36567]The server is running at 0.0.0.0:8989
    [36620]Start servicing connection 4
    [36620]Read: hello 
    [36620]Write: HELLO 
    [36620]Read: world
    [36620]Write: WORLD
    [36567]子进程36620接收到信号后停止（信号为17）
    [36567]子进程36620接收到 SIGCONT 信号后继续
    [36567]子进程36620接收到信号后退出（信号为15）但未产生内核转储文件
    [37110]Start servicing connection 4                # 新创建的进程37110来服务新的连接
    [37110]Read: voidint
    [37110]Write: VOIDINT
    [37110]Connection 4 is closed                      # 探测到客户端连接已主动关闭
    [36567]子进程37110主动调用exit或者_exit退出（退出码为0） # 客户端连接主动关闭后为此服务的进程也退出
    ```

# 参考
- 《UNIX环境高级编程》
- 《Linux/UNIX系统编程手册》
- 《Linux环境编程：从应用到内核》
- 传智播客Linux网络编程课程
- [Linux man pages](https://man7.org/linux/man-pages/)