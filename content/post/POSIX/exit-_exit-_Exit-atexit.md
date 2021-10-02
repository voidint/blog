---
title: "UNIX/Linux下的exit系列函数"
date: 2021-09-26T10:30:58+08:00
tags: ["exit","_exit","_Exit","exit_group","atexit","on_exit"]
categories: ["UNIX/Linux"]
draft: true
---

![题图](https://voidint.github.io/posix/exit.png)

使用C/C++语言在UNIX或者Linux系统下编程，应该都会遇到很多的进程退出相关的函数。有些是C标准库提供的函数，有些是系统调用，有些又是某个系统所独有的系统调用或者函数，并且命名上也极为类似，给人眼花缭乱的感觉。

这篇文章尝试去总结下其中常见的那几个系统调用和函数，并通过一个例子来展示下基本用法。

# 进程退出系列系统调用/函数
### 1、_exit
[_exit(2)](https://man7.org/linux/man-pages/man2/_exit.2.html) 属于 POSIX 系统调用，适用于 UNIX 和 Linux 系统。调用该系统调用后会导致当前进程**直接退出**，且函数不会返回。内核会关闭该进程打开的文件描述符，若还存在子进程，则交由1号进程领养，再向进程的父进程发送 SIGCHLD 信号。

函数原型如下：

```C
#include <unistd.h>
noreturn void _exit(int status);
```

#### 参数列表
- `status`: 进程退出码

#### 返回值
无返回值

### 2、exit_group
[exit_group(2)](https://man7.org/linux/man-pages/man2/exit_group.2.html) 是 **Linux 系统所独有的系统调用**，调用后会使得进程的所有线程都退出。从 glibc 2.3 开始，_exit 实际上是对 exit_group 系统调用的包装。因此，在Linux系统上两者是等价的。

函数原型如下：

```C
#include <linux/unistd.h>
void exit_group(int status);
```

#### 参数列表
- `status`: 进程退出码

#### 返回值
无返回值


### 3、_Exit
[_Exit(3)](https://man7.org/linux/man-pages/man3/_Exit.3p.html) 是C标准库函数，功能上等价于 _exit 系统调用，由 C99 引入。由于是标准库提供的函数，在跨平台移植性上比 _exit 好，建议优先使用。

函数原型如下：
```C
#include <stdlib.h>
void _Exit(int status);
```

#### 参数列表
- `status`: 进程退出码

#### 返回值
无返回值 


### 4、exit
[exit(3)](https://man7.org/linux/man-pages/man3/exit.3.html) 是C标准库函数，也是最常用的进程退出函数。它区别于 _exit、_Exit 的地方在于，除了使进程退出（也是通过调用 _exit 系统调用实现的）这个核心功能外，它还会执行一些**前置动作**：
- 逐个执行用户注册的自定义清理函数（通过 atexit 或者 on_exit 函数注册）
- 刷新标准I/O流缓冲区并关闭
- 删除由标准库函数 tmpfile 创建的临时文件

函数原型如下：
```C
#include <stdlib.h>
noreturn void exit(int status);
```

#### 参数列表
- `status`: 进程退出码

#### 返回值
无返回值



### 5、atexit
[atexit(3)](https://man7.org/linux/man-pages/man3/atexit.3.html) 是C标准库函数，用于注册进程退出清理函数。该函数在使用时有以下几个注意点：
- 清理函数的执行顺序与注册顺序相反。
- 当进程收到致命信号时，注册的清理函数不会被执行。
- 当进程调用 _exit（或者 _Exit）时，注册的清理函数不会被执行。
- 当执行到某个清理函数时，若收到致命信号或者清理函数内调用了 _exit（或者 _Exit），那么该清理函数不会返回并且后续的其它清理函数也会被丢弃。
- 当同一个清理函数被注册多次，那么正常情况下该清理函数也会被执行相应的次数。
- 父进程在调用 fork 前注册了清理函数，那么这些清理函数也会被子进程所继承；若子进程后续又调用了 exec 系列函数，那么子进程所继承的清理函数则会被移除。
- 单个进程能够注册的清理函数的数量不会少于32个。

函数原型如下：
```C
#include <stdlib.h>
int atexit(void (*function)(void));
```

#### 参数列表
- `function`: 用户自定义的进程退出清理函数。

#### 返回值
成功返回0，非0值则表示失败。



### 6、on_exit
功能上与 atexit 函数类似的，还有[on_exit(3)](https://man7.org/linux/man-pages/man3/on_exit.3.html)函数。它是 **Linux 系统下所独有的函数**，用于注册进程退出清理函数，区别于 atexit 函数的是，它支持了额外的入参。

函数原型如下：
```C
#include <stdlib.h>
int on_exit(void (*function)(int, void *), void *arg);
```

#### 参数列表
- `function`: 用户自定义的进程退出清理函数。
- `arg`: `void *`类型的自定义参数。

#### 返回值
成功返回0，非0值则表示失败。

# 示例

```C
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void cleanup1() {
    fprintf(stderr, "[1]cleanup\n");
    sleep(1);
}
void cleanup2() {
    fprintf(stderr, "[2]cleanup\n");
    sleep(1);
}
void cleanup3(int status, void *arg) {
    fprintf(stderr, "[3]cleanup: %s\n", (char *)arg);
    sleep(1);
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s exit|_exit|_Exit|return\n", argv[0]);
        return EXIT_FAILURE;
    }

    // atexit注册自定义清理函数
    atexit(cleanup1);
    atexit(cleanup2);
    atexit(cleanup2); // 多次注册同一个函数

    // 非标准函数on_exit，仅Linux下有效
    // on_exit(cleanup3, (void *)"bye!!!");
    // on_exit(cleanup3, (void *)"bye!!!"); // 多次注册同一个函数

    fprintf(stdout, "a newline!\n"); // 向stdout写入带换行符的字符串（行缓冲，遇到换行符的情况下就会调用write系统调用输出内容）
    fprintf(stderr, "[stderr]a newline!"); // 向stderr写入不带换行符的字符串（stderr默认情况下无缓冲，直接调用write系统调用）
    fprintf(stdout, "[stdout]forgot a newline!"); // 向stdout写入不带换行符的字符串（若不刷新缓冲区，则该行内容不会被输出）

    if (strcmp("exit", argv[1]) == 0) {
        // 作用：执行一些前置的清理操作并终止当前进程
        // 标准库函数（C89）
        // #include <stdlib.h>
        // 调用exit函数会执行以下操作：
        // 1、调用用户注册的清理函数
        // 2、刷新缓冲区并关闭所有标准IO流
        // 3、删除临时文件
        // 4、调用_exit系统调用
        exit(0);
    } else if (strcmp("_Exit", argv[1]) == 0) {
        // 作用：直接终止当前进程（含进程的所有线程）
        // 标准库函数（C99）
        // #include <stdlib.h>
        // 效果等同于_exit，但移植性更好。
        _Exit(0);
    } else if (strcmp("_exit", argv[1]) == 0) {
        // 作用：直接终止当前进程（含进程的所有线程）
        // 是对exit_group系统调用的包装（可退出所有线程）
        // #include <unistd.h>
        _exit(0);
    }
    return EXIT_SUCCESS; // main函数return会调用exit函数
}
```

# 参考
- [Linux man pages](https://man7.org/linux/man-pages/)
- [C Library](http://www.cplusplus.com/reference/)
- 《Linux环境编程：从应用到内核》
- 《Linux/UNIX系统编程手册》


