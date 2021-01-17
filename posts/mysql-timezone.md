---
title: '容器内MySQL时区调整'
date: 2020-02-25 16:08:07
tags: [MySQL,timezone,docker]
published: true
hideInList: false
feature: /post-images/mysql-timezone.jpg
isTop: false
---
从docker hub拉取的MySQL官方docker镜像，启动MySQL容器后，执行`select now()`语句，发现显示的时间与我宿主机的时间不一致且相差8小时。显然，需要重置MySQL的时区，将时区设置与宿主机保持一致，即东八区。

### 如何为MySQL设置时区？
[MySQL 5.7官方文档](https://dev.mysql.com/doc/refman/5.7/en/time-zone-support.html)中提到了多种设置时区的方案，我们这里仅关注配置文件（MySQL官方称之为[Option Files](https://dev.mysql.com/doc/refman/5.7/en/option-files.html)）的方案。

#### 配置文件中修改时区
- 配置项default-time-zone及取值
    依据文档可以通过在配置文件中增加default-time-zone='timezone'的配置项来修改时区。配置值的取值遵循以下规则：

    >- The value 'SYSTEM' indicates that the time zone should be the same as the system time zone.
    >
    >- The value can be given as a string indicating an offset from UTC, such as '+10:00' or '-6:00'.
    >
    >- The value can be given as a named time zone, such as 'Europe/Helsinki', 'US/Eastern', or 'MET'. Named time zones can be used only if the time zone information tables in the mysql database have been created and populated.

    我们选择第二种方式，通过UTC的偏移量来表示东八区，+8:00意味着在零时区的基础上往东偏移8个时区。
- group
    官方文档中描述了配置文件的语法，包括注释、组、选项名、选项值等。其中组（group）是与我们当前遇到的问题息息相关的东西。配置项需要放置在正确的group下，官方表述如下：

    > If an option group name is the same as a program name, options in the group apply specifically to that program.
    > For example, the [mysqld] and [mysql] groups apply to the mysqld server and the mysql client program, respectively.

由于配置项default-time-zone是为了让MySQL Server调整默认时区，并结合上面有关group的表述，不难得出一个结论：default-time-zone配置项应该放置在名为[mysqld]的group下。

```shell
[mysqld]
default-time_zone = '+8:00'
```

#### 配置文件位置
既然已经明确了通过修改配置文件来达到重置MySQL时区的目的，那么修改后的配置文件放哪儿呢？这是首先面临的一个问题。好在MySQL官方文档中已经告诉我们配置文件的读取顺序。

| **File Name**       | **Purpose**                                     |
| ------------------- | ----------------------------------------------- |
| /etc/my.cnf         | Global options                                  |
| /etc/mysql/my.cnf   | Global options                                  |
| *SYSCONFDIR*/my.cnf | Global options                                  |
| $MYSQL_HOME/my.cnf  | Server-specific options (server only)           |
| defaults-extra-file | The file specified with `--defaults-extra-file` |
| ~/.my.cnf           | User-specific options                           |
| ~/.mylogin.cnf      | User-specific login path options (clients only) |

再尝试查看MySQL的docker容器中的配置文件，docker run --rm mysql:5.7 cat /etc/mysql/my.cnf，我们看到了容器中的配置文件内容如下：

```
# Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
```


这下这个疑问终于有了答案，我们可以将自定义的配置文件想办法放入容器中的/etc/mysql/conf.d/目录（放在/etc/mysql/mysql.conf.d/目录当然也同样OK）。

注意：在*nix系统下使用!includedir指令指定的配置文件目录下的配置文件扩展名必须是.cnf，在Windows系统下的扩展名可以是.ini或者.cnf。

#### 启动MySQL容器

```shell
$ docker run  -d --name mysql5.7 \
    -v /Users/voidint/dockerV/mysql/5.7/conf:/etc/mysql/conf.d \
    -e MYSQL_ROOT_PASSWORD='abc#123' \
    -p 3306:3306\
    mysql:5.7
```

参考MySQL官方docker镜像的说明，我们将上面步骤准备好的MySQL配置文件放置在/Users/voidint/dockerV/mysql/5.7/conf目录下，并通过docker -v选项将宿主机上的配置文件目录挂载到容器中的/etc/mysql/conf.d目录。这样在容器启动时就能读取到我们自定义的配置文件，时区配置也就生效了。

容器启动后，通过MySQL客户端连接上MySQL，再次执行select now()语句以验证MySQL的时区是否与宿主机时区保持一致。

### 参考
- [MySQL Server Time Zone Support](https://dev.mysql.com/doc/refman/5.7/en/time-zone-support.html)
- [Using Option Files](https://dev.mysql.com/doc/refman/5.7/en/option-files.html)
- [MySQL Docker镜像](https://hub.docker.com/_/mysql)




