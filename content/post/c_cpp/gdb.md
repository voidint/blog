---
title: "gdb常用命令速查"
date: 2021-07-22T16:49:24+08:00
draft: true
tags: ["gdb", "debug"]
categories: ["C/C++"]
---

> 原文链接：https://voidint.github.io/post/c_cpp/gdb/

![题图](https://voidint.github.io/c_cpp/gdb.gif)


gdb 调试前提是需要保留符号表。对于 C/C++ 等使用 gcc 进行编译的语言，编译时增加`-g`选项。对于 go 语言，则增加`-ldflags=-compressdwarf=false` 、`-gcflags=all="-N -l"`等选项。



| 命令      | 缩写 | 子命令      | 描述                             | 示例                                                         |
| --------- | ---- | ----------- | -------------------------------- | ------------------------------------------------------------ |
| help      | h    |             | 显示目标命令的帮助信息           | (gdb) h start                                                |
| file      |      |             | 加载待调试的可执行文件           | (gdb) file /root/main_cpp                                    |
| quit      | q    |             | 退出gdb                          | (gdb) q                                                      |
| show      |      | listsize    | 返回list命令单次显示的源代码行数 | (gdb) show listsize                                          |
|           |      | args        | 显示调试程序的启动参数           | (gdb) show args                                              |
| set       |      | listsize    | 设置list命令单次显示的源代码行数 | (gdb) set listsize 20                                        |
|           |      | args        | 设置调试程序启动参数             | (gdb) set args --config /root/config.json                    |
| list      | l    |             | 显示指定位置的源代码             | (gdb) l<br />(gdb) l 7<br />(gdb) l showFunc<br />(gdb) l hello.cpp:7<br />(gdb) l main.cpp:showFunc |
| break     | b    |             | 设置断点/条件断点                | (gdb) b 9<br />(gdb) b showFunc<br />(gdb) b main.cpp:13<br />(gdb) b main.cpp:showFunc<br />(gdb) b showFunc if a==10 |
| delete    | d    |             | 删除断点                         | (gdb) d 1<br />(gdb) d 2 3<br />(gdb) d 4-7                  |
|           |      | breakpoints | 删除所有断点                     | (gdb) delete breakpoints                                     |
| disable   |      |             | 使断点失效                       | (gdb) disable 10                                             |
| enable    |      |             | 使失效断点重新有效               | (gdb) enable 10                                              |
| info      | i    | break       | 显示断点                         | (gdb) i b                                                    |
|           |      | stack       | 显示堆栈信息                     | (gdb) i s                                                    |
|           |      | frame       | 显示当前栈帧详细信息             | (gdb) info frame                                             |
|           |      | args        | 显示当前栈帧的入参               | (gdb) info args                                              |
|           |      | locals      | 显示当前栈帧的所有局部变量       | (gdb) info locals                                            |
| start     |      |             | 运行程序并在第一条语句处暂停     | (gdb) start                                                  |
| run       | r    |             | 运行程序并在首个断点处暂停       | (gdb) r                                                      |
| next      | n    |             | 下一步（step over）              | (gdb) n                                                      |
| step      | s    |             | 下一步（step into）              | (gdb) s                                                      |
| finish    |      |             | 跳出当前堆栈帧（step out）       | (gdb) finish                                                 |
| continue  | c    |             | 继续执行并直至下一个断点处       | (gdb) c                                                      |
| backtrace | bt   |             | 显示当前函数调用栈               | (gdb) bt                                                     |
| print     | p    |             | 显示变量的值                     | (gdb) print v<br />(gdb) print &v                            |
| whatis    |      |             | 显示变量/表达式的数据类型        | (gdb) whatis v<br />(gdb) whatis &v                          |

