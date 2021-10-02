---
title: "Linux下hpssacli配置 HP Smart Array"
date: 2020-02-25 17:05:06
tags: [RAID,HPSSACLI]
categories: ["工具箱"]
draft: true
---

![题图](https://voidint.github.io/tool/hp-ssa-cli.jpg)

# 什么是HP SSA CLI
HP Smart Storage Administrator Command Line

# 适用范围
HP Smart Array G6、G7、G8、G9

# 创建RAID的指导方针
- 组成逻辑磁盘(RAID阵列)的物理驱动器应该是一致的。
- 为了更好地利用物理驱动器的空间容量，组成RAID阵列的每一块物理驱动器的容量应该趋于一致的。如果物理驱动器在容量上有差异，以容量最小的为准。

# HPSSACLI操作模式
- Console mode: 交互式的带上下文的命令行模式。
- Command mode:

# 语法
不管是console mode还是command mode，典型的HP SSA CLI由这几部分组成: target、command、parameter（如果需要的话）。

<target> <command> [parameter=value]

## target
target是你所要配置的device的一种表示方法。device可以是controller、array、logical drive、physical drive。

### 例子
- controller slot=3
- controller wwn=500805F3000BAC11
- controller slot=2 array A
- controller chassisname="A" array B logicaldrive 2
- controller chassisname="A" physicaldrive 1:0
- controller all
- controller slot=2 array all
- controller slot=3 physicaldrive 1:2-1:5

## command
### 配置类
- add
- create
- delete
- modify
- remove
- set target

### 非配置类
- diag
- help
- rescan
- shorthand
- show
- version

## 去除警告性提示
对于一些可能对数据安全产生危险的操作，程序会要求输入y/n后才会实际执行。如果你并不希望如此，可以增加一个force的参数来实现这样的目的。

比如，ctrl ch="Lab4" ld 1 delete forced


## show命令
通过此命令可以获取关于目标设备的一些信息。

基本的语法: <target> show [detail]|[status]

# 典型用法
## 删除目标设备
### 语法
```
<target> delete [forced]
```
由于删除设备会导致数据丢失，属于危险操作。默认情况下，程序会显示警告性的提示信息并要求输入y/n。如果要规避这种情况，可以加上force参数。
### 例子
- ctrl ch="Lab 4" delete forced
- ctrl slot=3 ld all delete

## 创建逻辑驱动器
### 语法
```
<target> create type=ld [parameter=value]
```
一般而言<target>指的是controller，但如果是要在一个已经存在的阵列(array)基础上创建一个逻辑驱动器，那么<target>也可以是array。

如果你想要在一组物理驱动器(physical drive)之上创建一个逻辑驱动器(logical drive)，那么不需要先去创建一个阵列(array)。CLI有别于GUI，阵列是在创建逻辑驱动器时自动创建的。

### 例子
- ctrl slot=5 create type=ld drives=1:0,1:1,1:3 raid=adg
- ctrl slot=5 create type=ld drives=1:1-1:3 raid=adg
- ctrl slot=5 create type=ld drives=1:7,1:10-2:5,2:8-2:12 raid=adg
- ctrl slot=5 array A create type=ld size=330 raid=adg

# 参考
- [HP Smart Storage Administrator User Guide](https://community.hpe.com/hpeb/attachments/hpeb/itrc-264/148204/3/HP%20Smart%20Storage%20Administrator%20User%20Guide.pdf)