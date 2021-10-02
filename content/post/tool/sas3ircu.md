---
title: "SAS3IRCU配置LSI SAS3系列RAID卡"
date: 2020-02-25 16:43:06
tags: [RAID,SAS3IRCU]
categories: ["工具箱"]
draft: true
---

![题图](https://voidint.github.io/tool/sas3ircu.jpg)

# 适用的controller
- LSISAS3008
- LSISAS3004

# 名词解释
- Controller:
- IR:
- Volume: 卷，基于物理驱动器通过创建冗余磁盘阵列所生成的虚拟磁盘。概念上等同于RAID冗余磁盘阵列。
- Enclosure: 硬盘盒编号。
- Bay: 即slot，指代硬盘盒的某个插槽。
- HDD: Hard Disk Drive的缩写，即普通机械硬盘。
- SSD: Solid State Drive的缩写，即固态硬盘。
- SAS: 序列式SCSI（SAS：Serial Attached SCSI）是一种电脑集线的技术，其功能主要是作为周边零件的数据传输，例如：硬盘、CD-ROM等设备而设计的界面。
- SATA: 串行ATA（Serial ATA: Serial Advanced Technology Attachment）是一种电脑总线，负责主板和大容量存储设备（如硬盘及光盘驱动器）之间的数据传输，主要用于个人电脑。

# 语法
```
sas3ircu <controller_#> <command> <parameters>
```

# 通用参数
- <controller_#>
    controller编号是程序分配给PCI插槽上的RAID硬件的唯一编号。比如，某个设备上包含2块LSI SAS3008的RAID卡，那么编号0就代表这第一块RAID卡，而编号1就指代另一块。这个编号的取值范围是0~255之间的整数。

- <Enclosure:Bay>
    由硬盘盒编号(Enclosure)和插槽编号(Bay/Slot)组成的物理驱动器唯一标识。通过DISPLAY命令可以查看到此信息。

# 退出码
- 0: 命令执行成功。
- 1: 错误的命令行参数或者操作失败。
- 2: 未发现指定的adapter。

# CREATE命令
创建volume须准守以下规则:

- 组成一个volume的多块磁盘，包括卷的热备盘在内，都必须是在同一个controller上。
- 支持的RAID级别包括: RAID0、RAID1、RAID1E、RAID10。
- 同一个controller上至多创建2个volume。
- RAID级别与物理驱动器数量限制
    - RAID0: Max=10; Min=2
    - RAID1: Max=2; Min=2
    - RAID1E: Max=10; Min=3
    - RAID10: Max=10; Min=3
- 每个controller上能创建1个或者2个hot spare disk。
- 不允许跨SAS、SATA物理驱动器创建volume。
- 不允许跨普通硬盘和固态硬盘创建volume。
## 语法
```
sas3ircu <controller_#> create <volume_type> <size> {<Enclosure:Bay>} [VolumeName] [noprompt]
```
## 参数
- <controller_#>: controller编号。
- <volume_type>: volume类型。等价于RAID级别。可选值包括RAID0、RAID1、RAID1E、RAID10。
- <size>: volume的容量大小，单位MB。MAX代表可用的最大容量值。
- <Enclosure:Bay>:
- [VolumeName]: 可选，volume名称。
- [noprompt]: 可选，阻止在命令运行过程中产生的警告和交互式提示，即静默运行。

# DELETE命令
该命令用于删除指定controller下的所有的volume及其hot spare drives，但并不会对其它controller的配置参数产生任何影响。
## 语法
```
sas3ircu <controller_#> delete [noprompt]
```
## 参数
- <controller_#>: controller编号。
- [noprompt]: 可选，阻止在命令运行过程中产生的警告和交互式提示，即静默运行。

# DELETEVOLUME命令
该命令用于删除指定controller下的指定volume及其hot spare drives，但并不会对其它controller的配置参数产生任何影响。如果某个hot spare对于剩余还未被删除的volume而言是不合适的，那么这个hot spare也会被删除。
## 语法
```
sas3ircu <controller_#> deletevolume <volumeID> [noprompt]
```
## 参数
- <controller_#>: controller编号。
- <volumeID>: 待删除的volume ID。通过STATUS或者DISPLAY命令可以查看到volume ID相关的信息。
- [noprompt]: 可选，阻止在命令运行过程中产生的警告和交互式提示，即静默运行。

# DISPLAY命令
该命令用于显示LSI SAS3 controller相关的配置信息，包括controller类型、固件版本、BIOS版本、volume信息、物理驱动器信息，以及enclosure。

## 语法
```
sas3ircu <controller_#> display [filename]
```

## 参数
- <controller_#>: controller编号。
- [filename]: 可选，用于存储该命令输出的文件。

## 命令输出样例
```
Avago Technologies SAS3 IR Configuration Utility.
Version 15.00.00.00 (2016.11.21) 
Copyright (c) 2009-2016 Avago Technologies. All rights reserved. 

Read configuration has been initiated for controller 0
------------------------------------------------------------------------
Controller information
------------------------------------------------------------------------
  Controller type                         : SAS3008
  BIOS version                            : 8.29.02.00
  Firmware version                        : 12.00.02.00
  Channel description                     : 1 Serial Attached SCSI
  Initiator ID                            : 0
  Maximum physical devices                : 255
  Concurrent commands supported           : 4096
  Slot                                    : 0
  Segment                                 : 0
  Bus                                     : 1
  Device                                  : 0
  Function                                : 0
  RAID Support                            : Yes
------------------------------------------------------------------------
IR Volume information
------------------------------------------------------------------------
IR volume 1
  Volume ID                               : 323
  Status of volume                        : Okay (OKY)
  Volume wwid                             : 04b796b93430a2a7
  RAID level                              : RAID1
  Size (in MB)                            : 857353
  Boot                                    : Primary
  Physical hard disks                     :
  PHY[0] Enclosure#/Slot#                 : 2:0
  PHY[1] Enclosure#/Slot#                 : 2:1
------------------------------------------------------------------------
Physical device information
------------------------------------------------------------------------
Initiator at ID #0

Device is a Hard disk
  Enclosure #                             : 2
  Slot #                                  : 0
  SAS Address                             : 5000c50-0-9f3e-0741
  State                                   : Optimal (OPT)
  Size (in MB)/(in sectors)               : 858483/1758174767
  Manufacturer                            : SEAGATE 
  Model Number                            : ST900MM0168     
  Firmware Revision                       : N003
  Serial No                               : W4009ZLH0000E739G08J
  Unit Serial No(VPD)                     : W4009ZLH0000E739G08J
  GUID                                    : 5000c5009f3e0743
  Protocol                                : SAS
  Drive Type                              : SAS_HDD

Device is a Hard disk
  Enclosure #                             : 2
  Slot #                                  : 1
  SAS Address                             : 5000c50-0-9f40-be21
  State                                   : Optimal (OPT)
  Size (in MB)/(in sectors)               : 123/1758174767
  Manufacturer                            : SEAGATE 
  Model Number                            : ST900MM0168     
  Firmware Revision                       : N003
  Serial No                               : S403EKZH0000E7400Z53
  Unit Serial No(VPD)                     : S403EKZH0000E7400Z53
  GUID                                    : 5000c5009f40be23
  Protocol                                : SAS
  Drive Type                              : SAS_SSD

Device is a Enclosure services device
  Enclosure #                             : 2
  Slot #                                  : 36
  SAS Address                             : 500e004-a-aaaa-aa3e
  State                                   : Standby (SBY)
  Manufacturer                            : 12G SAS
  Model Number                            : Expander        
  Firmware Revision                       : RevB
  Serial No                               : 
  Unit Serial No(VPD)                     : 500e004aaaaaaa3e
  GUID                                    : N/A
  Protocol                                : SAS
  Device Type                             : Enclosure services device
------------------------------------------------------------------------
Enclosure information
------------------------------------------------------------------------
  Enclosure#                              : 1
  Logical ID                              : 5a0086f5:dc780000
  Numslots                                : 8
  StartSlot                               : 0
  Enclosure#                              : 2
  Logical ID                              : 500e004a:aaaaaa3e
  Numslots                                : 29
  StartSlot                               : 0
------------------------------------------------------------------------
SAS3IRCU: Command DISPLAY Completed Successfully.
SAS3IRCU: Utility Completed Successfully.
```

- IR Volume State可选值
    - Okay(OKY): 活跃、有效。如果配置的RAID级别能够提供一定的数据保护，那么此时用户数据就是受保护状态。
    - Degraded(DGD): 活跃、有效。由于配置已经发生了改变或者物理驱动器中某些处于不可用状态，用户数据实际上处于不完全受保护状态。
    - Failed(FLD): 失败。
    - Missing(MIS): 缺失。
    - Initializing(INIT): 初始化中。
    - Online(ONL): 已上线。
- Physical device State可选值
    - Online(ONL): 该物理驱动器是可用的并且已经是构成某个volume的一部分了。
    - HotSpare(HSP): 该物理驱动器已经处于热备状态。一旦对应的volume中有物理驱动器发生故障不可用，该物理驱动器就会顶替发生故障的物理驱动器。
    - Ready(RDY): 该物理驱动器已经处于预备(ready)状态，可以随时被当作一个普通的物理驱动器被使用，可以被分配到某个volume或者热备盘池(hot spare pool)。
    - Available(AVL): 该物理驱动器可能并不处于预备(ready)状态，并且不适合作为volume的一个物理驱动器，也不适合作为热备盘池中的一员。
    - Failed(FLD): 该物理驱动器发生故障或者已经下线。
    - Missing(MIS): 该物理驱动器已经被移除或者处于无响应状态。
    - Standby(SBY): 该设备不是一个硬盘设备。
    - OutofSync(OSY): 该物理驱动器是某个volume的一部分，但是它并没有与同样是volume一部分的其他物理驱动器进行同步。
    - Degraded(DGD): 该物理驱动器时某个volume的一部分并且处于降级(degraded)状态。
    - Rebuilding(RBLD): 该物理驱动器时某个volume的一部分并且处于重建(rebuilding)状态。
    - Optimal(OPT): 该物理驱动器时某个volume的一部分并且处于最优(optimal)状态。
- Physical device的Drive Type属性可选值
    - SAS_HDD: 物理驱动器是SAS普通机械硬盘。
    - SATA_HDD: 物理驱动器是SATA普通机械硬盘。
    - SAS_SSD: 物理驱动器是SAS固态硬盘。
    - SATA_SSD: 物理驱动器是SATA固态硬盘。
- Physical device的Protocol属性可选值
    - SAS: 物理驱动器支持SAS协议。
    - SATA: 物理驱动器支持SATA协议。

# HOTSPARE命令
该命令用来给热备池中添加或者删除一个物理驱动器。待添加的物理驱动器存储容量不能小于volume中各个物理驱动器存储容量最小的那个物理驱动器的存储容量。若想要确定各个物理驱动器的存储容量等信息，请参考DISPLAY命令。

创建热备盘时须准守以下规则:
- 创建热备盘前至少已经存在一个RAID级别为RAID 1、RAID 10、RAID 1E的volume。因为RAID 0不具备数据冗余特性，因此无法为此创建热备盘。
- 可以为状态是inactive的volume创建热备盘。
- 对于HDD而言，若当前controller上的所有volume使用的是SATA磁盘，那么可以添加SAS的热备盘。若当前controller上的所有volume使用的是SAS磁盘，则无法再添加SATA的热备盘。
- 对于SSD而言，只要RAID卡固件允许，允许为SATA的volume添加SAS的热备盘，也可以为SAS的volume添加SATA的热备盘。
- 每个controller最多添加2块热备盘。
- SSD可以作为HDD类型的volume的热备盘，HDD不可以作为SSD类型volume的热备盘。

## 语法
```
sas3ircu <controller_#> hotspare [delete] <Enclosure:Bay>
```

## 参数
- <controller_#>: controller编号。
- <Enclosure:Bay>: 硬盘盒编号+物理驱动器编号，可以唯一标识一块物理驱动器。
- [delete]: 可选。加上此参数意味着执行的是删除热备盘的操作，反之，则是添加热备盘操作。

# STATUS命令
该命令会显示当前已经存在volume，以及当前还在进行中的操作的状态。

## 语法
```
sas3ircu <controller_#> status
```

## 参数
- <controller_#>: controller编号。

# LIST命令
该命令显示当前系统中的所有controller及其controller index组成的列表。

## 语法
sas3ircu list

# 参考
- [SAS-3 Integrated RAID Configuration Utility (SAS3IRCU)](https://docs.broadcom.com/docs/12353382)
- [LSI SAS3008文档](https://support.huawei.com/enterprise/zh/doc/EDOC1000004345/b4b05091#it_server_sas3008_700035)
- [Disk Enclosure](https://zh.wikipedia.org/wiki/%E7%A1%AC%E7%9B%98%E7%9B%92)
- [HDD](https://zh.wikipedia.org/wiki/%E7%A1%AC%E7%9B%98)
- [SSD](https://zh.wikipedia.org/wiki/%E5%9B%BA%E6%80%81%E7%A1%AC%E7%9B%98)
- [SAS](https://zh.wikipedia.org/wiki/%E4%B8%B2%E5%88%97SCSI)
- [SATA](https://zh.wikipedia.org/wiki/SATA)
