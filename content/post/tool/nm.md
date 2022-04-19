---
title: "nm 简明教程"
date: 2022-04-16T16:58:22+08:00
tags: ["nm","符号","符号修饰","重定位","链接"]
categories: ["工具箱"]
draft: true
---

![题图](https://voidint.github.io/tool/puzzle.jpeg)

`nm`是 UNIX/Linux 系统下查看二进制文件（可执行文件、目标文件、静态库、动态库）中符号信息的命令行工具。那么所谓的`符号`又是什么呢？

# 什么是符号
现代的编程语言越来越智能，开发工具链越来越完善，各种 IDE 更是将程序员往傻瓜方向带，导致不少程序员（特别是开发上层应用的程序员）对程序的编译过程不甚了解。日常开发过程中的编译也就是按个按钮或者敲一条指令就完成了整个编译构建的过程，也的确接触不到这个编译过程中的细节。

![gcc编译链接过程](https://voidint.github.io/tool/gcc-compilation-process.jpeg)

上图是 GCC 编译过程的分解，从图中可以看到整个过程分为`预处理`、`编译`、`汇编`、`链接`等几个过程。目前常见的静态编译型的语言多数也会涉及到其中的`编译`、`汇编`、`链接`等步骤，只不过是强大的工具链将这些细节为我们隐藏了罢了。而`符号`在这其中扮演着重要的角色。

在现代软件开发过程中，软件的规模往往都很大，动辄数百万行代码，如果都放在一个模块肯定无法想象。所以现代的大型软件往往拥有成千上万个模块，这些模块之间相互依赖又相对独立。这种按照层次化及模块化存储和组织源代码有很多好处，比如代码更容易阅读、理解、重用，每个模块可以单独开发、编译、测试，改变部分代码不需要编译整个程序等。

在一个程序被分割成多个模块以后，这些模块之间最后如何组合形成一个单一的程序是须解决的问题。模块之间如何组合的问题可以归结为模块之间如何通信的问题，最常见的属于静态语言的 C/C++ 模块之间通信有两种方式，一种是模块间的函数调用，另外一种是模块间的变量访问。函数访问须知道目标函数的地址，变量访问也须知道目标变量的地址，所以这两种方式都可以归结为一种方式，那就是模块间符号的引用。模块间依靠符号来通信类似于拼图版，定义符号的模块多出一块区域，引用该符号的模块刚好少了那一块区域，两者一拼接刚好完美组合。这个模块的拼接过程就是**链接（Linking）**。

![模块间拼合](https://voidint.github.io/tool/link-puzzle.jpeg)

链接过程的本质就是要把多个不同的目标文件之间相互“粘”到一起，或者说像玩具积木一样，可以拼装形成一个整体。为了使不同目标文件之间能够相互粘合，这些目标文件之间必须有固定的规则才行，就像积木模块必须有凹凸部分才能够拼合。在链接中，目标文件之间相互拼合实际上是目标文件之间对地址的引用，即对函数和变量的地址的引用。比如目标文件B要用到了目标文件A中的函数`foo`，那么我们就称目标文件A定义（Define）了函数`foo`，称目标文件B引用（Reference）了目标文件A中的函数`foo`。这两个概念也同样适用于变量。**每个函数或变量都有自己独特的名字，才能避免链接过程中不同变量和函数之间的混淆。在链接中，我们将函数和变量统称为符号（Symbol），函数名或变量名就是符号名（Symbol Name）。**

### 示例
接下来将会用 C/C++ 编写一个简单的程序，并使用 nm 分别查看目标文件和可执行文件中的符号表。通过这个真实的例子来更加直观地体验下符号。

- a.cpp
    ``` cpp
    #include <iostream>

    namespace testns {
    int shared = 7;
    };

    extern int shared;
    void swap(int *a, int *b);

    int main(int argc, char *argv[]) {
        int a = 100;
        swap(&a, &shared);
        std::printf("a=%d, shared=%d\n", a, shared);
    }
    ```
	
- b.cpp
    ```cpp
    int shared = 1;
        
    void swap(int *a, int *b) {
        int c = *a;
        *a = *b;
        *b = c;
    }
    ```
	
- 分别对 a.cpp 和 b.cpp 文件进行编译并查看两者的符号表
    ```shell
    $ g++ -g -c a.cpp
    $ g++ -g -c b.cpp
    $ nm a.o
                        U __cxa_atexit
                        U __dso_handle
    0000000000000086 t _GLOBAL__sub_I__ZN6testns6sharedE
    0000000000000000 T main
                        U printf
                        U shared
    0000000000000048 t _Z41__static_initialization_and_destruction_0ii
                        U _Z4swapPiS_
    0000000000000000 D _ZN6testns6sharedE
                        U _ZNSt8ios_base4InitC1Ev
                        U _ZNSt8ios_base4InitD1Ev
    0000000000000000 r _ZStL19piecewise_construct
    0000000000000000 b _ZStL8__ioinit	
    $ nm b.o
    0000000000000000 D shared
    0000000000000000 T _Z4swapPiS_
    ```

- 将 a.cpp 和 b.cpp 文件编译成可执行文件a.out并查看其符号表
    ```shell
    $ g++ -g a.cpp b.cpp
    $ nm a.out
    0000000000400635 t .annobin__dl_relocate_static_pie.end
    0000000000400630 t .annobin__dl_relocate_static_pie.start
    00000000004007b0 t .annobin_elf_init.c
    0000000000400825 t .annobin_elf_init.c_end
    0000000000400600 t .annobin_elf_init.c_end.exit
    0000000000400600 t .annobin_elf_init.c_end.hot
    0000000000400600 t .annobin_elf_init.c_end.startup
    0000000000400600 t .annobin_elf_init.c_end.unlikely
    0000000000400600 t .annobin_elf_init.c.exit
    0000000000400600 t .annobin_elf_init.c.hot
    0000000000400600 t .annobin_elf_init.c.startup
    0000000000400600 t .annobin_elf_init.c.unlikely
    000000000040062f t .annobin_init.c
    000000000040062f t .annobin_init.c_end
    0000000000400600 t .annobin_init.c_end.exit
    0000000000400600 t .annobin_init.c_end.hot
    0000000000400600 t .annobin_init.c_end.startup
    0000000000400600 t .annobin_init.c_end.unlikely
    0000000000400600 t .annobin_init.c.exit
    0000000000400600 t .annobin_init.c.hot
    0000000000400600 t .annobin_init.c.startup
    0000000000400600 t .annobin_init.c.unlikely
    0000000000400825 t .annobin___libc_csu_fini.end
    0000000000400815 t .annobin___libc_csu_fini.start
    0000000000400815 t .annobin___libc_csu_init.end
    00000000004007b0 t .annobin___libc_csu_init.start
    0000000000400630 t .annobin_static_reloc.c
    0000000000400635 t .annobin_static_reloc.c_end
    0000000000400600 t .annobin_static_reloc.c_end.exit
    0000000000400600 t .annobin_static_reloc.c_end.hot
    0000000000400600 t .annobin_static_reloc.c_end.startup
    0000000000400600 t .annobin_static_reloc.c_end.unlikely
    0000000000400600 t .annobin_static_reloc.c.exit
    0000000000400600 t .annobin_static_reloc.c.hot
    0000000000400600 t .annobin_static_reloc.c.startup
    0000000000400600 t .annobin_static_reloc.c.unlikely
    0000000000601044 B __bss_start
    0000000000601044 b completed.7294
                        U __cxa_atexit@@GLIBC_2.2.5
    0000000000601038 D __data_start
    0000000000601038 W data_start
    0000000000400640 t deregister_tm_clones
    0000000000400630 T _dl_relocate_static_pie
    00000000004006b0 t __do_global_dtors_aux
    0000000000600dd8 t __do_global_dtors_aux_fini_array_entry
    0000000000400840 R __dso_handle
    0000000000600de0 d _DYNAMIC
    0000000000601044 D _edata
    0000000000601048 B _end
    0000000000400828 T _fini
    00000000004006e0 t frame_dummy
    0000000000600dc8 t __frame_dummy_init_array_entry
    00000000004009f4 r __FRAME_END__
    0000000000601000 d _GLOBAL_OFFSET_TABLE_
    000000000040076c t _GLOBAL__sub_I__ZN6testns6sharedE
                        w __gmon_start__
    000000000040085c r __GNU_EH_FRAME_HDR
    0000000000400590 T _init
    0000000000600dd8 t __init_array_end
    0000000000600dc8 t __init_array_start
    0000000000400838 R _IO_stdin_used
                        w _ITM_deregisterTMCloneTable
                        w _ITM_registerTMCloneTable
    0000000000400820 T __libc_csu_fini
    00000000004007b0 T __libc_csu_init
                        U __libc_start_main@@GLIBC_2.2.5
    00000000004006e6 T main
                        U printf@@GLIBC_2.2.5
    0000000000400670 t register_tm_clones
    0000000000601040 D shared
    0000000000400600 T _start
    0000000000601048 D __TMC_END__
    000000000040072e t _Z41__static_initialization_and_destruction_0ii
    0000000000400781 T _Z4swapPiS_
    000000000060103c D _ZN6testns6sharedE
                        U _ZNSt8ios_base4InitC1Ev@@GLIBCXX_3.4
                        U _ZNSt8ios_base4InitD1Ev@@GLIBCXX_3.4
    0000000000400848 r _ZStL19piecewise_construct
    0000000000601045 b _ZStL8__ioinit
    ```


# 符号类型
nm 的默认输出格式是每行一个符号，每行均由空格分隔成了三列：第一列是内存地址；第二列是符号类型；第三列是符号名。

内存地址指的是虚拟内存地址，如果地址是`0000000000000000`，链接器会在链接过程中重新计算一个新的内存地址，这个过程叫**重定位**。比如上文示例中全局变量`shared`在 b.o 目标文件中的符号内存地址就是`0000000000000000`，但是经过链接后的可执行文件 a.out 中的符号内存地址就被重定位成了`0000000000601040`。

符号名通常就是上文所提到的函数和变量，链接器在链接过程中需要通过各个目标文件中的符号进行重定位计算内存地址并生成最终的可执行文件，因为符号名在这些目标文件中得是唯一的。C++ 拥有丰富的语言特性，其中命名空间、类继承、函数重载等特性允许在不同作用域下拥有同名的变量和函数，这就必须有一套机制去确保符号不会重名，这也就是**符号修饰**。比如上文示例中存在两个名为`shared`的变量，一个为默认命名空间中的变量，一个为`testns`命名空间中的变量。为了支持 C++ 的命名空间特性，同时也为了保证符号名称的唯一性，编译器对符号名称进行了修饰，最终的符号名变成了`_ZN6testns6sharedE`。当然，符号修饰的规则各家编译器厂商并不统一，因此最终的符号名称不一定就是示例中给出的名称。正因如此，C++ 的 ABI 兼容性并不好，甚至同一编译器的不同版本也存在 ABI 不兼容的情况。

本节对重定位和符号修饰不做过多展开，主要来阐述下有关符号类型的话题。符号类型一般遵循这样的规则：**大写字母表示全局符号（global），小写字母表示局部符号（local）**。所谓的**全局符号**，是在某个目标文件中能被其他目标文件所引用的符号，比如全局函数、全局变量等。所谓的**局部符号**，则是只能在当前目标文件内部被引用的符号，比如 C/C++ 中使用 static 关键字修饰的全局变量，它们仅仅在编译单元内部可见。而上文所提及的**外部符号**，是那些在当前目标文件中所引用的其他目标文件中的全局符号。

以下是对常见符号类型的说明：

| 类型 | 说明                                                         |
| ---- | ------------------------------------------------------------ |
| B    | 未初始化数据段（即`.bss`段）全局符号。                       |
| b    | 未初始化数据段（即`.bss`段）局部符号。                       |
| C    | 该符号为common。common symbol是未初始话数据段。该符号没有包含于一个普通section中。只有在链接过程中才进行分配。符号的值表示该符号需要的字节数。 |
| D    | 已初始化数据段（即`.data`段）全局符号                        |
| d    | 已初始化数据段（即`.data`段）局部符号。                      |
| R    | 只读数据段（即`.rodata`段）全局符号。                        |
| r    | 只读数据段（即`.rodata`段）局部符号。                        |
| T    | 代码段（即`.text`段）全局符号。                              |
| t    | 代码段（即`.text`段）局部符号。                              |
| U    | 未定义符号（外部符号）。                                     |


# nm命令行选项

| 选项                       | 说明                                                         |
| -------------------------- | ------------------------------------------------------------ |
| -a, --debug-syms           | 显示所有的符号，包括debugger-only symbols。                  |
| -A, --print-file-name      | 在每个符号的开始位置显示输入文件名。                         |
| **-C, --demangle[=STYLE]** | 将低级符号名解析成用户级名字（可以使得 C++ 函数名具有可读性）。 |
| --no-demangle              | 默认的选项，不将低级符号名解析成用户级名。                   |
| -f, --format=FORMAT        | 输出格式。可选值包括`bsd`（默认）、`sysv`、`posix`。         |
| **-g, --extern-only**      | 仅显示外部符号。                                             |
| **-l, --line-numbers**     | 若目标文件中包含调试信息（gcc/g++ -g选项），则显示每个符号所对应的源代码文件名和行号。 |
| -n, --numeric-sort         | 按符号对应地址的顺序排序，而非按符号名的字符顺序。           |
| -p, --no-sort              | 按目标文件中遇到的符号顺序显示，不排序。                     |
| **-S, --print-size**       | 输出每个符号的大小。                                         |
| --size-sort                | 按照符号大小排序。                                           |
| **-u, --undefined-only**   | 仅显示未定义符号。                                           |
| -h, --help                 | 显示帮助信息。                                               |
| -V, --version              | 显示版本号。                                                 |


# go tool nm命令行选项
go 标准库工具链中也提供了`go tool nm`子命令。该子命令是一个 nm 的简化实现，仅提供了有限的几个选项。注意：不建议在编译时为链接器指定选项`-ldflags='-s -w'`，否则相关的符号表和调试信息将被去除。

| 选项  | 说明                                                         |
| ----- | ------------------------------------------------------------ |
| -n    | 按符号对应地址的顺序排序（同`nm -n`）。                      |
| -size | 是否输出每个符号的大小（同`nm -S`）。                        |
| -sort | 按照给定的排序条件进行排序显示。address`：按低地址到高地址排序。`name`：按照符号名的字符表顺序排序。`none`：不排序。`size`：按照符号大小降序排列。 |
| -type | 是否在名称后打印符号类型。                                   |


# 参考资料
- [《程序员的自我修养：链接、装载与库》](https://book.douban.com/subject/3652388/)
- [nm 目标文件格式分析](https://linuxtools-rst.readthedocs.io/zh_CN/latest/tool/nm.html)
- [nm(1)](https://man7.org/linux/man-pages/man1/nm.1.html)