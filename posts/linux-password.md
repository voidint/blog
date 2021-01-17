---
title: 'Linux用户登录密码的生成'
date: 2020-02-25 17:24:33
tags: [Linux,Password,grub-crypt]
published: true
hideInList: false
feature: /post-images/linux-password.jpg
isTop: false
---

如何生成一个Linux用户登录密码？可能有人会说用passwd生成。的确，passwd命令能够帮助我们重置用户登录密码，但是这并没有解答如何生成一个Linux用户登录密码的疑问。

对于这个问题，秉承着实用主义的精神，我原本也不会去深究。毕竟，安装的时候会设置密码，安装完毕后能通过passwd命令重置密码，学会这两点后已满足一般的需求已经绰绰有余了。

但是，对于自动化而言，知道以上的两点是不够的。Linux的自动化安装过程中，设置用户登录密码这事，肯定不能有人为干预，否则谈什么自动化。操作系统安装完毕后，也有可能会有重置用户密码的自动化需求，此时使用passwd命令来重置用户密码，也不见得是最佳的选择。

如果明白了密码的生成机制，那么这个自动化需求的难题也就迎刃而解了。

# 密码生成理论
有Linux基础的人一定知道，Linux的用户登录密码信息是存放在/etc/shadow文件当中的，并且该文件只有root用户能够访问。以下会以voidint这个用户为例，看一下这个用户的密码信息。

```shell
$ sudo cat /etc/shadow | grep voidint
[sudo] password for voidint:
voidint:$6$3kheX/Vg$TGum9JEjfmGsj8Mfk3SUY/d/bWkJgnRimCxoaDTX7wcgrraYvU.fiziEUdpDglWc58uPZqWJhKNjiXayP9Q6b0:16892::::::
```

很明显，这个字符串被`:`符号分隔成了9段。我们这里只关注前两段，至于每一段具体的含义，可以戳这里自行阅读。第一段，是用户名称。第二段，即为用户密码。其实密码这种称呼并不准确。相对准确的说法是，用户密码明文经过某种哈希算法计算所获得的密文。但是，鉴于这个相对准确的说法实在太长太拗口，不便于表达。因此，以下提到的密码在无特别说明情况下，一律指的是密码明文的密文。

言归正传，看到这里相信好多人会和我有一样的思考: 是不是只要知道了密码生成的算法，并按照此算法生成一个满足Linux要求的密码，再把密码覆盖这个第二段的内容，那么用户密码就被重置了吗？

仔细看这段密码，会发现它是由`$xxx$xxx$xxx`的格式构成，即由`$`符号分隔的3端字符串构成。查阅资料后得知，这个格式可以进一步概括为`$id$salt$encrypted`。简要说明下`$id$salt$encrypted`中各个部分的含义:

- id: 加密(确切说是哈希)所用算法的代号。
    | **ID** | **Method**                                                   |
    | ------ | ------------------------------------------------------------ |
    | 1      | MD5                                                          |
    | 2a     | Blowfish (not in mainline glibc; added in some Linux distributions) |
    | 5      | SHA-256 (since glibc 2.7)                                    |
    | 6      | SHA-512 (since glibc 2.7)                                    |
- salt: 由程序随机生成的字符串，即盐。
- encrypted: 用户密码明文字符串加盐后使用哈希算法所得的哈希值，即哈希(明文+盐)。

## 特别说明
资料中还提到了另外一种形式的密码——`$id$rounds=yyy$salt$encrypted`。其中，盐的部分换成了rounds=yyy。yyy是一个由用户(调用方)提供的[1000, 999999999]之间的整数。

# 密码生成实践
知道了上面这部分基础知识，那么接下来就是理论指导实践的环节了。具体可以借助什么工具来生成密码呢？这里使用的grub-crypt工具。你可以在某个Linux发行版中安装这个工具，也可以使用我提供的这个[dockerfile](https://github.com/voidint/dockerfile/tree/master/grub-crypt)。

- 使用sha512算法生成密码

```shell
$ grub-crypt --sha-512
Password:
Retype password:
$6$r1jcut3Crl8bSIMo$XfKnrl4Ykzk2KPQ59MCXcUef9OjZWoZrIp7aeWwnCzIVQY1p/G1EiJQE4DYFej783NlvR5KtKYXs4P/hQaVst.
```

- 将生成的密码写入/etc/shadow文件

```shell
$ sudo cat /etc/shadow | grep voidint
voidint:$6$r1jcut3Crl8bSIMo$XfKnrl4Ykzk2KPQ59MCXcUef9OjZWoZrIp7aeWwnCzIVQY1p/G1EiJQE4DYFej783NlvR5KtKYXs4P/hQaVst.:16892:::::: 
```

- 退出当前用户并使用新修改的密码登录

# 参考
- [CRYPT(3)](http://man7.org/linux/man-pages/man3/crypt.3.html)
- [CentOS / RHEL 6 : How to password protect grub (Password-Protected Booting)](https://www.thegeekdiary.com/centos-rhel-6-how-to-password-protect-grub-password-protected-booting/)
- [Command | kickstart之中rootpw密码生成方法](http://clavinli.github.io/2014/11/14/linux-command-hash-root-password-in-kickstart/)
- [鸟哥的Linux私房菜——/etc/shadow文件结构](http://cn.linux.vbird.org/linux_basic/0410accountmanager.php#shadow_file)

