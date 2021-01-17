---
title: '为什么mysql -h localhost无法登录了？'
date: 2020-02-25 15:56:49
tags: [MySQL,localhost]
published: true
hideInList: false
feature: /post-images/mysql-login-localhost.png
isTop: false
---
我在自己的mac上安装了docker，并在docker中运行了mysql5.6容器。启动容器的方式大致如下：
```shell
$ docker run --name mydb -d \
    -p 3306:3306 \
    -v /Users/voidint/dockerV/mysql/data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=xxxxx \
    mysql:5.6
```

mysql服务正常启动之后，我想通过客户端连接此服务。于是，我顺理成章地在终端敲下了这样的命令
```shell
$ mysql -u root -p
Enter password:
ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/tmp/mysql.sock' (2)
```

非常意外，居然报错了。我记得以前都是这样敲的呀？怎么换成跑在docker里就行不通了？不科学！

```shell
$ mysql -h localhost -uroot -p
Enter password:
ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/tmp/mysql.sock' (2)
```

加上`-h`选项还是不行，气急败坏。气归气，问题还是要解决的，那就查查资料。然后，看到了这篇，在粗粗浏览过之后，发现有人建议用`-h 127.0.0.1`。

```shell 
$ mysql -h 127.0.0.1 -u root -p 
Enter password:
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 3823
Server version: 5.6.35 MySQL Community Server (GPL)

Copyright (c) 2000, 2015, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

试过之后，发现效果立竿见影。这简直颠覆了我的既有观念！

- 难道localhost和127.0.0.1不是同一个东西？OMG！
- 那个socket文件/tmp/mysql.sock又是怎么一回事，指定了127.0.0.1怎么就正常了？

在查阅了一些资料之后，终于对于这几个问题有了稍深入的理解：

# localhost和127.0.0.1的区别
- localhost和127.0.0.1，前者是域名，后者是IP地址中特殊的一类回还地址。
- 许多时候localhost和127.0.0.1给人感觉是等价的，是由于在多数系统的/etc/hosts文件中，两者存在映射关系。
- 本机上的服务，如果通过localhost访问，可以不经过网卡，并且不受防火墙的限制。如果不经过网卡，那客户端和服务端要如何通信？答案就是socket。比如上面例子中的/tmp/mysql.sock。也因为不需要经过网卡，不需要TCP/IP协议的层层封包和层层解包过程，性能上会更出色一些。
- 本机上的服务，如果通过127.0.0.1访问，需要经过网卡，也可能受到防火墙限制。

# 参考资料
- https://hub.docker.com/_/mysql/
- http://stackoverflow.com/questions/11657829/error-2002-hy000-cant-connect-to-local-mysql-server-through-socket-var-run
- http://blog.onlycatch.com/post/7e371ca28621
- http://i.joymvp.com/%E6%8A%80%E6%9C%AF/routing-traffic-localhost.html